import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/multisig_provider.dart';
import '../services/crypto_service.dart';
import '../services/yubikey_service.dart';
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
  bool _yubiKeyEnabled = false;
  String? _yubiKeyPublicId;
  bool _isMainnet = true;
  String _rpcUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final yubiEnabled = await YubiKeyService.isEnabled();
    final yubiId = await YubiKeyService.getPublicId();
    final config = await MultisigConfig.load();

    setState(() {
      _yubiKeyEnabled = yubiEnabled;
      _yubiKeyPublicId = yubiId;
      _isMainnet = config?.isMainnet ?? true;
      _rpcUrl = config?.rpcUrl ?? '';
    });
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
      await MultisigConfig.clear();
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

  Future<void> _resetConfiguration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reset Configuration'),
        content: const Text('This will reset the multisig account configuration. Your encrypted private key will be kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await MultisigConfig.clear();
      final provider = context.read<MultisigProvider>();
      provider.disconnect();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const InitScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showNetworkSwitchDialog() async {
    final selectedMainnet = await showDialog<bool>(
      context: context,
      builder: (context) => _NetworkSwitchDialog(isMainnet: _isMainnet),
    );

    if (selectedMainnet != null && selectedMainnet != _isMainnet && mounted) {
      // Show confirmation
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Switch Network'),
          content: Text(
            'Switch to ${selectedMainnet ? 'Mainnet' : 'Nile Testnet'}?\n\n'
            'Note: Your multisig address must exist on the target network.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        await MultisigConfig.updateNetwork(selectedMainnet);
        
        final config = await MultisigConfig.load();
        if (config != null && mounted) {
          final provider = context.read<MultisigProvider>();
          
          // Reinitialize with new network
          await provider.init(
            rpcUrl: config.rpcUrl,
            multisigAddress: config.multisigAddress,
            usdtAddress: config.usdtAddress,
          );

          setState(() {
            _isMainnet = selectedMainnet;
            _rpcUrl = config.rpcUrl;
          });

          _showSnack('Switched to ${selectedMainnet ? 'Mainnet' : 'Nile Testnet'}');
        }
      }
    }
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
                  // Network
                  const Text(
                    'NETWORK',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingTile(
                    icon: _isMainnet ? Icons.public : Icons.science,
                    title: _isMainnet ? 'Mainnet' : 'Nile Testnet',
                    subtitle: _rpcUrl,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isMainnet ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isMainnet ? 'LIVE' : 'TEST',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _isMainnet ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ),
                    onTap: _showNetworkSwitchDialog,
                  ),
                  const SizedBox(height: 32),

                  // Account Info
                  const Text(
                    'MULTISIG ACCOUNT',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (provider.multisigAddress != null)
                    _InfoRow(
                      label: 'Address',
                      value: _shortAddress(provider.multisigAddress!),
                      fullValue: provider.multisigAddress!,
                    ),
                  _InfoRow(label: 'Owners', value: '${provider.owners.length}'),
                  _InfoRow(label: 'Threshold', value: '${provider.threshold}'),
                  _InfoRow(
                    label: 'Status',
                    value: provider.isMultisigAccount ? 'Multisig Enabled' : 'Single Signature',
                  ),
                  const SizedBox(height: 16),
                  _SettingTile(
                    icon: Icons.refresh,
                    title: 'Reset Configuration',
                    subtitle: 'Change multisig account',
                    onTap: _resetConfiguration,
                  ),
                  const SizedBox(height: 32),

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
                    subtitle: 'Remove encrypted key',
                    onTap: _showDeleteWalletDialog,
                  ),
                  const SizedBox(height: 32),

                  // Connected Wallet
                  const Text(
                    'CONNECTED WALLET',
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
                      label: 'Address',
                      value: _shortAddress(provider.userAddress!),
                      fullValue: provider.userAddress!,
                    ),
                  _InfoRow(
                    label: 'Status',
                    value: provider.isOwner ? 'Signer' : 'Connected',
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

                  // About
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TRON Native Multisig',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This app uses TRON\'s built-in account permission system '
                          'for multi-signature functionality. No custom smart contract required.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      overflow: TextOverflow.ellipsis,
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

class _NetworkSwitchDialog extends StatefulWidget {
  final bool isMainnet;

  const _NetworkSwitchDialog({required this.isMainnet});

  @override
  State<_NetworkSwitchDialog> createState() => _NetworkSwitchDialogState();
}

class _NetworkSwitchDialogState extends State<_NetworkSwitchDialog> {
  late bool _selectedMainnet;

  @override
  void initState() {
    super.initState();
    _selectedMainnet = widget.isMainnet;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Select Network'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NetworkOption(
            title: 'Mainnet',
            subtitle: 'Production network',
            icon: Icons.public,
            isSelected: _selectedMainnet,
            color: Colors.green,
            onTap: () => setState(() => _selectedMainnet = true),
          ),
          const SizedBox(height: 12),
          _NetworkOption(
            title: 'Nile Testnet',
            subtitle: 'Testing network',
            icon: Icons.science,
            isSelected: !_selectedMainnet,
            color: Colors.orange,
            onTap: () => setState(() => _selectedMainnet = false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedMainnet),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

class _NetworkOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _NetworkOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? color.withOpacity(0.8) : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }
}
