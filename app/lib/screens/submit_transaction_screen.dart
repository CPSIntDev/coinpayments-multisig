import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/multisig_provider.dart';
import '../services/contracts_service.dart';
import '../main.dart';

class SubmitTransactionScreen extends StatefulWidget {
  const SubmitTransactionScreen({super.key});

  @override
  State<SubmitTransactionScreen> createState() => _SubmitTransactionScreenState();
}

class _SubmitTransactionScreenState extends State<SubmitTransactionScreen> {
  final _toController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  bool _isValidAddress(String address, NetworkType networkType) {
    if (networkType == NetworkType.tvm) {
      // TRON address: starts with T, 34 characters, base58
      return address.startsWith('T') && address.length == 34;
    } else {
      // EVM address: starts with 0x, 42 characters, hex
      return address.startsWith('0x') && address.length == 42;
    }
  }

  Future<void> _submit() async {
    final to = _toController.text.trim();
    final amountText = _amountController.text.trim();
    final provider = context.read<MultisigProvider>();
    final networkType = provider.networkType;

    if (to.isEmpty || amountText.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    if (!_isValidAddress(to, networkType)) {
      if (networkType == NetworkType.tvm) {
        setState(() => _error = 'Invalid TRON address (must start with T, 34 chars)');
      } else {
        setState(() => _error = 'Invalid EVM address (must start with 0x, 42 chars)');
      }
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Invalid amount');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final threshold = provider.info?.threshold ?? 2;
    final willAutoExecute = threshold == 1;
    
    final txHash = await provider.submitTransaction(to, amount);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (txHash != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(willAutoExecute 
            ? 'Transaction submitted & executed!' 
            : 'Transaction submitted & auto-approved'),
          backgroundColor: Colors.black,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    } else {
      setState(() => _error = provider.error ?? 'Failed to submit');
    }
  }

  @override
  void dispose() {
    _toController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MultisigProvider>();
    final threshold = provider.info?.threshold ?? 2;
    final owners = provider.info?.owners.length ?? 3;
    final willAutoExecute = threshold == 1;
    final approvalsNeeded = threshold - 1; // -1 because submitter auto-approves

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Send'),
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
                Text(
                  'RECIPIENT (${provider.networkType == NetworkType.tvm ? "TRON" : "EVM"})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _toController,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
                  decoration: InputDecoration(
                    hintText: provider.networkType == NetworkType.tvm ? 'T...' : '0x...',
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AMOUNT (USDT)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_error!, style: TextStyle(fontSize: 14, color: Colors.red.shade700)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(willAutoExecute ? 'Submit & Execute' : 'Submit Transaction'),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Info box about auto-approve behavior
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 20, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Auto-approve enabled',
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
                        'Your submission counts as 1 approval automatically.',
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Threshold info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        willAutoExecute ? Icons.bolt : Icons.people_outline, 
                        size: 20, 
                        color: willAutoExecute ? Colors.green.shade700 : Colors.black54,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          willAutoExecute
                            ? 'Transaction will execute immediately (threshold: 1)'
                            : 'Needs $approvalsNeeded more approval${approvalsNeeded > 1 ? 's' : ''} to execute ($threshold of $owners)',
                          style: TextStyle(
                            fontSize: 13, 
                            color: willAutoExecute ? Colors.green.shade700 : Colors.black54,
                          ),
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
    );
  }
}
