import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/multisig_provider.dart';
import '../services/crypto_service.dart';
import '../services/yubikey_service.dart';
import '../services/contracts_service.dart';
import '../main.dart';
import 'change_password_dialog.dart';
import 'delete_wallet_dialog.dart';
import 'unlock_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<ContractConfig> _contracts = [];
  ContractConfig? _activeContract;
  bool _yubiKeyEnabled = false;
  String? _yubiKeyPublicId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final contracts = await ContractsService.getContracts();
    final active = await ContractsService.getActiveContract();
    
    final yubiEnabled = await YubiKeyService.isEnabled();
    final yubiId = await YubiKeyService.getPublicId();

    setState(() {
      _contracts = contracts;
      _activeContract = active;
      _yubiKeyEnabled = yubiEnabled;
      _yubiKeyPublicId = yubiId;
    });
  }

  Future<void> _showAddContractDialog() async {
    final result = await showDialog<ContractConfig>(
      context: context,
      builder: (context) => const _AddContractDialog(),
    );

    if (result != null && mounted) {
      await _loadSettings();
      _showSnack('Contract added');
    }
  }

  Future<void> _showEditContractDialog(ContractConfig config) async {
    final result = await showDialog<ContractConfig>(
      context: context,
      builder: (context) => _EditContractDialog(config: config),
    );

    if (result != null && mounted) {
      await _loadSettings();
      
      // If we edited the active contract, reload the provider
      if (result.id == _activeContract?.id) {
        final provider = context.read<MultisigProvider>();
        final currentPrivateKey = provider.blockchainService?.privateKey;
        
        if (currentPrivateKey != null) {
          // Use switchContract to preserve wallet connection
          await provider.switchContract(
            rpcUrl: result.rpcUrl,
            contractAddress: result.contractAddress,
            networkType: result.networkType,
            privateKey: currentPrivateKey,
          );
        } else {
          provider.disconnect();
          await provider.init(
            rpcUrl: result.rpcUrl,
            contractAddress: result.contractAddress,
            networkType: result.networkType,
          );
        }
      }
      
      _showSnack('Contract updated');
    }
  }

  Future<void> _deleteContract(ContractConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Contract'),
        content: Text('Delete "${config.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ContractsService.removeContract(config.id);
      await _loadSettings();
      
      // If we deleted the active contract, switch to another
      if (config.id == _activeContract?.id) {
        final newActive = await ContractsService.getActiveContract();
        if (newActive != null) {
          final provider = context.read<MultisigProvider>();
          final currentPrivateKey = provider.blockchainService?.privateKey;
          
          if (currentPrivateKey != null) {
            // Use switchContract to preserve wallet connection
            await provider.switchContract(
              rpcUrl: newActive.rpcUrl,
              contractAddress: newActive.contractAddress,
              networkType: newActive.networkType,
              privateKey: currentPrivateKey,
            );
          } else {
            provider.disconnect();
            await provider.init(
              rpcUrl: newActive.rpcUrl,
              contractAddress: newActive.contractAddress,
              networkType: newActive.networkType,
            );
          }
        }
      }
      
      _showSnack('Contract deleted');
    }
  }

  Future<void> _switchToContract(ContractConfig config) async {
    if (config.id == _activeContract?.id) return;

    try {
      await ContractsService.setActiveContract(config.id);
      
      if (!mounted) return;
      
      final provider = context.read<MultisigProvider>();
      
      // Get the current private key before switching (if connected)
      final currentPrivateKey = provider.blockchainService?.privateKey;
      
      if (currentPrivateKey != null) {
        // Use switchContract to preserve wallet connection
        await provider.switchContract(
          rpcUrl: config.rpcUrl,
          contractAddress: config.contractAddress,
          networkType: config.networkType,
          privateKey: currentPrivateKey,
        );
      } else {
        // Not connected, just init
        provider.disconnect();
        await provider.init(
          rpcUrl: config.rpcUrl,
          contractAddress: config.contractAddress,
          networkType: config.networkType,
        );
      }
      
      setState(() {
        _activeContract = config;
      });
      
      _showSnack('Switched to ${config.name}');
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const ChangePasswordDialog(),
    );

    if (result == true && mounted) {
      _showSnack('Password changed');
    }
  }

  Future<void> _showDeleteWalletDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteWalletDialog(),
    );

    if (confirmed == true && mounted) {
      await CryptoService.deleteWallet();
      await YubiKeyService.remove();
      if (!mounted) return;

      final provider = context.read<MultisigProvider>();
      provider.disconnect();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const InitScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showYubiKeyDialog() async {
    if (_yubiKeyEnabled) {
      // Remove YubiKey
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Remove YubiKey'),
          content: const Text('This will disable YubiKey authentication. You will only need your password to unlock.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        await YubiKeyService.remove();
        setState(() {
          _yubiKeyEnabled = false;
          _yubiKeyPublicId = null;
        });
        _showSnack('YubiKey removed');
      }
    } else {
      // Add YubiKey
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => const _AddYubiKeyDialog(),
      );

      if (result == true && mounted) {
        final enabled = await YubiKeyService.isEnabled();
        final publicId = await YubiKeyService.getPublicId();
        setState(() {
          _yubiKeyEnabled = enabled;
          _yubiKeyPublicId = publicId;
        });
        _showSnack('YubiKey added');
      }
    }
  }

  void _lockApp() {
    final provider = context.read<MultisigProvider>();
    provider.disconnect();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const UnlockScreen()),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    final provider = context.read<MultisigProvider>();
    provider.disconnect();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const InitScreen()),
      (route) => false,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MultisigProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ResponsiveContainer(
              maxWidth: 600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contracts
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CONTRACTS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                          letterSpacing: 0.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: _showAddContractDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 16, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Add',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._contracts.map((contract) => _ContractTile(
                    config: contract,
                    isActive: contract.id == _activeContract?.id,
                    onTap: () => _switchToContract(contract),
                    onEdit: () => _showEditContractDialog(contract),
                    onDelete: _contracts.length > 1 ? () => _deleteContract(contract) : null,
                  )),
                  const SizedBox(height: 32),

                  // Info
                  if (provider.info != null) ...[
                    const Text(
                      'CONTRACT INFO',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      label: 'USDT Token',
                      value: _shortAddress(provider.info!.usdtAddress),
                      fullValue: provider.info!.usdtAddress,
                    ),
                    _InfoRow(label: 'Owners', value: '${provider.info!.owners.length}'),
                    _InfoRow(label: 'Threshold', value: '${provider.info!.threshold}'),
                    const SizedBox(height: 32),
                  ],

                  // Security
                  const Text(
                    'SECURITY',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingTile(
                    icon: Icons.lock,
                    title: 'Lock App',
                    onTap: _lockApp,
                  ),
                  _SettingTile(
                    icon: Icons.key_outlined,
                    title: 'Change Password',
                    onTap: _showChangePasswordDialog,
                  ),
                  _SettingTile(
                    icon: Icons.security,
                    title: _yubiKeyEnabled ? 'YubiKey Enabled' : 'Add YubiKey',
                    subtitle: _yubiKeyEnabled && _yubiKeyPublicId != null
                        ? 'ID: $_yubiKeyPublicId'
                        : 'Hardware 2FA',
                    trailing: _yubiKeyEnabled
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                        : null,
                    onTap: _showYubiKeyDialog,
                  ),
                  _SettingTile(
                    icon: Icons.delete_outline,
                    title: 'Delete Wallet',
                    onTap: _showDeleteWalletDialog,
                  ),
                  const SizedBox(height: 32),

                  // Account
                  const Text(
                    'ACCOUNT',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (provider.userAddress != null)
                    _InfoRow(
                      label: 'Connected',
                      value: _shortAddress(provider.userAddress!),
                      fullValue: provider.userAddress!,
                    ),
                  _InfoRow(
                    label: 'Status',
                    value: provider.isOwner ? 'Owner' : 'View Only',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _logout,
                      child: const Text('Disconnect'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _shortAddress(String address) {
    return '${address.substring(0, 8)}...${address.substring(address.length - 6)}';
  }
}

class _AddYubiKeyDialog extends StatefulWidget {
  const _AddYubiKeyDialog();

  @override
  State<_AddYubiKeyDialog> createState() => _AddYubiKeyDialogState();
}

class _AddYubiKeyDialogState extends State<_AddYubiKeyDialog> {
  final _controller = TextEditingController();
  bool _isValid = false;
  String? _publicId;
  bool _isLoading = false;

  void _onChanged(String value) {
    setState(() {
      _isValid = YubiKeyService.isValidOtp(value);
      _publicId = _isValid ? YubiKeyService.extractPublicId(value) : null;
    });
  }

  Future<void> _save() async {
    if (!_isValid) return;

    setState(() => _isLoading = true);

    try {
      await YubiKeyService.savePublicId(_controller.text);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Add YubiKey'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Touch your YubiKey to register it for 2FA.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            autofocus: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Touch YubiKey here',
              suffixIcon: _isValid
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.key, color: Colors.black38),
            ),
          ),
          if (_publicId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.verified_user, size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  'Key ID: $_publicId',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: (_isValid && !_isLoading) ? _save : null,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String? fullValue;

  const _InfoRow({required this.label, required this.value, this.fullValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 15, fontFamily: fullValue != null ? 'monospace' : null),
              ),
              if (fullValue != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: fullValue!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Copied'),
                        backgroundColor: Colors.black,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  child: const Icon(Icons.copy_outlined, size: 16, color: Colors.black54),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.black),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

class _ContractTile extends StatelessWidget {
  final ContractConfig config;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _ContractTile({
    required this.config,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? Colors.black : Colors.grey.shade200,
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        config.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: config.networkType == NetworkType.evm 
                              ? Colors.blue.shade100 
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          config.networkType.displayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: config.networkType == NetworkType.evm 
                                ? Colors.blue.shade700 
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    config.shortAddress,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              color: Colors.black54,
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
                color: Colors.red.shade400,
              ),
          ],
        ),
      ),
    );
  }
}

