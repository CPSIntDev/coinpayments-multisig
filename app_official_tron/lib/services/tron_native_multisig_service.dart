import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:blockchain_utils/blockchain_utils.dart' hide hex;
import 'package:web3dart/crypto.dart';
import 'package:convert/convert.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/digests/sha256.dart';
import '../models/tron_permission.dart';
import '../models/pending_transaction.dart';

/// Service for TRON's native account-based multisig functionality
/// This uses TRON's built-in account permissions system, not a custom smart contract
class TronNativeMultisigService {
  late String _rpcUrl;
  String? _multisigAddress; // The multisig account address
  Uint8List? _privateKeyBytes;
  String? _privateKeyHex;
  String? _userAddress;

  bool get isConnected => _privateKeyBytes != null;
  String? get userAddress => _userAddress;
  String? get multisigAddress => _multisigAddress;
  String? get privateKey => _privateKeyHex;

  Future<void> init({required String rpcUrl, String? multisigAddress}) async {
    _rpcUrl = rpcUrl.endsWith('/') ? rpcUrl.substring(0, rpcUrl.length - 1) : rpcUrl;
    _multisigAddress = multisigAddress;
    debugPrint('[TronNativeMultisig] Initialized with RPC: $_rpcUrl');
    if (multisigAddress != null) {
      debugPrint('[TronNativeMultisig] Multisig address: $multisigAddress');
    }
  }

  void setMultisigAddress(String address) {
    _multisigAddress = address;
    debugPrint('[TronNativeMultisig] Set multisig address: $address');
  }

  Future<void> connectWallet(String privateKey) async {
    final cleanKey = privateKey.startsWith('0x') 
        ? privateKey.substring(2) 
        : privateKey;
    _privateKeyHex = cleanKey;
    _privateKeyBytes = Uint8List.fromList(hex.decode(cleanKey));
    _userAddress = _privateKeyToTronAddress(_privateKeyBytes!);
    debugPrint('[TronNativeMultisig] Connected wallet: $_userAddress');
  }

  void disconnect() {
    _privateKeyBytes = null;
    _privateKeyHex = null;
    _userAddress = null;
  }

  /// Convert private key to TRON address
  String _privateKeyToTronAddress(Uint8List privateKey) {
    final ecDomainParams = ECCurve_secp256k1();
    final privateKeyNum = bytesToUnsignedInt(privateKey);
    final publicKeyPoint = ecDomainParams.G * privateKeyNum;
    final pubKeyBytes = publicKeyPoint!.getEncoded(false);
    final hash = keccak256(Uint8List.fromList(pubKeyBytes.sublist(1)));
    final addressBytes = Uint8List.fromList([0x41, ...hash.sublist(12)]);
    return Base58Encoder.checkEncode(addressBytes);
  }

  /// Convert TRON Base58 address to hex (with 41 prefix)
  /// Also handles addresses that are already in hex format
  String _tronAddressToHex(String tronAddress) {
    // If already hex (starts with 41 and is 42 chars), return as-is
    if (tronAddress.startsWith('41') && tronAddress.length == 42 && 
        RegExp(r'^[0-9a-fA-F]+$').hasMatch(tronAddress)) {
      return tronAddress.toLowerCase();
    }
    
    // If starts with T, it's Base58 - decode it
    if (tronAddress.startsWith('T')) {
      try {
        final bytes = Base58Decoder.checkDecode(tronAddress);
        return hex.encode(bytes);
      } catch (e) {
        debugPrint('[TronNativeMultisig] Base58 decode error for $tronAddress: $e');
        throw Exception('Invalid TRON address: $tronAddress');
      }
    }
    
    // Unknown format
    throw Exception('Invalid TRON address format: $tronAddress');
  }

  /// Convert hex address (with 41 prefix) to TRON Base58
  String _hexToTronAddress(String hexAddress) {
    final cleanHex = hexAddress.startsWith('0x') 
        ? hexAddress.substring(2) 
        : hexAddress;
    final bytes = Uint8List.fromList(hex.decode(cleanHex));
    return Base58Encoder.checkEncode(bytes);
  }

