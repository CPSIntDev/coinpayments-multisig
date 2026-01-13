import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/multisig_provider.dart';
import '../models/multisig_info.dart';
import '../services/contracts_service.dart';
import 'transactions_screen.dart';
import 'submit_transaction_screen.dart';
import 'owners_screen.dart';
import 'settings_screen.dart';
import 'unlock_screen.dart';
import 'transaction_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<ContractConfig> _contracts = [];
  ContractConfig? _activeContract;

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    final contracts = await ContractsService.getContracts();
    final active = await ContractsService.getActiveContract();
    if (mounted) {
      setState(() {
        _contracts = contracts;
        _activeContract = active;
      });
    }
  }

  Future<void> _switchContract(ContractConfig config) async {
    if (config.id == _activeContract?.id) return;

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
    final info = provider.info;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: provider.isLoading && info == null
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : RefreshIndicator(
                onRefresh: () => provider.loadData(),
                color: Colors.black,
                child: isWide
                    ? _buildWideLayout(context, provider, info)
                    : _buildNarrowLayout(context, provider, info),
              ),
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context, MultisigProvider provider, info) {
    final pendingTxs = provider.transactions.where((t) => !t.executed).toList();
    
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
            child: _buildBalanceCard(info),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildStatusBadge(provider.isOwner),
          ),
        ),
        // Deposit address (contract address)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: _buildContractAddressTile(context, provider),
          ),
        ),
        if (provider.userAddress != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _buildInfoTile(context, provider),
            ),
          ),
        // Pending transactions requiring action
        if (provider.isOwner && pendingTxs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: _buildSectionLabel('PENDING APPROVALS'),
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
            child: _buildActions(context, provider, info),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context, MultisigProvider provider, info) {
    final pendingTxs = provider.transactions.where((t) => !t.executed).toList();
    
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
                          _buildBalanceCard(info),
                          const SizedBox(height: 16),
                          _buildStatusBadge(provider.isOwner),
                          const SizedBox(height: 16),
                          _buildContractAddressTile(context, provider),
                          if (provider.userAddress != null) ...[
                            const SizedBox(height: 16),
                            _buildInfoTile(context, provider),
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
                            _buildSectionLabel('PENDING APPROVALS'),
                            const SizedBox(height: 16),
                            _PendingTransactionsList(
                              transactions: pendingTxs,
                              provider: provider,
                            ),
                            const SizedBox(height: 24),
                          ],
                          _buildSectionLabel('ACTIONS'),
                          const SizedBox(height: 16),
                          _buildActions(context, provider, info),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Wallet',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            Row(
              children: [
                _IconBtn(
                  icon: Icons.refresh,
                  isLoading: provider.isLoading,
                  onTap: provider.isLoading ? null : () => provider.loadData(),
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
                    _loadContracts(); // Refresh contracts after settings
                  },
                ),
              ],
            ),
          ],
        ),
        // Contract selector
        if (_contracts.length > 1) ...[
          const SizedBox(height: 12),
          _buildContractSelector(),
        ],
      ],
    );
  }

  Widget _buildContractSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _activeContract?.id,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          items: _contracts.map((contract) {
            return DropdownMenuItem<String>(
              value: contract.id,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: contract.id == _activeContract?.id 
                          ? Colors.green 
                          : Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              contract.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: contract.networkType == NetworkType.evm 
                                    ? Colors.blue.shade100 
                                    : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                contract.networkType.displayName,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: contract.networkType == NetworkType.evm 
                                      ? Colors.blue.shade700 
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          contract.shortAddress,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id != null) {
              final contract = _contracts.firstWhere((c) => c.id == id);
              _switchContract(contract);
            }
          },
        ),
      ),
    );
  }

  void _lockApp(BuildContext context, MultisigProvider provider) {
    provider.disconnect();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const UnlockScreen()),
      (route) => false,
    );
  }

  Widget _buildBalanceCard(MultisigInfo? info) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'USDT Balance',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${info?.formattedBalance ?? '0.00'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w600,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatChip(label: 'Owners', value: '${info?.owners.length ?? 0}'),
              const SizedBox(width: 12),
              _StatChip(label: 'Threshold', value: '${info?.threshold ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isOwner) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOwner ? Colors.black : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isOwner ? 'Owner Access' : 'View Only',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            isOwner ? 'Full control' : 'Limited access',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildContractAddressTile(BuildContext context, MultisigProvider provider) {
    final contractAddress = provider.contractAddress ?? '';
    final info = provider.info;
    final gasBalance = info?.formattedNativeBalance ?? '0';
    
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
                'Deposit Address',
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
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  gasBalance,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
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
                  contractAddress,
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
                  Clipboard.setData(ClipboardData(text: contractAddress));
                  _showSnack('Deposit address copied');
                },
                child: Icon(Icons.copy_outlined, size: 18, color: Colors.blue.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, MultisigProvider provider) {
    final address = provider.userAddress!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connected Wallet', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(
                _shortAddress(address),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, fontFamily: 'monospace'),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: address));
              _showSnack('Address copied');
            },
            child: const Icon(Icons.copy_outlined, size: 20, color: Colors.black54),
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

  Widget _buildActions(BuildContext context, MultisigProvider provider, info) {
    final pendingCount = provider.transactions.where((t) => !t.executed).length;
    
    return Column(
      children: [
        _ActionTile(
          icon: Icons.list_alt_outlined,
          title: 'Transactions',
          subtitle: pendingCount > 0 ? '$pendingCount pending' : 'View history',
          badge: pendingCount > 0 ? pendingCount : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TransactionsScreen()),
          ),
        ),
        _ActionTile(
          icon: Icons.people_outline,
          title: 'Owners',
          subtitle: '${info?.owners.length ?? 0} signers',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OwnersScreen()),
          ),
        ),
        if (provider.isOwner)
          _ActionTile(
            icon: Icons.send_outlined,
            title: 'Send',
            subtitle: 'Submit new transaction',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubmitTransactionScreen()),
            ),
          ),
      ],
    );
  }

  String _shortAddress(String address) {
    return '${address.substring(0, 8)}...${address.substring(address.length - 6)}';
  }
}

