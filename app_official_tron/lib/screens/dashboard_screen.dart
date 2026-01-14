import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/multisig_provider.dart';
import '../models/pending_transaction.dart';
import '../services/crypto_service.dart';
import '../main.dart';
import 'transactions_screen.dart';
import 'submit_transaction_screen.dart';
import 'owners_screen.dart';
import 'manage_signers_screen.dart';
import 'settings_screen.dart';
import 'unlock_screen.dart';
import 'transaction_detail_screen.dart';
import 'import_transaction_screen.dart';

class _NetworkInfo {
  final bool isMainnet;
  _NetworkInfo({required this.isMainnet});
}

Future<_NetworkInfo> _getNetworkInfo() async {
  final config = await MultisigConfig.load();
  return _NetworkInfo(isMainnet: config?.isMainnet ?? true);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
    final accountInfo = provider.accountInfo;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: provider.isLoading && accountInfo == null
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : RefreshIndicator(
                onRefresh: () => provider.loadAccountData(),
                color: Colors.black,
                child: isWide
                    ? _buildWideLayout(context, provider)
                    : _buildNarrowLayout(context, provider),
              ),
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context, MultisigProvider provider) {
    final pendingTxs = provider.activePendingTransactions;
    
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: _buildHeader(context, provider),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildBalanceCard(provider),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildStatusBadge(provider),
          ),
        ),
        // Connected wallet address (this IS the account)
        if (provider.userAddress != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _buildWalletTile(context, provider),
            ),
          ),
        // Pending transactions requiring signatures
        if (provider.isOwner && pendingTxs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: _buildSectionLabel('PENDING SIGNATURES'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _PendingTransactionsList(
                transactions: pendingTxs,
                provider: provider,
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
            child: _buildSectionLabel('ACTIONS'),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildActions(context, provider),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context, MultisigProvider provider) {
    final pendingTxs = provider.activePendingTransactions;
    
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, provider),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildBalanceCard(provider),
                          const SizedBox(height: 16),
                          _buildStatusBadge(provider),
                          if (provider.userAddress != null) ...[
                            const SizedBox(height: 16),
                            _buildWalletTile(context, provider),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right column
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pending transactions
                          if (provider.isOwner && pendingTxs.isNotEmpty) ...[
                            _buildSectionLabel('PENDING SIGNATURES'),
                            const SizedBox(height: 16),
                            _PendingTransactionsList(
                              transactions: pendingTxs,
                              provider: provider,
                            ),
                            const SizedBox(height: 24),
                          ],
                          _buildSectionLabel('ACTIONS'),
                          const SizedBox(height: 16),
                          _buildActions(context, provider),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, MultisigProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'Wallet',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 12),
            FutureBuilder<_NetworkInfo>(
              future: _getNetworkInfo(),
              builder: (context, snapshot) {
                final isMainnet = snapshot.data?.isMainnet ?? true;
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                    setState(() {}); // Refresh on return
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMainnet ? Colors.green.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isMainnet ? 'MAINNET' : 'TESTNET',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isMainnet ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        Row(
          children: [
            _IconBtn(
              icon: Icons.refresh,
              isLoading: provider.isLoading,
              onTap: provider.isLoading ? null : () => provider.loadAccountData(),
            ),
            const SizedBox(width: 8),
            _IconBtn(
              icon: Icons.lock_outline,
              onTap: () => _lockApp(context, provider),
            ),
            const SizedBox(width: 8),
            _IconBtn(
              icon: Icons.settings_outlined,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                setState(() {}); // Refresh network indicator
              },
            ),
          ],
        ),
      ],
    );
  }

  void _lockApp(BuildContext context, MultisigProvider provider) {
    provider.disconnect();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const UnlockScreen()),
      (route) => false,
    );
  }

  Widget _buildBalanceCard(MultisigProvider provider) {
    final trxBalance = provider.trxBalance.toDouble() / 1000000;
    final usdtBalance = provider.usdtBalance.toDouble() / 1000000;
    final accountInfo = provider.accountInfo;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TRX Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TRX',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trxBalance.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'TRX',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.white.withAlpha(20),
          ),
          const SizedBox(height: 16),
          // USDT Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'USDT',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    usdtBalance.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'USDT',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatChip(label: 'Signers', value: '${provider.owners.length}'),
              const SizedBox(width: 12),
              _StatChip(label: 'Threshold', value: '${provider.threshold}'),
              if (accountInfo != null && accountInfo.isMultisig) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Multisig',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(MultisigProvider provider) {
    final isSigner = provider.isOwner;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSigner ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSigner ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSigner ? Colors.green.shade100 : Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSigner ? Icons.check : Icons.visibility_outlined,
              size: 18,
              color: isSigner ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSigner ? 'Signer' : 'Observer',
                  style: TextStyle(
                    fontSize: 15, 
                    fontWeight: FontWeight.w600,
                    color: isSigner ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isSigner 
                      ? 'You can sign and approve transactions' 
                      : 'Connected wallet is not a signer',
                  style: TextStyle(
                    fontSize: 12, 
                    color: isSigner ? Colors.green.shade600 : Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletTile(BuildContext context, MultisigProvider provider) {
    final address = provider.userAddress!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Account',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'TRON',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: address));
                  _showSnack('Address copied');
                },
                child: Icon(Icons.copy_outlined, size: 18, color: Colors.blue.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade500,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildActions(BuildContext context, MultisigProvider provider) {
    final pendingCount = provider.activePendingTransactions.length;
    
    return Column(
      children: [
        if (provider.isOwner) ...[
          _ActionTile(
            icon: Icons.send_outlined,
            title: 'Send',
            subtitle: 'Transfer TRX or USDT',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubmitTransactionScreen()),
            ),
          ),
        ],
        _ActionTile(
          icon: Icons.list_alt_outlined,
          title: 'Transactions',
          subtitle: pendingCount > 0 ? '$pendingCount pending approval' : 'View pending & history',
          badge: pendingCount > 0 ? pendingCount : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TransactionsScreen()),
          ),
        ),
        _ActionTile(
          icon: Icons.people_outline,
          title: 'Signers',
          subtitle: provider.isMultisigAccount 
              ? '${provider.owners.length} signers, threshold ${provider.threshold}'
              : 'Single signature (not multisig)',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OwnersScreen()),
          ),
        ),
        // Show Setup Multisig prominently for non-multisig accounts
        if (provider.isOwner && !provider.isMultisigAccount) ...[
          _ActionTile(
            icon: Icons.security,
            title: 'Setup Multisig',
            subtitle: 'Add signers and enable multi-signature',
            highlight: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageSignersScreen()),
            ),
          ),
        ],
        if (provider.isOwner && provider.isMultisigAccount) ...[
          _ActionTile(
            icon: Icons.person_add_outlined,
            title: 'Manage Signers',
            subtitle: 'Add/remove signers, change threshold',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageSignersScreen()),
            ),
          ),
        ],
        // Import Transaction always available for connected users
        // Any signer needs to be able to import and co-sign transactions
        _ActionTile(
          icon: Icons.download_outlined,
          title: 'Import Transaction',
          subtitle: 'Import from another signer to co-sign',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ImportTransactionScreen()),
          ),
        ),
        const SizedBox(height: 16),
        // Full Reset
        _ActionTile(
          icon: Icons.restart_alt,
          title: 'Full Reset',
          subtitle: 'Clear all data and start fresh',
          isDanger: true,
          onTap: () => _showFullResetDialog(context),
        ),
      ],
    );
  }

  Future<void> _showFullResetDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Full Reset'),
        content: const Text(
          'This will delete:\n\n'
          '• Your encrypted private key\n'
          '• All pending transactions\n'
          '• All app configuration\n\n'
          'You will need to re-enter your private key to use the app again.\n\n'
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Clear all data
      await CryptoService.deleteWallet();
      await MultisigConfig.clear();
      
      // Clear all SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      if (!context.mounted) return;
      
      final provider = context.read<MultisigProvider>();
      provider.disconnect();
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const InitScreen()),
        (route) => false,
      );
    }
  }

}

