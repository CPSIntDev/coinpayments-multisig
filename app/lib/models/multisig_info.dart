import 'package:intl/intl.dart';

class MultisigInfo {
  final List<String> owners;
  final int threshold;
  final BigInt balance;
  final BigInt nativeBalance; // TRX (SUN) or ETH (Wei)
  final String usdtAddress;
  final bool isTron; // true for TVM, false for EVM
  final int expirationPeriod; // Transaction expiration period in seconds

  MultisigInfo({
    required this.owners,
    required this.threshold,
    required this.balance,
    required this.nativeBalance,
    required this.usdtAddress,
    required this.isTron,
    required this.expirationPeriod,
  });

  String get formattedBalance {
    // USDT has 6 decimals
    final value = balance.toDouble() / 1000000;
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return formatter.format(value);
  }

  String get formattedNativeBalance {
    if (isTron) {
      // TRX: 1 TRX = 1,000,000 SUN
      final value = nativeBalance.toDouble() / 1000000;
      final formatter = NumberFormat('#,##0.######', 'en_US');
      return '${formatter.format(value)} TRX';
    } else {
      // ETH: 1 ETH = 10^18 Wei
      final value = nativeBalance.toDouble() / 1e18;
      final formatter = NumberFormat('#,##0.######', 'en_US');
      return '${formatter.format(value)} ETH';
    }
  }

  String get nativeSymbol => isTron ? 'TRX' : 'ETH';
}
