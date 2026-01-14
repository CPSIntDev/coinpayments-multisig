import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/multisig_provider.dart';
import '../main.dart';
import 'transaction_detail_screen.dart';

enum TokenType { trx, usdt }

class SubmitTransactionScreen extends StatefulWidget {
  const SubmitTransactionScreen({super.key});

  @override
  State<SubmitTransactionScreen> createState() => _SubmitTransactionScreenState();
}

class _SubmitTransactionScreenState extends State<SubmitTransactionScreen> {
  final _toController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  TokenType _selectedToken = TokenType.trx;

  @override
  void dispose() {
    _toController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final to = _toController.text.trim();
    final amountText = _amountController.text.trim();
    
    if (to.isEmpty || !to.startsWith('T') || to.length != 34) return false;
    
    try {
      final amount = double.parse(amountText);
      return amount > 0;
    } catch (e) {
      return false;
    }
  }

  String get _tokenSymbol => _selectedToken == TokenType.trx ? 'TRX' : 'USDT';
  
  int get _tokenDecimals => _selectedToken == TokenType.trx ? 6 : 6; // Both TRX and USDT use 6 decimals

  double _getBalance(MultisigProvider provider) {
    if (_selectedToken == TokenType.trx) {
      return provider.trxBalance.toDouble() / 1000000;
    } else {
      return provider.usdtBalance.toDouble() / 1000000;
    }
  }

  Future<void> _submit() async {
    final to = _toController.text.trim();
    final amountText = _amountController.text.trim();
    final description = _descriptionController.text.trim();

    if (to.isEmpty || !to.startsWith('T') || to.length != 34) {
      setState(() => _error = 'Invalid TRON address');
      return;
    }

    double amount;
    try {
      amount = double.parse(amountText);
      if (amount <= 0) {
        setState(() => _error = 'Amount must be greater than 0');
        return;
      }
    } catch (e) {
      setState(() => _error = 'Invalid amount');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = context.read<MultisigProvider>();
      
      // Convert to smallest unit (6 decimals for both TRX and USDT)
      final amountInSmallestUnit = BigInt.from(amount * 1000000);

      final pendingTx = _selectedToken == TokenType.trx
          ? await provider.createTrxTransfer(
              to: to,
              amount: amountInSmallestUnit,
              description: description.isNotEmpty ? description : null,
            )
          : await provider.createUsdtTransfer(
              to: to,
              amount: amountInSmallestUnit,
              description: description.isNotEmpty ? description : null,
            );

      if (!mounted) return;

      if (pendingTx != null) {
        // Navigate to transaction detail
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(transaction: pendingTx),
          ),
        );
      } else {
        setState(() => _error = provider.error ?? 'Failed to create transaction');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MultisigProvider>();
    final balance = _getBalance(provider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Send'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ResponsiveContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Token selector
                  const Text(
                    'Select Token',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TokenOption(
                          symbol: 'TRX',
                          name: 'TRON',
                          color: Colors.red,
                          isSelected: _selectedToken == TokenType.trx,
                          balance: provider.trxBalance.toDouble() / 1000000,
                          onTap: () => setState(() {
                            _selectedToken = TokenType.trx;
                            _amountController.clear();
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TokenOption(
                          symbol: 'USDT',
                          name: 'Tether',
                          color: Colors.green,
                          isSelected: _selectedToken == TokenType.usdt,
                          balance: provider.usdtBalance.toDouble() / 1000000,
                          onTap: () => setState(() {
                            _selectedToken = TokenType.usdt;
                            _amountController.clear();
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Balance display
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _selectedToken == TokenType.trx ? Colors.red.shade900 : Colors.green.shade800,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Available Balance',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _tokenSymbol,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          balance.toStringAsFixed(2),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recipient
                  const Text(
                    'Recipient Address',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _toController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'T...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste_outlined, size: 20),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _toController.text = data!.text!;
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Amount
                  Text(
                    'Amount ($_tokenSymbol)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      hintText: '0.00',
                      suffixText: _tokenSymbol,
                      suffixIcon: TextButton(
                        onPressed: () {
                          _amountController.text = balance.toStringAsFixed(6);
                          setState(() {});
                        },
                        child: const Text('MAX', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description (optional)
                  const Text(
                    'Description (optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'What is this payment for?',
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
                  const SizedBox(height: 32),

                  // Info box - workflow explanation
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
                              'How Multisig Works',
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
                          '1. You create and sign this transaction\n'
                          '2. Share it with other signers for approval\n'
                          '3. When ${provider.threshold} signatures are collected, broadcast it\n'
                          '4. Transaction executes on the network',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Expiration info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 18, color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Transactions expire in 5 minutes. Collect all signatures before then.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_isValid) ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Send $_tokenSymbol'),
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
}

class _TokenOption extends StatelessWidget {
  final String symbol;
  final String name;
  final Color color;
  final bool isSelected;
  final double balance;
  final VoidCallback onTap;

  const _TokenOption({
    required this.symbol,
    required this.name,
    required this.color,
    required this.isSelected,
    required this.balance,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      symbol[0],
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  symbol,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : Colors.black,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${balance.toStringAsFixed(2)} $symbol',
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? color.withOpacity(0.8) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
