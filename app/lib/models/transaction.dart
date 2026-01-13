import 'package:intl/intl.dart';

class MultisigTransaction {
  final int id;
  final String to;
  final BigInt amount;
  final bool executed;
  final int approvalCount;
  final BigInt createdAt;
  final int expirationPeriod;

  MultisigTransaction({
    required this.id,
    required this.to,
    required this.amount,
    required this.executed,
    required this.approvalCount,
    required this.createdAt,
    required this.expirationPeriod,
  });

  String get formattedAmount {
    // USDT has 6 decimals
    final value = amount.toDouble() / 1000000;
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return formatter.format(value);
  }

  String get shortAddress {
    if (to.length < 12) return to;
    return '${to.substring(0, 6)}...${to.substring(to.length - 4)}';
  }

  String get status {
    if (executed) return 'Executed';
    if (isExpired) return 'Expired';
    return 'Pending';
  }

  /// Check if the transaction is expired (older than 1 day and not executed)
  bool get isExpired {
    if (executed) return false;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSeconds > createdAt.toInt() + expirationPeriod;
  }

  /// Get the expiration timestamp
  DateTime get expiresAt {
    return DateTime.fromMillisecondsSinceEpoch(
      (createdAt.toInt() + expirationPeriod) * 1000,
    );
  }

  /// Get time remaining until expiration (null if expired)
  Duration? get timeRemaining {
    if (executed || isExpired) return null;
    final expirationTime = createdAt.toInt() + expirationPeriod;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = expirationTime - nowSeconds;
    if (remaining <= 0) return null;
    return Duration(seconds: remaining);
  }

  /// Format time remaining as a human-readable string
  String? get formattedTimeRemaining {
    final remaining = timeRemaining;
    if (remaining == null) return null;
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m remaining';
    } else if (minutes > 0) {
      return '${minutes}m remaining';
    } else {
      return 'Expiring soon';
    }
  }
}