  /// Get account info including permissions
  Future<TronAccountInfo?> getAccountInfo(String address) async {
    final hexAddr = _tronAddressToHex(address);
    
    final response = await http.post(
      Uri.parse('$_rpcUrl/wallet/getaccount'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address': hexAddr, 'visible': false}),
    );

    final result = jsonDecode(response.body);
    if (result.isEmpty || result['address'] == null) {
      debugPrint('[TronNativeMultisig] Account not found or not activated');
      return null;
    }

    return TronAccountInfo.fromJson(result);
  }

  /// Get TRX balance of an account
  Future<BigInt> getTrxBalance(String address) async {
    final info = await getAccountInfo(address);
    return BigInt.from(info?.balance ?? 0);
  }

  /// Get TRC20 token balance
  Future<BigInt> getTrc20Balance(String accountAddress, String tokenAddress) async {
    final accountHex = _tronAddressToHex(accountAddress);
    final tokenHex = _tronAddressToHex(tokenAddress);
    
    // Encode balanceOf(address) call
    final functionSelector = 'balanceOf(address)';
    final parameter = accountHex.substring(2).padLeft(64, '0');
    
    final response = await http.post(
      Uri.parse('$_rpcUrl/wallet/triggerconstantcontract'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'owner_address': accountHex,
        'contract_address': tokenHex,
        'function_selector': functionSelector,
        'parameter': parameter,
      }),
    );

    final result = jsonDecode(response.body);
    if (result['constant_result'] != null && (result['constant_result'] as List).isNotEmpty) {
      final hexValue = result['constant_result'][0] as String;
      return BigInt.parse(hexValue, radix: 16);
    }
    return BigInt.zero;
  }

  /// Extend transaction expiration by specified seconds (default 5 minutes)
  /// This modifies the raw_data and recalculates the txID
  /// Note: Must be called BEFORE signing, as changing expiration invalidates signatures
  Map<String, dynamic> extendExpiration(Map<String, dynamic> transaction, {int extensionSeconds = 300}) {
    final tx = Map<String, dynamic>.from(transaction);
    final rawData = Map<String, dynamic>.from(tx['raw_data'] as Map<String, dynamic>);
    
    // Get current expiration and extend it
    final currentExpiration = rawData['expiration'] as int;
    final newExpiration = currentExpiration + (extensionSeconds * 1000); // Convert to ms
    rawData['expiration'] = newExpiration;
    
    // Re-encode raw_data to protobuf and calculate new txID
    final rawDataHex = _encodeRawDataToProtobuf(rawData);
    final newTxId = _calculateTxId(rawDataHex);
    
    tx['raw_data'] = rawData;
    tx['raw_data_hex'] = rawDataHex;
    tx['txID'] = newTxId;
    
    // Clear any existing signatures (they're invalid now)
    tx['signature'] = <String>[];
    
    debugPrint('[TronNativeMultisig] Extended expiration by ${extensionSeconds}s, new txID: $newTxId');
    return tx;
  }

  /// Encode raw_data map to protobuf hex string
  String _encodeRawDataToProtobuf(Map<String, dynamic> rawData) {
    final buffer = <int>[];
    
    // Field 1: ref_block_bytes (bytes)
    if (rawData['ref_block_bytes'] != null) {
      final bytes = hex.decode(rawData['ref_block_bytes'] as String);
      buffer.addAll(_encodeField(1, bytes, wireType: 2));
    }
    
    // Field 4: ref_block_hash (bytes)
    if (rawData['ref_block_hash'] != null) {
      final bytes = hex.decode(rawData['ref_block_hash'] as String);
      buffer.addAll(_encodeField(4, bytes, wireType: 2));
    }
    
    // Field 8: expiration (int64)
    if (rawData['expiration'] != null) {
      buffer.addAll(_encodeVarintField(8, rawData['expiration'] as int));
    }
    
    // Field 11: contract (repeated message)
    if (rawData['contract'] != null) {
      final contracts = rawData['contract'] as List<dynamic>;
      for (final contract in contracts) {
        final contractBytes = _encodeContract(contract as Map<String, dynamic>);
        buffer.addAll(_encodeField(11, contractBytes, wireType: 2));
      }
    }
    
    // Field 14: timestamp (int64)
    if (rawData['timestamp'] != null) {
      buffer.addAll(_encodeVarintField(14, rawData['timestamp'] as int));
    }
    
    // Field 18: fee_limit (int64)
    if (rawData['fee_limit'] != null) {
      buffer.addAll(_encodeVarintField(18, rawData['fee_limit'] as int));
    }
    
    return hex.encode(buffer);
  }

