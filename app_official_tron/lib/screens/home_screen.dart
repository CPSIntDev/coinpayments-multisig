import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/multisig_provider.dart';
import '../services/crypto_service.dart';
import 'connect_wallet_screen.dart';
import 'dashboard_screen.dart';
import 'unlock_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isChecking = true;
  bool _hasWallet = false;

  @override
  void initState() {
    super.initState();
    _checkWallet();
  }

  Future<void> _checkWallet() async {
    final hasWallet = await CryptoService.hasWallet();
    if (mounted) {
      setState(() {
        _hasWallet = hasWallet;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MultisigProvider>(
      builder: (context, provider, _) {
        // Already connected - show dashboard
        if (provider.isConnected) {
          return const DashboardScreen();
        }

        // Still checking for saved wallet
        if (_isChecking) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            ),
          );
        }

        // Has saved wallet - show unlock screen
        if (_hasWallet) {
          return const UnlockScreen();
        }

        // No wallet - show connect screen
        return const ConnectWalletScreen();
      },
    );
  }
}