class _AddContractDialog extends StatefulWidget {
  const _AddContractDialog();

  @override
  State<_AddContractDialog> createState() => _AddContractDialogState();
}

class _AddContractDialogState extends State<_AddContractDialog> {
  final _nameController = TextEditingController();
  final _rpcController = TextEditingController(text: 'http://localhost:8545');
  final _addressController = TextEditingController();
  NetworkType _networkType = NetworkType.evm;
  bool _isLoading = false;
  String? _error;

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final rpc = _rpcController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name for this contract');
      return;
    }
    if (rpc.isEmpty) {
      setState(() => _error = 'Please enter the RPC URL');
      return;
    }
    if (address.isEmpty) {
      setState(() => _error = 'Please enter the contract address');
      return;
    }

    // Validate address based on network type
    if (_networkType == NetworkType.evm) {
      if (!address.startsWith('0x') || address.length != 42) {
        setState(() => _error = 'Invalid EVM address (must start with 0x)');
        return;
      }
    } else if (_networkType == NetworkType.tvm) {
      if (!address.startsWith('T') || address.length != 34) {
        setState(() => _error = 'Invalid TRON address (must start with T)');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final config = await ContractsService.addContract(
        name: name,
        networkType: _networkType,
        rpcUrl: rpc,
        contractAddress: address,
      );
      if (mounted) Navigator.pop(context, config);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rpcController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Add Contract'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Name', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'My Multisig'),
            ),
            const SizedBox(height: 16),
            const Text('Network Type', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 8),
            Row(
              children: NetworkType.values.map((type) {
                final isSelected = _networkType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _networkType = type;
                      // Update RPC hint based on network
                      if (type == NetworkType.tvm) {
                        _rpcController.text = 'https://api.trongrid.io';
                      } else {
                        _rpcController.text = 'http://localhost:8545';
                      }
                    }),
                    child: Container(
                      margin: EdgeInsets.only(right: type != NetworkType.values.last ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('RPC URL', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 4),
            TextField(
              controller: _rpcController,
              decoration: InputDecoration(
                hintText: _networkType == NetworkType.tvm 
                    ? 'https://api.trongrid.io' 
                    : 'http://localhost:8545',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Contract Address', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 4),
            TextField(
              controller: _addressController,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration(
                hintText: _networkType == NetworkType.tvm ? 'T...' : '0x...',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

class _EditContractDialog extends StatefulWidget {
  final ContractConfig config;

  const _EditContractDialog({required this.config});

  @override
  State<_EditContractDialog> createState() => _EditContractDialogState();
}

class _EditContractDialogState extends State<_EditContractDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _rpcController;
  late final TextEditingController _addressController;
  late NetworkType _networkType;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.config.name);
    _rpcController = TextEditingController(text: widget.config.rpcUrl);
    _addressController = TextEditingController(text: widget.config.contractAddress);
    _networkType = widget.config.networkType;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final rpc = _rpcController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name for this contract');
      return;
    }
    if (rpc.isEmpty) {
      setState(() => _error = 'Please enter the RPC URL');
      return;
    }
    if (address.isEmpty) {
      setState(() => _error = 'Please enter the contract address');
      return;
    }

    // Validate address based on network type
    if (_networkType == NetworkType.evm) {
      if (!address.startsWith('0x') || address.length != 42) {
        setState(() => _error = 'Invalid EVM address (must start with 0x)');
        return;
      }
    } else if (_networkType == NetworkType.tvm) {
      if (!address.startsWith('T') || address.length != 34) {
        setState(() => _error = 'Invalid TRON address (must start with T)');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final updated = ContractConfig(
        id: widget.config.id,
        name: name,
        networkType: _networkType,
        rpcUrl: rpc,
        contractAddress: address,
      );
      await ContractsService.updateContract(updated);
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rpcController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Edit Contract'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Name', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'My Multisig'),
            ),
            const SizedBox(height: 16),
            const Text('Network Type', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 8),
            Row(
              children: NetworkType.values.map((type) {
                final isSelected = _networkType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _networkType = type),
                    child: Container(
                      margin: EdgeInsets.only(right: type != NetworkType.values.last ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('RPC URL', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 4),
            TextField(
              controller: _rpcController,
              decoration: InputDecoration(
                hintText: _networkType == NetworkType.tvm 
                    ? 'https://api.trongrid.io' 
                    : 'http://localhost:8545',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Contract Address', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 4),
            TextField(
              controller: _addressController,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration(
                hintText: _networkType == NetworkType.tvm ? 'T...' : '0x...',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