  /// Encode a contract message to protobuf bytes
  List<int> _encodeContract(Map<String, dynamic> contract) {
    final buffer = <int>[];
    
    // Field 1: type (enum as int32)
    if (contract['type'] != null) {
      final typeValue = _contractTypeToInt(contract['type'] as String);
      buffer.addAll(_encodeVarintField(1, typeValue));
    }
    
    // Field 2: parameter (Any message - contains type_url and value)
    if (contract['parameter'] != null) {
      final param = contract['parameter'] as Map<String, dynamic>;
      final paramBytes = _encodeParameter(param);
      buffer.addAll(_encodeField(2, paramBytes, wireType: 2));
    }
    
    return buffer;
  }

  /// Encode parameter (Any type) to protobuf bytes
  List<int> _encodeParameter(Map<String, dynamic> param) {
    final buffer = <int>[];
    
    // Field 1: type_url (string)
    if (param['type_url'] != null) {
      final typeUrl = utf8.encode(param['type_url'] as String);
      buffer.addAll(_encodeField(1, typeUrl, wireType: 2));
    }
    
    // Field 2: value (bytes) - the actual contract data
    if (param['value'] != null) {
      final valueData = param['value'] as Map<String, dynamic>;
      final valueBytes = _encodeContractValue(valueData, param['type_url'] as String?);
      buffer.addAll(_encodeField(2, valueBytes, wireType: 2));
    }
    
    return buffer;
  }

  /// Encode contract value based on type
  List<int> _encodeContractValue(Map<String, dynamic> value, String? typeUrl) {
    final buffer = <int>[];
    
    if (typeUrl?.contains('TransferContract') == true) {
      // TransferContract: owner_address, to_address, amount
      if (value['owner_address'] != null) {
        final addr = hex.decode(value['owner_address'] as String);
        buffer.addAll(_encodeField(1, addr, wireType: 2));
      }
      if (value['to_address'] != null) {
        final addr = hex.decode(value['to_address'] as String);
        buffer.addAll(_encodeField(2, addr, wireType: 2));
      }
      if (value['amount'] != null) {
        buffer.addAll(_encodeVarintField(3, value['amount'] as int));
      }
    } else if (typeUrl?.contains('TriggerSmartContract') == true) {
      // TriggerSmartContract: owner_address, contract_address, call_value, data, call_token_value, token_id
      if (value['owner_address'] != null) {
        final addr = hex.decode(value['owner_address'] as String);
        buffer.addAll(_encodeField(1, addr, wireType: 2));
      }
      if (value['contract_address'] != null) {
        final addr = hex.decode(value['contract_address'] as String);
        buffer.addAll(_encodeField(2, addr, wireType: 2));
      }
      if (value['call_value'] != null && (value['call_value'] as int) != 0) {
        buffer.addAll(_encodeVarintField(3, value['call_value'] as int));
      }
      if (value['data'] != null) {
        final data = hex.decode(value['data'] as String);
        buffer.addAll(_encodeField(4, data, wireType: 2));
      }
    } else if (typeUrl?.contains('AccountPermissionUpdateContract') == true) {
      // AccountPermissionUpdateContract: owner_address, owner, witness, actives
      if (value['owner_address'] != null) {
        final addr = hex.decode(value['owner_address'] as String);
        buffer.addAll(_encodeField(1, addr, wireType: 2));
      }
      if (value['owner'] != null) {
        final ownerBytes = _encodePermission(value['owner'] as Map<String, dynamic>);
        buffer.addAll(_encodeField(2, ownerBytes, wireType: 2));
      }
      if (value['actives'] != null) {
        final actives = value['actives'] as List<dynamic>;
        for (final active in actives) {
          final activeBytes = _encodePermission(active as Map<String, dynamic>);
          buffer.addAll(_encodeField(4, activeBytes, wireType: 2));
        }
      }
    }
    
    return buffer;
  }

