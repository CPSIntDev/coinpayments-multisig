import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/multisig_provider.dart';
import '../models/transaction.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  // Cache of approval status for current user
  final Map<int, bool> _approvalCache = {};

  @override
  void initState() {
    super.initState();
    _loadApprovalStatus();
  }

  Future<void> _loadApprovalStatus() async {
    final provider = context.read<MultisigProvider>();
    for (final tx in provider.transactions) {
      if (!tx.executed) {
        final approved = await provider.isTransactionApproved(tx.id);
        if (mounted) {
          setState(() => _approvalCache[tx.id] = approved);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MultisigProvider>();
    final transactions = provider.transactions;
    final threshold = provider.info?.threshold ?? 2;
    final isOwner = provider.isOwner;

    // Separate pending and executed
    final pending = transactions.where((t) => !t.executed).toList();
    final executed = transactions.where((t) => t.executed).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Transactions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (provider.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              ),
            ),
        ],
      ),
      body: transactions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions',
                    style: TextStyle(fontSize: 17, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await provider.loadData();
                await _loadApprovalStatus();
              },
              color: Colors.black,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Pending transactions section
                      if (pending.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'PENDING',
                          count: pending.length,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        ...pending.map((tx) => _TransactionCard(
                          transaction: tx,
                          threshold: threshold,
                          isOwner: isOwner,
                          hasApproved: _approvalCache[tx.id] ?? false,
                          onTap: () => _openDetail(tx),
                        )),
                        const SizedBox(height: 24),
                      ],
                      
                      // Executed transactions section
                      if (executed.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'EXECUTED',
                          count: executed.length,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 12),
                        ...executed.map((tx) => _TransactionCard(
                          transaction: tx,
                          threshold: threshold,
                          isOwner: isOwner,
                          hasApproved: true,
                          onTap: () => _openDetail(tx),
                        )),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  void _openDetail(MultisigTransaction tx) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transaction: tx),
      ),
    );
    // Reload approval status when returning
    if (mounted) {
      _loadApprovalStatus();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final MultisigTransaction transaction;
  final int threshold;
  final bool isOwner;
  final bool hasApproved;
  final VoidCallback onTap;

  const _TransactionCard({
    required this.transaction,
    required this.threshold,
    required this.isOwner,
    required this.hasApproved,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final approvalsNeeded = threshold - tx.approvalCount;
    final needsYourApproval = isOwner && !tx.executed && !hasApproved;
    final willExecuteNext = approvalsNeeded == 1;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: needsYourApproval ? Colors.orange.shade300 : Colors.grey.shade200,
            width: needsYourApproval ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tx.executed ? Colors.green.shade100 : Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    tx.executed ? Icons.check : Icons.schedule,
                    size: 20,
                    color: tx.executed ? Colors.green.shade700 : Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To: ${tx.shortAddress}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${tx.formattedAmount} USDT',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                
                // Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('#${tx.id}', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    if (tx.executed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Executed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade700,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: willExecuteNext ? Colors.orange.shade100 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${tx.approvalCount}/$threshold',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: willExecuteNext ? Colors.orange.shade700 : Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            
            // Action needed banner
            if (needsYourApproval) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: willExecuteNext ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      willExecuteNext ? Icons.bolt : Icons.touch_app,
                      size: 16,
                      color: willExecuteNext ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        willExecuteNext
                            ? 'Your approval will execute this transaction!'
                            : 'Needs your approval',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: willExecuteNext ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: willExecuteNext ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ],
                ),
              ),
            ],
            
            // Already approved badge
            if (isOwner && !tx.executed && hasApproved) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'You approved • Waiting for $approvalsNeeded more',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
