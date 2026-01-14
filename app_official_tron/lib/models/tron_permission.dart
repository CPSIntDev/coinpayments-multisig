import 'dart:typed_data';
import 'package:blockchain_utils/blockchain_utils.dart' hide hex;
import 'package:convert/convert.dart';

/// Represents a key (signer) in a TRON permission
class TronPermissionKey {
  final String address;
  final int weight;

  TronPermissionKey({
    required this.address,
    required this.weight,
  });

  factory TronPermissionKey.fromJson(Map<String, dynamic> json) {
    // Address can be in hex format from API
    String address = json['address'] as String;
    if (address.startsWith('41') && address.length == 42 &&
        RegExp(r'^[0-9a-fA-F]+$').hasMatch(address)) {
      // Convert hex to base58 using proper library
      address = _hexToBase58(address);
    }
    
    return TronPermissionKey(
      address: address,
      weight: _parseIntOrString(json['weight'], defaultValue: 1),
    );
  }

  /// Parse a value that can be either int or String
  static int _parseIntOrString(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  Map<String, dynamic> toJson() => {
    'address': address,
    'weight': weight,
  };

  /// Convert hex address to Base58Check encoded TRON address
  /// Uses the proper Base58Encoder from blockchain_utils library
  static String _hexToBase58(String hexAddress) {
    try {
      final bytes = Uint8List.fromList(hex.decode(hexAddress));
      return Base58Encoder.checkEncode(bytes);
    } catch (e) {
      // If conversion fails, return the original
      return hexAddress;
    }
  }

  String get shortAddress {
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}

/// Represents a TRON account permission
/// TRON has 3 types: owner (0), witness (1), active (2+)
class TronPermission {
  final int type; // 0=owner, 1=witness, 2+=active
  final int id;
  final String permissionName;
  final int threshold;
  final List<TronPermissionKey> keys;
  final String? operations; // Hex string of allowed operations for active permissions

  TronPermission({
    required this.type,
    required this.id,
    required this.permissionName,
    required this.threshold,
    required this.keys,
    this.operations,
  });

  factory TronPermission.fromJson(Map<String, dynamic> json) {
    final keys = (json['keys'] as List<dynamic>?)
        ?.map((k) => TronPermissionKey.fromJson(k as Map<String, dynamic>))
        .toList() ?? [];
    
    return TronPermission(
      type: _parseIntOrString(json['type']),
      id: _parseIntOrString(json['id']),
      permissionName: json['permission_name'] as String? ?? 'Unknown',
      threshold: _parseIntOrString(json['threshold'], defaultValue: 1),
      keys: keys,
      operations: json['operations'] as String?,
    );
  }

  /// Parse a value that can be either int or String
  static int _parseIntOrString(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'permission_name': permissionName,
    'threshold': threshold,
    'keys': keys.map((k) => k.toJson()).toList(),
    if (operations != null) 'operations': operations,
  };

  bool get isOwnerPermission => type == 0;
  bool get isWitnessPermission => type == 1;
  bool get isActivePermission => type == 2;

  int get totalWeight => keys.fold(0, (sum, k) => sum + k.weight);
}

/// Full TRON account information including permissions
class TronAccountInfo {
  final String address;
  final int balance; // In SUN (1 TRX = 1,000,000 SUN)
  final TronPermission? ownerPermission;
  final TronPermission? witnessPermission;
  final List<TronPermission> activePermissions;
  final int createTime;
  final int? latestOperationTime;

  TronAccountInfo({
    required this.address,
    required this.balance,
    this.ownerPermission,
    this.witnessPermission,
    required this.activePermissions,
    required this.createTime,
    this.latestOperationTime,
  });

  factory TronAccountInfo.fromJson(Map<String, dynamic> json) {
    // Parse address from hex
    String address = json['address'] as String? ?? '';
    if (address.startsWith('41') && address.length == 42) {
      address = TronPermissionKey._hexToBase58(address);
    }

    TronPermission? ownerPermission;
    if (json['owner_permission'] != null) {
      ownerPermission = TronPermission.fromJson(
        json['owner_permission'] as Map<String, dynamic>
      );
    }

    TronPermission? witnessPermission;
    if (json['witness_permission'] != null) {
      witnessPermission = TronPermission.fromJson(
        json['witness_permission'] as Map<String, dynamic>
      );
    }

    final activePermissions = <TronPermission>[];
    if (json['active_permission'] != null) {
      for (final p in json['active_permission'] as List<dynamic>) {
        activePermissions.add(TronPermission.fromJson(p as Map<String, dynamic>));
      }
    }

    return TronAccountInfo(
      address: address,
      balance: _parseIntOrString(json['balance']),
      ownerPermission: ownerPermission,
      witnessPermission: witnessPermission,
      activePermissions: activePermissions,
      createTime: _parseIntOrString(json['create_time']),
      latestOperationTime: json['latest_opration_time'] != null 
          ? _parseIntOrString(json['latest_opration_time']) 
          : null,
    );
  }

  /// Parse a value that can be either int or String
  static int _parseIntOrString(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Get the active permission for transfers (usually id=2)
  TronPermission? get transferPermission {
    // First active permission is typically for transfers
    return activePermissions.isNotEmpty ? activePermissions.first : ownerPermission;
  }

  /// Check if this is a multisig account
  bool get isMultisig {
    if (ownerPermission != null && ownerPermission!.keys.length > 1) {
      return true;
    }
    for (final perm in activePermissions) {
      if (perm.keys.length > 1 || perm.threshold > 1) {
        return true;
      }
    }
    return false;
  }

  /// Get all unique owner addresses
  List<String> get allOwners {
    final owners = <String>{};
    if (ownerPermission != null) {
      for (final key in ownerPermission!.keys) {
        owners.add(key.address);
      }
    }
    for (final perm in activePermissions) {
      for (final key in perm.keys) {
        owners.add(key.address);
      }
    }
    return owners.toList();
  }

  /// Get threshold for active permission
  int get activeThreshold {
    return transferPermission?.threshold ?? 1;
  }

  String get formattedBalance {
    final trx = balance / 1000000;
    return '${trx.toStringAsFixed(6)} TRX';
  }
}