  /// Encode a Permission message
  List<int> _encodePermission(Map<String, dynamic> permission) {
    final buffer = <int>[];
    
    // Field 1: type (PermissionType enum)
    if (permission['type'] != null) {
      final type = permission['type'];
      int typeValue = 0;
      if (type is String) {
        typeValue = type == 'Owner' ? 0 : (type == 'Witness' ? 1 : 2);
      } else if (type is int) {
        typeValue = type;
      }
      buffer.addAll(_encodeVarintField(1, typeValue));
    }
    
    // Field 2: id (int32)
    if (permission['id'] != null) {
      buffer.addAll(_encodeVarintField(2, permission['id'] as int));
    }
    
    // Field 3: permission_name (string)
    if (permission['permission_name'] != null) {
      final name = utf8.encode(permission['permission_name'] as String);
      buffer.addAll(_encodeField(3, name, wireType: 2));
    }
    
    // Field 4: threshold (int64)
    if (permission['threshold'] != null) {
      buffer.addAll(_encodeVarintField(4, permission['threshold'] as int));
    }
    
    // Field 5: operations (bytes)
    if (permission['operations'] != null) {
      final ops = hex.decode(permission['operations'] as String);
      buffer.addAll(_encodeField(7, ops, wireType: 2));
    }
    
    // Field 6: keys (repeated Key)
    if (permission['keys'] != null) {
      final keys = permission['keys'] as List<dynamic>;
      for (final key in keys) {
        final keyBytes = _encodeKey(key as Map<String, dynamic>);
        buffer.addAll(_encodeField(6, keyBytes, wireType: 2));
      }
    }
    
    return buffer;
  }

  /// Encode a Key message
  List<int> _encodeKey(Map<String, dynamic> key) {
    final buffer = <int>[];
    
    if (key['address'] != null) {
      String addr = key['address'] as String;
      // Convert base58 to hex if needed
      if (addr.startsWith('T')) {
        addr = _tronAddressToHex(addr);
      }
      final addrBytes = hex.decode(addr);
      buffer.addAll(_encodeField(1, addrBytes, wireType: 2));
    }
    
    if (key['weight'] != null) {
      buffer.addAll(_encodeVarintField(2, key['weight'] as int));
    }
    
    return buffer;
  }

  /// Encode a protobuf field with tag and wire type
  List<int> _encodeField(int fieldNumber, List<int> data, {required int wireType}) {
    final buffer = <int>[];
    final tag = (fieldNumber << 3) | wireType;
    buffer.addAll(_encodeVarint(tag));
    if (wireType == 2) {
      // Length-delimited
      buffer.addAll(_encodeVarint(data.length));
    }
    buffer.addAll(data);
    return buffer;
  }

  /// Encode a varint field
  List<int> _encodeVarintField(int fieldNumber, int value) {
    final buffer = <int>[];
    final tag = (fieldNumber << 3) | 0; // Wire type 0 for varint
    buffer.addAll(_encodeVarint(tag));
    buffer.addAll(_encodeVarint(value));
    return buffer;
  }

  /// Encode an integer as a varint
  List<int> _encodeVarint(int value) {
    final buffer = <int>[];
    var v = value;
    while (v > 127) {
      buffer.add((v & 0x7F) | 0x80);
      v >>= 7;
    }
    buffer.add(v & 0x7F);
    return buffer;
  }

  /// Convert contract type string to enum int
  int _contractTypeToInt(String type) {
    const types = {
      'AccountCreateContract': 0,
      'TransferContract': 1,
      'TransferAssetContract': 2,
      'VoteAssetContract': 3,
      'VoteWitnessContract': 4,
      'WitnessCreateContract': 5,
      'AssetIssueContract': 6,
      'WitnessUpdateContract': 8,
      'ParticipateAssetIssueContract': 9,
      'AccountUpdateContract': 10,
      'FreezeBalanceContract': 11,
      'UnfreezeBalanceContract': 12,
      'WithdrawBalanceContract': 13,
      'UnfreezeAssetContract': 14,
      'UpdateAssetContract': 15,
      'ProposalCreateContract': 16,
      'ProposalApproveContract': 17,
      'ProposalDeleteContract': 18,
      'SetAccountIdContract': 19,
      'CustomContract': 20,
      'CreateSmartContract': 30,
      'TriggerSmartContract': 31,
      'GetContract': 32,
      'UpdateSettingContract': 33,
      'ExchangeCreateContract': 41,
      'ExchangeInjectContract': 42,
      'ExchangeWithdrawContract': 43,
      'ExchangeTransactionContract': 44,
      'UpdateEnergyLimitContract': 45,
      'AccountPermissionUpdateContract': 46,
      'ClearABIContract': 48,
      'UpdateBrokerageContract': 49,
      'ShieldedTransferContract': 51,
    };
    return types[type] ?? 0;
  }

  /// Calculate txID from raw_data_hex (SHA256)
  String _calculateTxId(String rawDataHex) {
    final bytes = hex.decode(rawDataHex);
    // TRON uses SHA256 for txID
    return hex.encode(_sha256(bytes));
  }

