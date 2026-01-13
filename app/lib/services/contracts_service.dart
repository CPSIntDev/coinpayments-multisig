import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

/// Network type for the contract
enum NetworkType {
  evm,  // Ethereum Virtual Machine (Ethereum, Polygon, BSC, etc.)
  tvm,  // TRON Virtual Machine
}

extension NetworkTypeExtension on NetworkType {
  String get displayName {
    switch (this) {
      case NetworkType.evm:
        return 'EVM';
      case NetworkType.tvm:
        return 'TVM (TRON)';
    }
  }

  String get description {
    switch (this) {
      case NetworkType.evm:
        return 'Ethereum, Polygon, BSC, Avalanche, etc.';
      case NetworkType.tvm:
        return 'TRON Network';
    }
  }

  static NetworkType fromString(String? value) {
    switch (value) {
      case 'tvm':
        return NetworkType.tvm;
      case 'evm':
      default:
        return NetworkType.evm;
    }
  }
}

/// Represents a saved contract configuration
class ContractConfig {
  final String id;
  final String name;
  final NetworkType networkType;
  final String rpcUrl;
  final String contractAddress;

  ContractConfig({
    required this.id,
    required this.name,
    required this.networkType,
    required this.rpcUrl,
    required this.contractAddress,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'networkType': networkType.name,
        'rpcUrl': rpcUrl,
        'contractAddress': contractAddress,
      };

  factory ContractConfig.fromJson(Map<String, dynamic> json) => ContractConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        networkType: NetworkTypeExtension.fromString(json['networkType'] as String?),
        rpcUrl: json['rpcUrl'] as String,
        contractAddress: json['contractAddress'] as String,
      );

  String get shortAddress {
    if (contractAddress.length < 12) return contractAddress;
    return '${contractAddress.substring(0, 6)}...${contractAddress.substring(contractAddress.length - 4)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContractConfig &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Service for managing multiple contract configurations
class ContractsService {
  static const String _contractsKey = 'contracts';
  static const String _activeContractKey = 'active_contract_id';

  /// Get all saved contracts
  static Future<List<ContractConfig>> getContracts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(StorageService.key(_contractsKey));
    if (data == null || data.isEmpty) return [];

    try {
      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((e) => ContractConfig.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save all contracts
  static Future<void> _saveContracts(List<ContractConfig> contracts) async {
    final prefs = await SharedPreferences.getInstance();
    final data = json.encode(contracts.map((e) => e.toJson()).toList());
    await prefs.setString(StorageService.key(_contractsKey), data);
  }

  /// Add a new contract
  static Future<ContractConfig> addContract({
    required String name,
    required NetworkType networkType,
    required String rpcUrl,
    required String contractAddress,
  }) async {
    final contracts = await getContracts();
    
    // Generate unique ID
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final config = ContractConfig(
      id: id,
      name: name,
      networkType: networkType,
      rpcUrl: rpcUrl,
      contractAddress: contractAddress,
    );
    
    contracts.add(config);
    await _saveContracts(contracts);
    
    // If this is the first contract, set it as active
    if (contracts.length == 1) {
      await setActiveContract(id);
    }
    
    return config;
  }

  /// Update an existing contract
  static Future<void> updateContract(ContractConfig config) async {
    final contracts = await getContracts();
    final index = contracts.indexWhere((c) => c.id == config.id);
    if (index >= 0) {
      contracts[index] = config;
      await _saveContracts(contracts);
    }
  }

  /// Remove a contract
  static Future<void> removeContract(String id) async {
    final contracts = await getContracts();
    contracts.removeWhere((c) => c.id == id);
    await _saveContracts(contracts);
    
    // If we removed the active contract, set another one as active
    final activeId = await getActiveContractId();
    if (activeId == id && contracts.isNotEmpty) {
      await setActiveContract(contracts.first.id);
    } else if (contracts.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageService.key(_activeContractKey));
    }
  }

  /// Get active contract ID
  static Future<String?> getActiveContractId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageService.key(_activeContractKey));
  }

  /// Set active contract
  static Future<void> setActiveContract(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageService.key(_activeContractKey), id);
  }

  /// Get active contract config
  static Future<ContractConfig?> getActiveContract() async {
    final contracts = await getContracts();
    final activeId = await getActiveContractId();
    
    if (activeId == null) {
      return contracts.isNotEmpty ? contracts.first : null;
    }
    
    try {
      return contracts.firstWhere((c) => c.id == activeId);
    } catch (e) {
      return contracts.isNotEmpty ? contracts.first : null;
    }
  }

  /// Migrate from old single contract format
  static Future<void> migrateFromOldFormat() async {
    final prefs = await SharedPreferences.getInstance();
    final oldRpc = prefs.getString(StorageService.key('rpc_url'));
    final oldContract = prefs.getString(StorageService.key('contract_address'));
    
    if (oldRpc != null && oldContract != null && oldRpc.isNotEmpty && oldContract.isNotEmpty) {
      final contracts = await getContracts();
      if (contracts.isEmpty) {
        // Migrate old config to new format (assume EVM for existing configs)
        await addContract(
          name: 'Default',
          networkType: NetworkType.evm,
          rpcUrl: oldRpc,
          contractAddress: oldContract,
        );
      }
    }
  }
}
