import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/multisig_provider.dart';
import '../main.dart';

class TransactionDetailScreen extends StatefulWidget {
  final MultisigTransaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  bool _isApproved = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkApproval();
  }

  Future<void> _checkApproval() async {
    final provider = context.read<MultisigProvider>();
    final approved = await provider.isTransactionApproved(widget.transaction.id);
    debugPrint('[TxDetail] Tx #${widget.transaction.id} - isApproved by current user: $approved');
    debugPrint('[TxDetail] approvalCount: ${widget.transaction.approvalCount}, threshold: ${provider.info?.threshold}');
    if (mounted) setState(() => _isApproved = approved);
  }

  Future<void> _approve() async {
    setState(() => _isLoading = true);
    final provider = context.read<MultisigProvider>();
    final threshold = provider.info?.threshold ?? 0;
    final willExecute = widget.transaction.approvalCount + 1 >= threshold;
    
    debugPrint('[Approve] Starting approval for tx #${widget.transaction.id}');
    debugPrint('[Approve] Current approvals: ${widget.transaction.approvalCount}, threshold: $threshold');
    
    final txHash = await provider.approveTransaction(widget.transaction.id);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (txHash != null) {
      debugPrint('[Approve] Success! txHash: $txHash');
      // Transaction auto-executes when threshold is reached
      if (willExecute) {
        _showSnack('Transaction approved & executed!');
      } else {
        _showSnack('Transaction approved');
      }
      Navigator.pop(context);
    } else {
      // Show error to user
      final error = provider.error ?? 'Unknown error';
      debugPrint('[Approve] Failed: $error');
      _showSnack('Error: $error', isError: true);
    }
  }

  Future<void> _revoke() async {
    setState(() => _isLoading = true);
    final provider = context.read<MultisigProvider>();
    final txHash = await provider.revokeApproval(widget.transaction.id);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (txHash != null) {
      _showSnack('Approval revoked');
      Navigator.pop(context);
    }
  }

  Future<void> _cancel() async {
    setState(() => _isLoading = true);
    final provider = context.read<MultisigProvider>();
    final txHash = await provider.cancelExpiredTransaction(widget.transaction.id);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (txHash != null) {
      _showSnack('Transaction cancelled');
      Navigator.pop(context);
    } else {
      final error = provider.error ?? 'Unknown error';
      _showSnack('Error: $error', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.black,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 5 : 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MultisigProvider>();
    final tx = widget.transaction;
    final threshold = provider.info?.threshold ?? 0;
    final approvalsNeeded = threshold - tx.approvalCount;
    final willExecuteOnApprove = approvalsNeeded == 1 && !_isApproved;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Transaction #${tx.id}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: tx.executed 
                        ? Colors.grey.shade100 
                        : tx.isExpired 
                            ? Colors.red.shade50
                            : Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: tx.isExpired 
                        ? Border.all(color: Colors.red.shade300, width: 2)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        tx.executed 
                            ? Icons.check_circle_outline 
                            : tx.isExpired 
                                ? Icons.timer_off_outlined
                                : Icons.schedule,
                        size: 40,
                        color: tx.executed 
                            ? Colors.black 
                            : tx.isExpired 
                                ? Colors.red.shade700
                                : Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tx.status,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: tx.executed 
                              ? Colors.black 
                              : tx.isExpired 
                                  ? Colors.red.shade700
                                  : Colors.white,
                        ),
                      ),
                      if (!tx.executed && !tx.isExpired) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${tx.approvalCount} of $threshold signatures',
                          style: const TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        if (approvalsNeeded > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            approvalsNeeded == 1
                                ? '1 more approval to auto-execute'
                                : '$approvalsNeeded more approvals needed',
                            style: const TextStyle(fontSize: 12, color: Colors.white54),
                          ),
                        ],
                        if (tx.formattedTimeRemaining != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tx.formattedTimeRemaining!,
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ),
                        ],
                      ],
                      if (tx.isExpired) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Transaction has expired',
                          style: TextStyle(fontSize: 14, color: Colors.red.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Any owner can cancel this transaction',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Amount
                const Text(
                  'AMOUNT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${tx.formattedAmount}',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -1),
                ),
                const Text('USDT', style: TextStyle(fontSize: 15, color: Colors.black54)),
                const SizedBox(height: 24),

                // Recipient
                const Text(
                  'RECIPIENT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: tx.to));
                    _showSnack('Address copied');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tx.to,
                            style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_outlined, size: 18, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Actions
                if (provider.isOwner && !tx.executed) ...[
                  // Show cancel button for expired transactions
                  if (tx.isExpired) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_outlined, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This transaction is expired and can be cancelled',
                              style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _cancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Cancel Transaction'),
                      ),
                    ),
                  ] else ...[
                    // Normal approve/revoke actions for non-expired transactions
                    if (!_isApproved) ...[
                      // Show info if this approval will trigger execution
                      if (willExecuteOnApprove) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.bolt, color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your approval will trigger automatic execution',
                                  style: TextStyle(fontSize: 13, color: Colors.green.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _approve,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(willExecuteOnApprove ? 'Approve & Execute' : 'Approve'),
                        ),
                      ),
                    ],
                    if (_isApproved) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You have already approved this transaction',
                                style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _revoke,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Text('Revoke Approval'),
                        ),
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