  /// SHA256 hash
  List<int> _sha256(List<int> data) {
    final digest = SHA256Digest();
    return digest.process(Uint8List.fromList(data)).toList();
  }

  /// Create a TRX transfer transaction (unsigned)
  Future<Map<String, dynamic>> createTrxTransfer({
    required String from,
    required String to,
    required BigInt amount,
    int expirationSeconds = 300, // Default 5 minutes
  }) async {
    final fromHex = _tronAddressToHex(from);
    final toHex = _tronAddressToHex(to);

    final response = await http.post(
      Uri.parse('$_rpcUrl/wallet/createtransaction'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'owner_address': fromHex,
        'to_address': toHex,
        'amount': amount.toInt(),
        'visible': false,
      }),
    );

    final result = jsonDecode(response.body);
    if (result['Error'] != null) {
      throw Exception(result['Error']);
    }
    
    // Extend expiration to desired duration
    final extendedTx = extendExpiration(result, extensionSeconds: expirationSeconds);
    
    debugPrint('[TronNativeMultisig] Created TRX transfer with ${expirationSeconds}s expiration: ${extendedTx['txID']}');
    return extendedTx;
  }

  /// Create a TRC20 token transfer transaction (unsigned)
  Future<Map<String, dynamic>> createTrc20Transfer({
    required String from,
    required String tokenAddress,
    required String to,
    required BigInt amount,
    int feeLimit = 100000000, // 100 TRX default
    int expirationSeconds = 300, // Default 5 minutes
  }) async {
    final fromHex = _tronAddressToHex(from);
    final tokenHex = _tronAddressToHex(tokenAddress);
    
    // Encode transfer(address,uint256) call
    final functionSelector = 'transfer(address,uint256)';
    final toHex = _tronAddressToHex(to).substring(2).padLeft(64, '0');
    final amountHex = amount.toRadixString(16).padLeft(64, '0');
    final parameter = toHex + amountHex;

    final response = await http.post(
      Uri.parse('$_rpcUrl/wallet/triggersmartcontract'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'owner_address': fromHex,
        'contract_address': tokenHex,
        'function_selector': functionSelector,
        'parameter': parameter,
        'fee_limit': feeLimit,
        'call_value': 0,
        'visible': false,
      }),
    );

    final result = jsonDecode(response.body);
    if (result['result']?['result'] != true) {
      final message = result['result']?['message'] ?? 'Failed to create transaction';
      String decodedMessage = message;
      if (message is String && message.isNotEmpty) {
        try {
          decodedMessage = utf8.decode(hex.decode(message));
        } catch (_) {}
      }
      throw Exception('Create transaction failed: $decodedMessage');
    }

    // Extend expiration to desired duration
    final extendedTx = extendExpiration(result['transaction'], extensionSeconds: expirationSeconds);
    
    debugPrint('[TronNativeMultisig] Created TRC20 transfer with ${expirationSeconds}s expiration: ${extendedTx['txID']}');
    return extendedTx;
  }

  /// Sign a transaction with the connected wallet
  String signTransaction(Map<String, dynamic> transaction) {
    if (_privateKeyBytes == null) {
      throw Exception('Wallet not connected');
    }

    final txID = transaction['txID'] as String;
    final txIDBytes = Uint8List.fromList(hex.decode(txID));
    
    // Sign using secp256k1
    final signature = sign(txIDBytes, _privateKeyBytes!);
    
    // Convert to TRON format: r (32 bytes) + s (32 bytes) + v (1 byte)
    final r = signature.r.toRadixString(16).padLeft(64, '0');
    final s = signature.s.toRadixString(16).padLeft(64, '0');
    final v = ((signature.v - 27) & 0xff).toRadixString(16).padLeft(2, '0');
    
    return r + s + v;
  }

  /// Add a signature to a transaction
  Map<String, dynamic> addSignature(Map<String, dynamic> transaction, String signature) {
    final tx = Map<String, dynamic>.from(transaction);
    final signatures = List<String>.from(tx['signature'] ?? []);
    if (!signatures.contains(signature)) {
      signatures.add(signature);
    }
    tx['signature'] = signatures;
    return tx;
  }

  /// Sign and add signature to transaction
  Map<String, dynamic> signAndAddToTransaction(Map<String, dynamic> transaction) {
    final signature = signTransaction(transaction);
    return addSignature(transaction, signature);
  }

  /// Broadcast a signed transaction
  Future<String> broadcastTransaction(Map<String, dynamic> transaction) async {
    final response = await http.post(
      Uri.parse('$_rpcUrl/wallet/broadcasttransaction'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(transaction),
    );

    final result = jsonDecode(response.body);
    
    if (result['result'] != true) {
      final code = result['code'] ?? '';
      final message = result['message'] ?? 'Broadcast failed';
      String decodedMessage = message;
      if (message is String && message.isNotEmpty) {
        try {
          decodedMessage = utf8.decode(hex.decode(message));
        } catch (_) {}
      }
      throw Exception('Broadcast failed [$code]: $decodedMessage');
    }

    final txId = transaction['txID'] as String;
    debugPrint('[TronNativeMultisig] Transaction broadcast: $txId');
    return txId;
  }

  /// Get the number of signatures on a transaction
  int getSignatureCount(Map<String, dynamic> transaction) {
    final signatures = transaction['signature'] as List<dynamic>?;
    return signatures?.length ?? 0;
  }

  /// Check if user has already signed
  bool hasUserSigned(Map<String, dynamic> transaction) {
    if (_privateKeyBytes == null || _userAddress == null) return false;
    
    final signatures = transaction['signature'] as List<dynamic>?;
    if (signatures == null || signatures.isEmpty) return false;
    
    // Generate the signature this user would produce
    final userSignature = signTransaction(transaction);
    return signatures.contains(userSignature);
  }

  /// Get the signer addresses from signatures
  Future<List<String>> getSignerAddresses(Map<String, dynamic> transaction) async {
    final signatures = transaction['signature'] as List<dynamic>?;
    if (signatures == null || signatures.isEmpty) return [];

    final txID = transaction['txID'] as String;
    final txIDBytes = Uint8List.fromList(hex.decode(txID));
    final signers = <String>[];

    for (final sig in signatures) {
      try {
        final sigHex = sig as String;
        final r = BigInt.parse(sigHex.substring(0, 64), radix: 16);
        final s = BigInt.parse(sigHex.substring(64, 128), radix: 16);
        final v = int.parse(sigHex.substring(128, 130), radix: 16) + 27;
        
        final signature = MsgSignature(r, s, v);
        final publicKey = ecRecover(txIDBytes, signature);
        
        // Convert public key to address
        final pubKeyHash = keccak256(publicKey);
        final addressBytes = Uint8List.fromList([0x41, ...pubKeyHash.sublist(12)]);
        final address = Base58Encoder.checkEncode(addressBytes);
        signers.add(address);
      } catch (e) {
        debugPrint('[TronNativeMultisig] Error recovering signer: $e');
      }
    }

    return signers;
  }

  /// Calculate total weight of signatures for a permission
  int calculateSignatureWeight(
    Map<String, dynamic> transaction,
    TronPermission permission,
    List<String> signerAddresses,
  ) {
    int totalWeight = 0;
    
    for (final signer in signerAddresses) {
      for (final key in permission.keys) {
        if (key.address.toLowerCase() == signer.toLowerCase()) {
          totalWeight += key.weight;
          break;
        }
      }
    }
    
    return totalWeight;
  }

  /// Check if transaction has enough signatures to broadcast
  Future<bool> hasEnoughSignatures(
    Map<String, dynamic> transaction,
    TronPermission permission,
  ) async {
    final signers = await getSignerAddresses(transaction);
    final weight = calculateSignatureWeight(transaction, permission, signers);
    return weight >= permission.threshold;
  }

  /// Check if an address is an owner in the permission
  bool isOwnerInPermission(TronPermission permission, String address) {
    return permission.keys.any(
      (k) => k.address.toLowerCase() == address.toLowerCase()
    );
  }

  /// Get transaction info from network
  Future<Map<String, dynamic>?> getTransactionInfo(String txId) async {
    final response = await http.post(
      Uri.parse('$_rpcUrl/wallet/gettransactioninfobyid'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'value': txId}),
    );

    final result = jsonDecode(response.body);
    if (result.isEmpty) return null;
    return result;
  }

  /// Serialize transaction to JSON string for sharing
  String serializeTransaction(PendingTransaction pendingTx) {
    return jsonEncode(pendingTx.toJson());
  }

  /// Deserialize transaction from JSON string
  PendingTransaction deserializeTransaction(String jsonStr) {
    final json = jsonDecode(jsonStr);
    return PendingTransaction.fromJson(json);
  }

  // ============ Account Permission Management ============

  /// Update account permissions (add/remove signers, change threshold)
  /// This creates a transaction that needs to be signed by the OWNER permission holders
  Future<Map<String, dynamic>> createPermissionUpdateTransaction({
    required String accountAddress,
    required TronPermission ownerPermission,
    required List<TronPermission> activePermissions,
    TronPermission? witnessPermission,
  }) async {
    final accountHex = _tronAddressToHex(accountAddress);
    
    // Build owner permission
    final ownerPermissionJson = {
      'type': 0,
      'permission_name': ownerPermission.permissionName,
      'threshold': ownerPermission.threshold,
      'keys': ownerPermission.keys.map((k) => {
        'address': _tronAddressToHex(k.address),
        'weight': k.weight,
      }).toList(),
    };
    
    // Build active permissions
    final activePermissionsJson = activePermissions.map((p) => {
      'type': 2,
      'permission_name': p.permissionName,
      'threshold': p.threshold,
      'operations': p.operations ?? '7fff1fc0033e0000000000000000000000000000000000000000000000000000',
      'keys': p.keys.map((k) => {
        'address': _tronAddressToHex(k.address),
        'weight': k.weight,
      }).toList(),
    }).toList();
    
    final body = <String, dynamic>{
      'owner_address': accountHex,
      'owner': ownerPermissionJson,
      'actives': activePermissionsJson,
      'visible': false,
    };
    
    // Add witness permission if provided
    if (witnessPermission != null) {
      body['witness'] = {
        'type': 1,
        'permission_name': witnessPermission.permissionName,
        'threshold': witnessPermission.threshold,
        'keys': witnessPermission.keys.map((k) => {
          'address': _tronAddressToHex(k.address),
          'weight': k.weight,
        }).toList(),
      };
    }

    final response = await http.post(
      Uri.parse('$_rpcUrl/wallet/accountpermissionupdate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final result = jsonDecode(response.body);
    
    if (result['Error'] != null) {
      throw Exception(result['Error']);
    }
    
    if (result['txID'] == null) {
      throw Exception('Failed to create permission update transaction');
    }
    
    // Extend expiration to 5 minutes
    final extendedTx = extendExpiration(result, extensionSeconds: 300);
    
    debugPrint('[TronNativeMultisig] Created permission update tx with 5min expiration: ${extendedTx['txID']}');
    return extendedTx;
  }

  /// Create a simple multisig setup - adds signers to active permission
  Future<Map<String, dynamic>> createMultisigSetupTransaction({
    required String accountAddress,
    required List<SignerInfo> signers,
    required int threshold,
  }) async {
    // Get current account info
    final accountInfo = await getAccountInfo(accountAddress);
    if (accountInfo == null) {
      throw Exception('Account not found');
    }
    
    // Create owner permission (keep original owner or use first signer)
    final ownerKeys = signers.map((s) => TronPermissionKey(
      address: s.address,
      weight: s.weight,
    )).toList();
    
    final ownerPermission = TronPermission(
      type: 0,
      id: 0,
      permissionName: 'owner',
      threshold: threshold,
      keys: ownerKeys,
    );
    
    // Create active permission for transfers
    final activePermission = TronPermission(
      type: 2,
      id: 2,
      permissionName: 'active',
      threshold: threshold,
      keys: ownerKeys,
      operations: '7fff1fc0033e0000000000000000000000000000000000000000000000000000',
    );
    
    return createPermissionUpdateTransaction(
      accountAddress: accountAddress,
      ownerPermission: ownerPermission,
      activePermissions: [activePermission],
    );
  }

  /// Add a new signer to the account
  Future<Map<String, dynamic>> createAddSignerTransaction({
    required String accountAddress,
    required String newSignerAddress,
    required int weight,
    int? newThreshold,
  }) async {
    final accountInfo = await getAccountInfo(accountAddress);
    if (accountInfo == null) {
      throw Exception('Account not found');
    }
    
    // Get current permissions
    final currentOwner = accountInfo.ownerPermission;
    final currentActive = accountInfo.activePermissions.isNotEmpty 
        ? accountInfo.activePermissions.first 
        : null;
    
    if (currentOwner == null) {
      throw Exception('Account has no owner permission');
    }
    
    // Add new key to owner permission
    final newOwnerKeys = [
      ...currentOwner.keys,
      TronPermissionKey(address: newSignerAddress, weight: weight),
    ];
    
    final ownerPermission = TronPermission(
      type: 0,
      id: 0,
      permissionName: 'owner',
      threshold: newThreshold ?? currentOwner.threshold,
      keys: newOwnerKeys,
    );
    
    // Add new key to active permission
    final activeKeys = currentActive != null 
        ? [...currentActive.keys, TronPermissionKey(address: newSignerAddress, weight: weight)]
        : [TronPermissionKey(address: newSignerAddress, weight: weight)];
    
    final activePermission = TronPermission(
      type: 2,
      id: 2,
      permissionName: 'active',
      threshold: newThreshold ?? (currentActive?.threshold ?? 1),
      keys: activeKeys,
      operations: currentActive?.operations ?? '7fff1fc0033e0000000000000000000000000000000000000000000000000000',
    );
    
    return createPermissionUpdateTransaction(
      accountAddress: accountAddress,
      ownerPermission: ownerPermission,
      activePermissions: [activePermission],
    );
  }

  /// Remove a signer from the account
  Future<Map<String, dynamic>> createRemoveSignerTransaction({
    required String accountAddress,
    required String signerToRemove,
    int? newThreshold,
  }) async {
    final accountInfo = await getAccountInfo(accountAddress);
    if (accountInfo == null) {
      throw Exception('Account not found');
    }
    
    final currentOwner = accountInfo.ownerPermission;
    final currentActive = accountInfo.activePermissions.isNotEmpty 
        ? accountInfo.activePermissions.first 
        : null;
    
    if (currentOwner == null) {
      throw Exception('Account has no owner permission');
    }
    
    // Remove key from owner permission
    final newOwnerKeys = currentOwner.keys
        .where((k) => k.address.toLowerCase() != signerToRemove.toLowerCase())
        .toList();
    
    if (newOwnerKeys.isEmpty) {
      throw Exception('Cannot remove last signer');
    }
    
    final ownerPermission = TronPermission(
      type: 0,
      id: 0,
      permissionName: 'owner',
      threshold: newThreshold ?? currentOwner.threshold,
      keys: newOwnerKeys,
    );
    
    // Remove key from active permission
    final activeKeys = currentActive?.keys
        .where((k) => k.address.toLowerCase() != signerToRemove.toLowerCase())
        .toList() ?? [];
    
    final activePermission = TronPermission(
      type: 2,
      id: 2,
      permissionName: 'active',
      threshold: newThreshold ?? (currentActive?.threshold ?? 1),
      keys: activeKeys.isNotEmpty ? activeKeys : newOwnerKeys,
      operations: currentActive?.operations ?? '7fff1fc0033e0000000000000000000000000000000000000000000000000000',
    );
    
    return createPermissionUpdateTransaction(
      accountAddress: accountAddress,
      ownerPermission: ownerPermission,
      activePermissions: [activePermission],
    );
  }

  /// Update threshold for the account
  Future<Map<String, dynamic>> createUpdateThresholdTransaction({
    required String accountAddress,
    required int newThreshold,
  }) async {
    final accountInfo = await getAccountInfo(accountAddress);
    if (accountInfo == null) {
      throw Exception('Account not found');
    }
    
    final currentOwner = accountInfo.ownerPermission;
    final currentActive = accountInfo.activePermissions.isNotEmpty 
        ? accountInfo.activePermissions.first 
        : null;
    
    if (currentOwner == null) {
      throw Exception('Account has no owner permission');
    }
    
    // Check if threshold is valid
    final totalWeight = currentOwner.keys.fold<int>(0, (sum, k) => sum + k.weight);
    if (newThreshold > totalWeight) {
      throw Exception('Threshold cannot exceed total weight ($totalWeight)');
    }
    
    final ownerPermission = TronPermission(
      type: 0,
      id: 0,
      permissionName: 'owner',
      threshold: newThreshold,
      keys: currentOwner.keys,
    );
    
    final activePermission = TronPermission(
      type: 2,
      id: 2,
      permissionName: 'active',
      threshold: newThreshold,
      keys: currentActive?.keys ?? currentOwner.keys,
      operations: currentActive?.operations ?? '7fff1fc0033e0000000000000000000000000000000000000000000000000000',
    );
    
    return createPermissionUpdateTransaction(
      accountAddress: accountAddress,
      ownerPermission: ownerPermission,
      activePermissions: [activePermission],
    );
  }

  void dispose() {
    // No resources to dispose
  }
}

/// Helper class for signer info
class SignerInfo {
  final String address;
  final int weight;
  
  SignerInfo({required this.address, required this.weight});
}