class _PendingTransactionsList extends StatefulWidget {
  final List transactions;
  final MultisigProvider provider;

  const _PendingTransactionsList({
    required this.transactions,
    required this.provider,
  });

  @override
  State<_PendingTransactionsList> createState() => _PendingTransactionsListState();
}

class _PendingTransactionsListState extends State<_PendingTransactionsList> {
  final Map<int, bool> _approvalCache = {};

  @override
  void initState() {
    super.initState();
    _loadApprovals();
  }

  Future<void> _loadApprovals() async {
    for (final tx in widget.transactions) {
      final approved = await widget.provider.isTransactionApproved(tx.id);
      if (mounted) {
        setState(() => _approvalCache[tx.id] = approved);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final threshold = widget.provider.info?.threshold ?? 2;
    
    // Sort: needs approval first, then already approved
    final sortedTxs = List.from(widget.transactions);
    sortedTxs.sort((a, b) {
      final aApproved = _approvalCache[a.id] ?? false;
      final bApproved = _approvalCache[b.id] ?? false;
      if (aApproved != bApproved) return aApproved ? 1 : -1;
      return b.id.compareTo(a.id);
    });

    // Only show first 3
    final displayTxs = sortedTxs.take(3).toList();

    return Column(
      children: [
        ...displayTxs.map((tx) {
          final hasApproved = _approvalCache[tx.id] ?? false;
          final approvalsNeeded = threshold - tx.approvalCount;
          final willExecuteNext = approvalsNeeded == 1;
          final isExpired = tx.isExpired;

          return GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionDetailScreen(transaction: tx),
                ),
              );
              _loadApprovals();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isExpired 
                    ? Colors.red.shade50 
                    : !hasApproved 
                        ? Colors.orange.shade50 
                        : Colors.grey.shade50,
                border: Border.all(
                  color: isExpired 
                      ? Colors.red.shade300 
                      : !hasApproved 
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
                          '\$${tx.formattedAmount}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'To: ${tx.shortAddress}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!hasApproved)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: willExecuteNext ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            willExecuteNext ? Icons.bolt : Icons.touch_app,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            willExecuteNext ? 'Execute' : 'Approve',
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
                        '${tx.approvalCount}/$threshold',
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
        
        if (widget.transactions.length > 3)
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
                    'View all ${widget.transactions.length} pending',
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
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: Colors.black),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
