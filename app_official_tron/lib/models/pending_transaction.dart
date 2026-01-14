import 'package:intl/intl.dart';

/// Status of a pending transaction
enum PendingTxStatus {
  pending,    // Waiting for signatures
  ready,      // Has enough signatures to broadcast
  broadcast,  // Has been broadcast to network
  confirmed,  // Confirmed on chain
  expired,    // Transaction expired
  failed,     // Failed to broadcast
}

/// Represents a transaction pending signatures in native TRON multisig
class PendingTransaction {
  final String id; // Local unique ID
  final String txId; // TRON transaction ID (hash)
  final Map<String, dynamic> rawTransaction; // The unsigned/partially signed transaction
  final String fromAddress; // Multisig account address
  final String toAddress; // Recipient address
  final BigInt amount; // Amount in smallest unit
  final String assetType; // 'TRX' or token address
  final int threshold; // Required signatures
  final List<String> signers; // Addresses that have signed
  final DateTime createdAt;
  final DateTime expiresAt; // TRON transactions expire after ~1 hour
  final PendingTxStatus status;
  final String? broadcastTxId; // Set after successful broadcast
  final String? errorMessage;
  final String? description; // Optional description

  PendingTransaction({
    required this.id,
    required this.txId,
    required this.rawTransaction,
    required this.fromAddress,
    required this.toAddress,
    required this.amount,
    required this.assetType,
    required this.threshold,
    required this.signers,
    required this.createdAt,
    required this.expiresAt,
    this.status = PendingTxStatus.pending,
    this.broadcastTxId,
    this.errorMessage,
    this.description,
  });

  factory PendingTransaction.fromJson(Map<String, dynamic> json) {
    return PendingTransaction(
      id: json['id'] as String,
      txId: json['txId'] as String,
      rawTransaction: Map<String, dynamic>.from(json['rawTransaction'] as Map),
      fromAddress: json['fromAddress'] as String,
      toAddress: json['toAddress'] as String,
      amount: BigInt.parse(json['amount'] as String),
      assetType: json['assetType'] as String,
      threshold: json['threshold'] as int,
      signers: List<String>.from(json['signers'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      status: PendingTxStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PendingTxStatus.pending,
      ),
      broadcastTxId: json['broadcastTxId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'txId': txId,
    'rawTransaction': rawTransaction,
    'fromAddress': fromAddress,
    'toAddress': toAddress,
    'amount': amount.toString(),
    'assetType': assetType,
    'threshold': threshold,
    'signers': signers,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'status': status.name,
    'broadcastTxId': broadcastTxId,
    'errorMessage': errorMessage,
    'description': description,
  };

  PendingTransaction copyWith({
    String? id,
    String? txId,
    Map<String, dynamic>? rawTransaction,
    String? fromAddress,
    String? toAddress,
    BigInt? amount,
    String? assetType,
    int? threshold,
    List<String>? signers,
    DateTime? createdAt,
    DateTime? expiresAt,
    PendingTxStatus? status,
    String? broadcastTxId,
    String? errorMessage,
    String? description,
  }) {
    return PendingTransaction(
      id: id ?? this.id,
      txId: txId ?? this.txId,
      rawTransaction: rawTransaction ?? this.rawTransaction,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      amount: amount ?? this.amount,
      assetType: assetType ?? this.assetType,
      threshold: threshold ?? this.threshold,
      signers: signers ?? this.signers,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      broadcastTxId: broadcastTxId ?? this.broadcastTxId,
      errorMessage: errorMessage ?? this.errorMessage,
      description: description ?? this.description,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  bool get canBroadcast => 
      signers.length >= threshold && 
      !isExpired && 
      (status == PendingTxStatus.pending || status == PendingTxStatus.ready);

  bool get isPending => status == PendingTxStatus.pending && !isExpired;
  
  int get signatureCount => signers.length;
  
  int get remainingSignatures => threshold - signers.length;

  String get formattedAmount {
    if (assetType == 'PERMISSION_UPDATE') {
      return 'Permission Update';
    } else if (assetType == 'TRX') {
      final value = amount.toDouble() / 1000000;
      final formatter = NumberFormat('#,##0.######', 'en_US');
      return '${formatter.format(value)} TRX';
    } else {
      // Assume TRC20 with 6 decimals (like USDT)
      final value = amount.toDouble() / 1000000;
      final formatter = NumberFormat('#,##0.00', 'en_US');
      return '${formatter.format(value)} USDT';
    }
  }

  bool get isPermissionUpdate => assetType == 'PERMISSION_UPDATE';

  String get shortToAddress {
    if (toAddress.length < 12) return toAddress;
    return '${toAddress.substring(0, 6)}...${toAddress.substring(toAddress.length - 4)}';
  }

  String get statusText {
    if (isExpired && status == PendingTxStatus.pending) return 'Expired';
    switch (status) {
      case PendingTxStatus.pending:
        return 'Pending ($signatureCount/$threshold)';
      case PendingTxStatus.ready:
        return 'Ready to broadcast';
      case PendingTxStatus.broadcast:
        return 'Broadcast';
      case PendingTxStatus.confirmed:
        return 'Confirmed';
      case PendingTxStatus.expired:
        return 'Expired';
      case PendingTxStatus.failed:
        return 'Failed';
    }
  }

  Duration? get timeRemaining {
    if (isExpired) return null;
    return expiresAt.difference(DateTime.now());
  }

  String? get formattedTimeRemaining {
    final remaining = timeRemaining;
    if (remaining == null) return null;
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m remaining';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s remaining';
    } else if (seconds > 0) {
      return '${seconds}s remaining';
    } else {
      return 'Expiring now';
    }
  }
}
