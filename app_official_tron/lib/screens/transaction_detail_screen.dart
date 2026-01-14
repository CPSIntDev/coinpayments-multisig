import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/multisig_provider.dart';
import '../models/pending_transaction.dart';
import '../main.dart';

class TransactionDetailScreen extends StatefulWidget {
  final PendingTransaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late PendingTransaction _tx;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tx = widget.transaction;
  }

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

  Future<void> _signTransaction() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = context.read<MultisigProvider>();
      final success = await provider.signTransaction(_tx.id);

      if (success) {
        // Refresh transaction data
        final updated = provider.pendingTransactions.firstWhere(
          (t) => t.id == _tx.id,
          orElse: () => _tx,
        );
        setState(() => _tx = updated);
        _showSnack('Transaction signed successfully');
      } else {
        setState(() => _error = provider.error ?? 'Failed to sign');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _broadcastTransaction() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = context.read<MultisigProvider>();
      final txId = await provider.broadcastTransaction(_tx.id);

      if (txId != null) {
        _showSnack('Transaction broadcast successfully!');
        if (mounted) Navigator.pop(context);
      } else {
        setState(() => _error = provider.error ?? 'Failed to broadcast');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareTransaction() async {
    try {
      final provider = context.read<MultisigProvider>();
      final json = provider.exportTransaction(_tx.id);
      
      if (json != null) {
        await Clipboard.setData(ClipboardData(text: json));
        _showSnack('Transaction copied to clipboard. Share with other signers.');
      }
    } catch (e) {
      _showSnack('Failed to export: $e', isError: true);
    }
  }

  Future<void> _deleteTransaction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this pending transaction?'),
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

    if (confirmed == true) {
      final provider = context.read<MultisigProvider>();
      await provider.deleteTransaction(_tx.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MultisigProvider>();
    final hasSigned = provider.hasUserSigned(_tx.id);
    final canBroadcast = _tx.canBroadcast;
    final isExpired = _tx.isExpired;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Transaction'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareTransaction,
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteTransaction,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ResponsiveContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge
                  _buildStatusBadge(isExpired, canBroadcast, hasSigned),
                  const SizedBox(height: 24),

                  // Amount card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _tx.isPermissionUpdate ? Colors.purple.shade900 : Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _tx.isPermissionUpdate ? Icons.security : Icons.send,
                              color: Colors.white60,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _tx.isPermissionUpdate 
                                  ? 'Permission Update' 
                                  : 'TRX Transfer',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _tx.formattedAmount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1,
                          ),
                        ),
                        if (_tx.description != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _tx.description!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Details
                  _buildDetailRow('To', _tx.toAddress, isMono: true, canCopy: true),
                  _buildDetailRow('From', _tx.fromAddress, isMono: true, canCopy: true),
                  _buildDetailRow('TX ID', _tx.txId, isMono: true, canCopy: true),
                  _buildDetailRow('Created', _formatDateTime(_tx.createdAt)),
                  _buildDetailRow('Expires', _formatDateTime(_tx.expiresAt)),
                  
                  const SizedBox(height: 24),

                  // Signatures section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_document, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Signatures',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _tx.signatureCount >= _tx.threshold
                                    ? Colors.green
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_tx.signatureCount}/${_tx.threshold}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...(_tx.signers.map((signer) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 16, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _shortAddress(signer),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              if (signer.toLowerCase() == provider.userAddress?.toLowerCase())
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'You',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ))),
                        if (_tx.remainingSignatures > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${_tx.remainingSignatures} more signature(s) needed',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 20, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(fontSize: 14, color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Actions
                  if (!isExpired) ...[
                    // Show Sign button if user hasn't signed yet
                    // Any connected user can sign - the network validates if signature is valid
                    if (!hasSigned)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _signTransaction,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.edit),
                          label: const Text('Sign Transaction'),
                        ),
                      ),
                    if (canBroadcast) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _broadcastTransaction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send),
                          label: const Text('Broadcast to Network'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _shareTransaction,
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share with Signers'),
                      ),
                    ),
                  ],

                  if (isExpired) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_outlined, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This transaction has expired and can no longer be broadcast.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isExpired, bool canBroadcast, bool hasSigned) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String text;

    if (isExpired) {
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade700;
      icon = Icons.cancel_outlined;
      text = 'Expired';
    } else if (canBroadcast) {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade700;
      icon = Icons.check_circle_outline;
      text = 'Ready to Broadcast';
    } else if (!hasSigned) {
      bgColor = Colors.orange.shade100;
      textColor = Colors.orange.shade700;
      icon = Icons.pending_outlined;
      text = 'Needs Your Signature';
    } else {
      bgColor = Colors.blue.shade100;
      textColor = Colors.blue.shade700;
      icon = Icons.hourglass_empty;
      text = 'Waiting for Signatures';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMono = false, bool canCopy = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: isMono ? 'monospace' : null,
              ),
            ),
          ),
          if (canCopy)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                _showSnack('Copied');
              },
              child: const Icon(Icons.copy_outlined, size: 18, color: Colors.black45),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _shortAddress(String address) {
    if (address.length < 12) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 6)}';
  }
}