class _PendingTransactionsList extends StatelessWidget {
  final List<PendingTransaction> transactions;
  final MultisigProvider provider;

  const _PendingTransactionsList({
    required this.transactions,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    // Sort: needs signature first, then ready to broadcast
    final sortedTxs = List<PendingTransaction>.from(transactions);
    sortedTxs.sort((a, b) {
      // Prioritize those that need your signature
      final aSignedByUser = provider.hasUserSigned(a.id);
      final bSignedByUser = provider.hasUserSigned(b.id);
      if (aSignedByUser != bSignedByUser) return aSignedByUser ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });

    // Only show first 3
    final displayTxs = sortedTxs.take(3).toList();

    return Column(
      children: [
        ...displayTxs.map((tx) {
          final hasSigned = provider.hasUserSigned(tx.id);
          final canBroadcast = tx.canBroadcast;
          final isExpired = tx.isExpired;

          return GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionDetailScreen(transaction: tx),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isExpired 
                    ? Colors.red.shade50 
                    : canBroadcast
                        ? Colors.green.shade50
                        : !hasSigned 
                            ? Colors.orange.shade50 
                            : Colors.grey.shade50,
                border: Border.all(
                  color: isExpired 
                      ? Colors.red.shade300 
                      : canBroadcast
                          ? Colors.green.shade300
                          : !hasSigned 
                              ? Colors.orange.shade300 
                              : Colors.grey.shade200,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  // Amount
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.formattedAmount,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'To: ${tx.shortToAddress}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (tx.formattedTimeRemaining != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              tx.formattedTimeRemaining!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Status
                  if (isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Expired',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else if (canBroadcast)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.send, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Broadcast',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!hasSigned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Sign (${tx.signatureCount}/${tx.threshold})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${tx.signatureCount}/${tx.threshold} signed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        
        if (transactions.length > 3)
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TransactionsScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View all ${transactions.length} pending',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  const _IconBtn({required this.icon, this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Icon(icon, size: 20, color: Colors.black),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int? badge;
  final bool highlight;
  final bool isDanger;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.highlight = false,
    this.isDanger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color getBgColor() {
      if (isDanger) return Colors.red.shade50;
      if (highlight) return Colors.green.shade50;
      return Colors.transparent;
    }
    
    Color getBorderColor() {
      if (isDanger) return Colors.red.shade300;
      if (highlight) return Colors.green.shade300;
      return Colors.grey.shade200;
    }
    
    Color getIconBgColor() {
      if (isDanger) return Colors.red.shade100;
      if (highlight) return Colors.green.shade100;
      return Colors.grey.shade100;
    }
    
    Color getIconColor() {
      if (isDanger) return Colors.red.shade700;
      if (highlight) return Colors.green.shade700;
      return Colors.black;
    }
    
    Color getTitleColor() {
      if (isDanger) return Colors.red.shade700;
      if (highlight) return Colors.green.shade700;
      return Colors.black;
    }
    
    Color getSubtitleColor() {
      if (isDanger) return Colors.red.shade600;
      if (highlight) return Colors.green.shade600;
      return Colors.grey.shade600;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: getBgColor(),
          border: Border.all(color: getBorderColor()),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: getIconBgColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: getIconColor()),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: getTitleColor())),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: getSubtitleColor())),
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
