import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/crypto_service.dart';
import '../services/yubikey_service.dart';
import '../providers/multisig_provider.dart';
import '../main.dart';
import 'dashboard_screen.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _passwordController = TextEditingController();
  final _yubiKeyController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _yubiKeyRequired = false;
  bool _yubiKeyValid = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkYubiKeyRequired();
  }

  Future<void> _checkYubiKeyRequired() async {
    final enabled = await YubiKeyService.isEnabled();
    if (mounted) {
      setState(() => _yubiKeyRequired = enabled);
    }
    
    // Debug: Check wallet status
    final hasWallet = await CryptoService.hasWallet();
    debugPrint('[UnlockScreen] hasWallet: $hasWallet, yubiKeyRequired: $enabled');
  }

  void _onYubiKeyChanged(String value) {
    setState(() {
      _yubiKeyValid = YubiKeyService.isValidOtp(value);
    });
  }

  Future<void> _unlock() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }

    if (_yubiKeyRequired && !_yubiKeyValid) {
      setState(() => _error = 'Please touch your YubiKey');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Verify YubiKey first if required
      if (_yubiKeyRequired) {
        final yubiValid = await YubiKeyService.verifyOtp(_yubiKeyController.text);
        if (!yubiValid) {
          if (mounted) {
            setState(() {
              _error = 'YubiKey verification failed. Wrong hardware key.';
              _isLoading = false;
            });
          }
          return;
        }
        debugPrint('YubiKey verified successfully');
      }

      // Then decrypt the wallet
      debugPrint('Attempting unlock with password length: ${_passwordController.text.length}');
      
      String? privateKey;
      String? decryptError;
      try {
        privateKey = await CryptoService.decryptKey(_passwordController.text);
      } catch (e) {
        decryptError = e.toString();
        debugPrint('Decryption exception: $e');
      }

      if (privateKey == null) {
        debugPrint('Decryption returned null. Error: $decryptError');
        if (mounted) {
          setState(() {
            _error = decryptError != null 
                ? 'Decryption error: $decryptError'
                : 'Incorrect password';
            _isLoading = false;
          });
        }
        return;
      }

      debugPrint('Got private key, length: ${privateKey.length}');

      if (!mounted) return;

      final provider = context.read<MultisigProvider>();
      await provider.connectWallet(privateKey);

      debugPrint('Connected wallet, isOwner: ${provider.isOwner}');

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      debugPrint('Unlock error: $e');
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetWallet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reset Wallet'),
        content: const Text('This will delete your saved wallet and YubiKey configuration. Make sure you have backed up your private key.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await CryptoService.deleteWallet();
      await YubiKeyService.remove();
      if (!mounted) return;
      
      final provider = context.read<MultisigProvider>();
      provider.disconnect();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const InitScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _yubiKeyController.dispose();
    super.dispose();
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
                  const SizedBox(height: 60),
                  Center(
                    child: Icon(
                      _yubiKeyRequired ? Icons.security : Icons.lock_outline,
                      size: 56,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _yubiKeyRequired 
                          ? 'Enter password and touch YubiKey'
                          : 'Enter your password to unlock',
                      style: const TextStyle(fontSize: 15, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Password Field
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
                    autofocus: true,
                    onSubmitted: _yubiKeyRequired ? null : (_) => _unlock(),
                    decoration: InputDecoration(
                      hintText: 'Enter password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.black54,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),

                  // YubiKey Field (if required)
                  if (_yubiKeyRequired) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'YUBIKEY',
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
                      onSubmitted: (_) => _unlock(),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Touch YubiKey to authenticate',
                        suffixIcon: _yubiKeyValid
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.key, color: Colors.black38),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.black54),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Insert YubiKey and touch the sensor',
                              style: TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

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
                          Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _unlock,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Unlock'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: _resetWallet,
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(color: Colors.black54),
                      ),
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
