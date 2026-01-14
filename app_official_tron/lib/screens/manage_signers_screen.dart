import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/multisig_provider.dart';
import '../services/tron_native_multisig_service.dart';
import 'transaction_detail_screen.dart';

class ManageSignersScreen extends StatefulWidget {
  const ManageSignersScreen({super.key});

  @override
  State<ManageSignersScreen> createState() => _ManageSignersScreenState();
}

class _ManageSignersScreenState extends State<ManageSignersScreen> {
  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showAddSignerDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _AddSignerDialog(),
    );

    if (result != null && mounted) {
      final provider = context.read<MultisigProvider>();
      final pendingTx = await provider.addSigner(
        newSignerAddress: result['address'] as String,
        weight: result['weight'] as int,
        newThreshold: result['threshold'] as int?,
      );

      if (pendingTx != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(transaction: pendingTx),
          ),
        );
      } else if (provider.error != null) {
        _showSnack(provider.error!, isError: true);
      }
    }
  }

  Future<void> _showRemoveSignerDialog(String address) async {
    final provider = context.read<MultisigProvider>();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Remove Signer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to remove this signer?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                address,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will require ${provider.threshold} signature(s) to execute.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final pendingTx = await provider.removeSigner(signerToRemove: address);

      if (pendingTx != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(transaction: pendingTx),
          ),
        );
      } else if (provider.error != null) {
        _showSnack(provider.error!, isError: true);
      }
    }
  }

  Future<void> _showChangeThresholdDialog() async {
    final provider = context.read<MultisigProvider>();
    
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _ChangeThresholdDialog(
        currentThreshold: provider.threshold,
        maxThreshold: provider.owners.length,
      ),
    );

    if (result != null && mounted) {
      final pendingTx = await provider.updateThreshold(newThreshold: result);

      if (pendingTx != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(transaction: pendingTx),
          ),
        );
      } else if (provider.error != null) {
        _showSnack(provider.error!, isError: true);
      }
    }
  }

  Future<void> _showSetupMultisigDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _SetupMultisigDialog(),
    );

    if (result != null && mounted) {
      final provider = context.read<MultisigProvider>();
      final pendingTx = await provider.setupMultisig(
        signers: result['signers'] as List<SignerInfo>,
        threshold: result['threshold'] as int,
      );

      if (pendingTx != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(transaction: pendingTx),
          ),
        );
      } else if (provider.error != null) {
        _showSnack(provider.error!, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Manage Signers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<MultisigProvider>(
        builder: (context, provider, _) {
          final accountInfo = provider.accountInfo;
          final isMultisig = provider.isMultisigAccount;
          
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Current status
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isMultisig ? Colors.green.shade50 : Colors.orange.shade50,
                  border: Border.all(
                    color: isMultisig ? Colors.green.shade200 : Colors.orange.shade200,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      isMultisig ? Icons.verified_user : Icons.warning_outlined,
                      size: 48,
                      color: isMultisig ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isMultisig ? 'Multisig Active' : 'Single Signature',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isMultisig ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isMultisig 
                          ? '${provider.owners.length} signers, threshold ${provider.threshold}'
                          : 'This account is not configured for multisig',
                      style: TextStyle(
                        fontSize: 14,
                        color: isMultisig ? Colors.green.shade600 : Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Setup multisig button (if not already multisig)
              if (!isMultisig && provider.isOwner) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showSetupMultisigDialog,
                    icon: const Icon(Icons.security),
                    label: const Text('Setup Multisig'),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Current signers
              if (accountInfo != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SIGNERS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (provider.isOwner)
                      GestureDetector(
                        onTap: _showAddSignerDialog,
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

                // Signers list
                ...provider.owners.map((owner) {
                  final isCurrentUser = owner.toLowerCase() == provider.userAddress?.toLowerCase();
                  final weight = _getSignerWeight(accountInfo, owner);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isCurrentUser ? Colors.blue.shade200 : Colors.grey.shade200,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isCurrentUser ? Colors.blue.shade50 : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCurrentUser ? Colors.blue.shade100 : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: isCurrentUser ? Colors.blue : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${owner.substring(0, 8)}...${owner.substring(owner.length - 6)}',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (isCurrentUser)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'You',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Weight: $weight',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: owner));
                            _showSnack('Address copied');
                          },
                          child: const Icon(Icons.copy_outlined, size: 18, color: Colors.black45),
                        ),
                        if (provider.isOwner && provider.owners.length > 1) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showRemoveSignerDialog(owner),
                            child: Icon(Icons.remove_circle_outline, size: 20, color: Colors.red.shade400),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // Threshold management
                if (provider.isOwner && isMultisig) ...[
                  const Text(
                    'THRESHOLD',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showChangeThresholdDialog,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.how_to_vote, color: Colors.orange.shade700),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${provider.threshold} of ${provider.owners.length} required',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Tap to change threshold',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.black26),
                        ],
                      ),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 32),

              // Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Changes to signers require approval from the current owners. '
                      'Each signer has a weight, and the threshold is the minimum total weight needed to approve transactions.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _getSignerWeight(dynamic accountInfo, String address) {
    if (accountInfo?.ownerPermission != null) {
      for (final key in accountInfo.ownerPermission.keys) {
        if (key.address.toLowerCase() == address.toLowerCase()) {
          return key.weight;
        }
      }
    }
    return 1;
  }
}

class _AddSignerDialog extends StatefulWidget {
  const _AddSignerDialog();

  @override
  State<_AddSignerDialog> createState() => _AddSignerDialogState();
}

class _AddSignerDialogState extends State<_AddSignerDialog> {
  final _addressController = TextEditingController();
  int _weight = 1;
  bool _updateThreshold = false;
  int? _newThreshold;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final address = _addressController.text.trim();
    return address.startsWith('T') && address.length == 34;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MultisigProvider>();
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Add Signer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Address', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 4),
            TextField(
              controller: _addressController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: const InputDecoration(hintText: 'T...'),
            ),
            const SizedBox(height: 16),
            const Text('Weight', style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 8),
            Row(
              children: [1, 2, 3, 5, 10].map((w) {
                final isSelected = _weight == w;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _weight = w),
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$w',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Update threshold', style: TextStyle(fontSize: 14)),
              value: _updateThreshold,
              onChanged: (v) => setState(() {
                _updateThreshold = v;
                _newThreshold = v ? provider.threshold : null;
              }),
              contentPadding: EdgeInsets.zero,
            ),
            if (_updateThreshold) ...[
              const SizedBox(height: 8),
              Text(
                'New threshold: ${_newThreshold ?? provider.threshold}',
                style: const TextStyle(fontSize: 13),
              ),
              Slider(
                value: (_newThreshold ?? provider.threshold).toDouble(),
                min: 1,
                max: (provider.owners.length + 1).toDouble(),
                divisions: provider.owners.length,
                onChanged: (v) => setState(() => _newThreshold = v.round()),
              ),
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
          onPressed: _isValid
              ? () => Navigator.pop(context, {
                    'address': _addressController.text.trim(),
                    'weight': _weight,
                    'threshold': _updateThreshold ? _newThreshold : null,
                  })
              : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _ChangeThresholdDialog extends StatefulWidget {
  final int currentThreshold;
  final int maxThreshold;

  const _ChangeThresholdDialog({
    required this.currentThreshold,
    required this.maxThreshold,
  });

  @override
  State<_ChangeThresholdDialog> createState() => _ChangeThresholdDialogState();
}

class _ChangeThresholdDialogState extends State<_ChangeThresholdDialog> {
  late int _threshold;

  @override
  void initState() {
    super.initState();
    _threshold = widget.currentThreshold;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Change Threshold'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_threshold of ${widget.maxThreshold}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'signatures required',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Slider(
            value: _threshold.toDouble(),
            min: 1,
            max: widget.maxThreshold.toDouble(),
            divisions: widget.maxThreshold - 1 > 0 ? widget.maxThreshold - 1 : 1,
            onChanged: (v) => setState(() => _threshold = v.round()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _threshold != widget.currentThreshold
              ? () => Navigator.pop(context, _threshold)
              : null,
          child: const Text('Update'),
        ),
      ],
    );
  }
}

class _SetupMultisigDialog extends StatefulWidget {
  const _SetupMultisigDialog();

  @override
  State<_SetupMultisigDialog> createState() => _SetupMultisigDialogState();
}

class _SetupMultisigDialogState extends State<_SetupMultisigDialog> {
  final List<_SignerEntry> _signers = [];
  int _threshold = 1;

  @override
  void initState() {
    super.initState();
    // Add current user as first signer
    final provider = context.read<MultisigProvider>();
    if (provider.userAddress != null) {
      _signers.add(_SignerEntry(address: provider.userAddress!, weight: 1));
    }
  }

  void _addSigner() {
    setState(() {
      _signers.add(_SignerEntry(address: '', weight: 1));
    });
  }

  void _removeSigner(int index) {
    if (_signers.length > 1) {
      setState(() {
        _signers.removeAt(index);
        if (_threshold > _signers.length) {
          _threshold = _signers.length;
        }
      });
    }
  }

  bool get _isValid {
    return _signers.isNotEmpty &&
        _signers.every((s) => s.address.startsWith('T') && s.address.length == 34) &&
        _threshold >= 1 &&
        _threshold <= _signers.length;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Setup Multisig'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add signers and set the required threshold.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              const Text('SIGNERS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 8),
              ..._signers.asMap().entries.map((entry) {
                final index = entry.key;
                final signer = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: signer.address),
                          onChanged: (v) => setState(() => _signers[index].address = v),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'T...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: signer.weight,
                                      isDense: true,
                                      items: [1, 2, 3, 5, 10].map((w) => DropdownMenuItem(
                                        value: w,
                                        child: Text('$w', style: const TextStyle(fontSize: 12)),
                                      )).toList(),
                                      onChanged: (v) => setState(() => _signers[index].weight = v ?? 1),
                                    ),
                                  ),
                                ),
                                if (_signers.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, size: 18, color: Colors.red),
                                    onPressed: () => _removeSigner(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addSigner,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Signer'),
              ),
              const SizedBox(height: 16),
              const Text('THRESHOLD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '$_threshold of ${_signers.length}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Expanded(
                    child: Slider(
                      value: _threshold.toDouble(),
                      min: 1,
                      max: _signers.isNotEmpty ? _signers.length.toDouble() : 1,
                      divisions: _signers.length > 1 ? _signers.length - 1 : 1,
                      onChanged: (v) => setState(() => _threshold = v.round()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isValid
              ? () => Navigator.pop(context, {
                    'signers': _signers.map((s) => SignerInfo(address: s.address, weight: s.weight)).toList(),
                    'threshold': _threshold,
                  })
              : null,
          child: const Text('Setup'),
        ),
      ],
    );
  }
}

class _SignerEntry {
  String address;
  int weight;

  _SignerEntry({required this.address, required this.weight});
}
