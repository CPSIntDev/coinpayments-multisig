import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/multisig_provider.dart';
import '../services/crypto_service.dart';
import '../services/yubikey_service.dart';
import '../main.dart';

class ConnectWalletScreen extends StatefulWidget {
  const ConnectWalletScreen({super.key});

  @override
  State<ConnectWalletScreen> createState() => _ConnectWalletScreenState();
}

class _ConnectWalletScreenState extends State<ConnectWalletScreen> {
  final _privateKeyController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _yubiKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _enableYubiKey = false;
  String? _error;
  String? _yubiKeyPublicId;

  bool get _isValid {
    final key = _privateKeyController.text.trim();
    final normalizedKey = key.startsWith('0x') ? key.substring(2) : key;
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    
    final keyValid = normalizedKey.length == 64 &&
        RegExp(r'^[a-fA-F0-9]+$').hasMatch(normalizedKey);
    final passwordValid = password.length >= 6;
    final passwordsMatch = password == confirm && confirm.isNotEmpty;
    
    final basicValid = keyValid && passwordValid && passwordsMatch;
    
    if (_enableYubiKey) {
      return basicValid && _yubiKeyPublicId != null;
    }
    return basicValid;
  }

  @override
  void dispose() {
    _privateKeyController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _yubiKeyController.dispose();
    super.dispose();
  }

  void _onYubiKeyChanged(String value) {
    setState(() {
      if (YubiKeyService.isValidOtp(value)) {
        _yubiKeyPublicId = YubiKeyService.extractPublicId(value);
      } else {
        _yubiKeyPublicId = null;
      }
    });
  }

  Future<void> _connect() async {
    String key = _privateKeyController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Normalize key
    String normalizedKey = key.startsWith('0x') ? key.substring(2) : key;

    if (normalizedKey.length != 64) {
      setState(() => _error = 'Private key must be 64 hex characters');
      return;
    }

    if (!RegExp(r'^[a-fA-F0-9]+$').hasMatch(normalizedKey)) {
      setState(() => _error = 'Private key must be valid hex');
      return;
    }

    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    if (_enableYubiKey && _yubiKeyPublicId == null) {
      setState(() => _error = 'Please touch your YubiKey to register it');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // FIRST save the encrypted key (before connectWallet which triggers rebuild)
      debugPrint('Saving encrypted key...');
      await CryptoService.saveEncryptedKey(normalizedKey, password);
      debugPrint('Encrypted key saved!');
      
      // Save YubiKey if enabled
      if (_enableYubiKey && _yubiKeyController.text.isNotEmpty) {
        await YubiKeyService.savePublicId(_yubiKeyController.text);
      }

      // Verify save worked
      final hasWallet = await CryptoService.hasWallet();
      debugPrint('Wallet setup complete. hasWallet: $hasWallet');

      if (!mounted) return;

      // NOW connect the wallet (this triggers HomeScreen to switch to Dashboard)
      final provider = context.read<MultisigProvider>();
      await provider.connectWallet(normalizedKey);

      // Note: After connectWallet, HomeScreen's Consumer will switch to DashboardScreen
      // so we don't need Navigator.pushReplacement anymore
      
      if (!mounted) return;

      if (provider.error != null) {
        // If connection failed, we still have the saved key for retry
        setState(() {
          _error = provider.error;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Connect error: $e');
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ResponsiveContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Center(
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 48,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Import Wallet',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Enter your private key and create a password',
                      style: TextStyle(fontSize: 15, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Private Key
                  const Text(
                    'PRIVATE KEY',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _privateKeyController,
                    obscureText: _obscureKey,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '0x... or hex without prefix',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.black54,
                        ),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Password
                  const Text(
                    'PASSWORD',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Create password (min 6 chars)',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.black54,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  const Text(
                    'CONFIRM PASSWORD',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Confirm password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.black54,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // YubiKey Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Enable YubiKey',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          subtitle: const Text(
                            'Require hardware key for login',
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                          value: _enableYubiKey,
                          onChanged: (value) => setState(() {
                            _enableYubiKey = value;
                            if (!value) {
                              _yubiKeyController.clear();
                              _yubiKeyPublicId = null;
                            }
                          }),
                          activeTrackColor: Colors.black54,
                          inactiveTrackColor: Colors.grey.shade300,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        ),
                        if (_enableYubiKey) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'YUBIKEY OTP',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _yubiKeyController,
                                  onChanged: _onYubiKeyChanged,
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'Touch YubiKey to register',
                                    filled: true,
                                    fillColor: Colors.white,
                                    suffixIcon: _yubiKeyPublicId != null
                                        ? const Icon(Icons.check_circle, color: Colors.green)
                                        : const Icon(Icons.key, color: Colors.black38),
                                  ),
                                ),
                                if (_yubiKeyPublicId != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.verified_user, size: 14, color: Colors.green),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Key ID: $_yubiKeyPublicId',
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
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Validation checks
                  _buildChecks(),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_isValid) ? null : _connect,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Import & Encrypt'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 20, color: Colors.black54),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _enableYubiKey
                                ? 'Protected by AES-256 encryption + YubiKey 2FA.'
                                : 'Your key is encrypted with AES-256 and stored locally.',
                            style: const TextStyle(fontSize: 13, color: Colors.black54),
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

  Widget _buildChecks() {
    final key = _privateKeyController.text.trim();
    final normalizedKey = key.startsWith('0x') ? key.substring(2) : key;
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    final isValidHex = normalizedKey.isNotEmpty && RegExp(r'^[a-fA-F0-9]+$').hasMatch(normalizedKey);
    final isCorrectLength = normalizedKey.length == 64;
    final passwordsMatch = password == confirm && confirm.isNotEmpty;

    return Column(
      children: [
        _CheckRow(
          label: 'Valid hex key (${normalizedKey.length}/64 chars)',
          checked: isValidHex && isCorrectLength,
        ),
        _CheckRow(
          label: 'Password at least 6 characters (${password.length}/6)',
          checked: password.length >= 6,
        ),
        _CheckRow(
          label: 'Passwords match',
          checked: passwordsMatch,
        ),
        if (_enableYubiKey)
          _CheckRow(label: 'YubiKey registered', checked: _yubiKeyPublicId != null),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool checked;

  const _CheckRow({required this.label, required this.checked});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: checked ? Colors.black : Colors.black26,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: checked ? Colors.black : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
