import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/multisig_provider.dart';
import '../models/pending_transaction.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Transactions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<MultisigProvider>(
        builder: (context, provider, _) {
          final transactions = provider.pendingTransactions;
          
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a transaction or import one\nfrom another signer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group transactions by status
          final pending = transactions.where((t) => t.isPending).toList();
          final ready = transactions.where((t) => t.canBroadcast).toList();
          final broadcast = transactions.where((t) => t.status == PendingTxStatus.broadcast).toList();
          final expired = transactions.where((t) => t.isExpired || t.status == PendingTxStatus.expired).toList();
          final failed = transactions.where((t) => t.status == PendingTxStatus.failed).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (ready.isNotEmpty) ...[
                _buildSectionHeader('Ready to Broadcast', ready.length, Colors.green),
                ...ready.map((tx) => _TransactionTile(transaction: tx, provider: provider)),
                const SizedBox(height: 16),
              ],
              if (pending.isNotEmpty) ...[
                _buildSectionHeader('Pending Signatures', pending.length, Colors.orange),
                ...pending.map((tx) => _TransactionTile(transaction: tx, provider: provider)),
                const SizedBox(height: 16),
              ],
              if (broadcast.isNotEmpty) ...[
                _buildSectionHeader('Broadcast', broadcast.length, Colors.blue),
                ...broadcast.map((tx) => _TransactionTile(transaction: tx, provider: provider)),
                const SizedBox(height: 16),
              ],
              if (expired.isNotEmpty) ...[
                _buildSectionHeader('Expired', expired.length, Colors.grey),
                ...expired.map((tx) => _TransactionTile(transaction: tx, provider: provider)),
                const SizedBox(height: 16),
              ],
              if (failed.isNotEmpty) ...[
                _buildSectionHeader('Failed', failed.length, Colors.red),
                ...failed.map((tx) => _TransactionTile(transaction: tx, provider: provider)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
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
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(50),
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
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final PendingTransaction transaction;
  final MultisigProvider provider;

  const _TransactionTile({
    required this.transaction,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final hasSigned = provider.hasUserSigned(transaction.id);
    final isExpired = transaction.isExpired;
    final canBroadcast = transaction.canBroadcast;

    Color bgColor;
    Color borderColor;
    
    if (isExpired) {
      bgColor = Colors.grey.shade50;
      borderColor = Colors.grey.shade200;
    } else if (canBroadcast) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
    } else if (!hasSigned) {
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
    } else {
      bgColor = Colors.white;
      borderColor = Colors.grey.shade200;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionDetailScreen(transaction: transaction),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Amount
                Text(
                  transaction.formattedAmount,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isExpired ? Colors.grey : Colors.black,
                  ),
                ),
                // Status badge
                _buildStatusBadge(isExpired, canBroadcast, hasSigned),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    transaction.toAddress,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (transaction.description != null) ...[
              const SizedBox(height: 6),
              Text(
                transaction.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.edit_document, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  '${transaction.signatureCount}/${transaction.threshold} signatures',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                if (transaction.formattedTimeRemaining != null)
                  Text(
                    transaction.formattedTimeRemaining!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isExpired, bool canBroadcast, bool hasSigned) {
    if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Expired',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      );
    }

    if (canBroadcast) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.send, size: 12, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Ready',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (!hasSigned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit, size: 12, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Sign',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Signed',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }
}
