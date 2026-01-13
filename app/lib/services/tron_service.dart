import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:blockchain_utils/blockchain_utils.dart' hide hex;
import 'package:web3dart/crypto.dart';
import 'package:convert/convert.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'blockchain_service.dart';

class TronService implements BlockchainService {
  late String _rpcUrl;
  late String _contractAddress;
  Uint8List? _privateKeyBytes;
  String? _privateKeyHex;
  String? _userAddress;

  @override
  bool get isConnected => _privateKeyBytes != null;

  @override
  String? get userAddress => _userAddress;

  @override
  String get contractAddress => _contractAddress;

  @override
  String? get privateKey => _privateKeyHex;

  @override
  Future<void> init({
    required String rpcUrl,
    required String contractAddress,
  }) async {
    _rpcUrl = rpcUrl.endsWith('/') ? rpcUrl.substring(0, rpcUrl.length - 1) : rpcUrl;
    _contractAddress = contractAddress;
    debugPrint('[TronService] Initialized with RPC: $_rpcUrl, Contract: $_contractAddress');
  }

  @override
  Future<void> connectWallet(String privateKey) async {
    // Remove 0x prefix if present
    final cleanKey = privateKey.startsWith('0x') 
        ? privateKey.substring(2) 
        : privateKey;
    _privateKeyHex = cleanKey;
    _privateKeyBytes = Uint8List.fromList(hex.decode(cleanKey));
    _userAddress = _privateKeyToTronAddress(_privateKeyBytes!);
    debugPrint('[TronService] Connected wallet: $_userAddress');
  }

  @override
  void disconnect() {
    _privateKeyBytes = null;
    _privateKeyHex = null;
    _userAddress = null;
  }

  /// Convert private key to TRON address
  String _privateKeyToTronAddress(Uint8List privateKey) {
    // Get public key from private key using secp256k1
    final ecDomainParams = ECCurve_secp256k1();
    final privateKeyNum = bytesToUnsignedInt(privateKey);
    final publicKeyPoint = ecDomainParams.G * privateKeyNum;
    
    // Get uncompressed public key (65 bytes: 04 + x + y)
    final pubKeyBytes = publicKeyPoint!.getEncoded(false);
    
    // Keccak256 hash of public key (skip first byte 0x04)
    final hash = keccak256(Uint8List.fromList(pubKeyBytes.sublist(1)));
    
    // Take last 20 bytes and add 0x41 prefix (TRON mainnet)
    final addressBytes = Uint8List.fromList([0x41, ...hash.sublist(12)]);
    
    // Base58Check encode
    return Base58Encoder.checkEncode(addressBytes);
  }

  /// Convert TRON Base58 address to hex (with 41 prefix)
  String _tronAddressToHex(String tronAddress) {
    final bytes = Base58Decoder.checkDecode(tronAddress);
    return hex.encode(bytes);
  }

  /// Convert hex address (with 41 prefix) to TRON Base58
  String _hexToTronAddress(String hexAddress) {
    final cleanHex = hexAddress.startsWith('0x') 
        ? hexAddress.substring(2) 
        : hexAddress;
    final bytes = Uint8List.fromList(hex.decode(cleanHex));
    return Base58Encoder.checkEncode(bytes);
  }

  /// ABI encode an address parameter (pad to 32 bytes)
  String _encodeAddress(String tronAddress) {
    final hexAddr = _tronAddressToHex(tronAddress);
    // Remove 41 prefix and pad to 64 chars (32 bytes)
    return hexAddr.substring(2).padLeft(64, '0');
  }

  /// ABI encode a uint256 parameter
  String _encodeUint256(BigInt value) {
    return value.toRadixString(16).padLeft(64, '0');
  }

  /// Decode a uint256 from hex
  BigInt _decodeUint256(String hexValue) {
    final cleanHex = hexValue.startsWith('0x') ? hexValue.substring(2) : hexValue;
    return BigInt.parse(cleanHex, radix: 16);
  }

  /// Decode an address from 32-byte hex (add 41 prefix back)
  String _decodeAddress(String hexValue) {
    final cleanHex = hexValue.startsWith('0x') ? hexValue.substring(2) : hexValue;
    // Take last 40 chars (20 bytes) and add 41 prefix
    final addr = '41${cleanHex.substring(cleanHex.length - 40)}';
    return _hexToTronAddress(addr);
  }

  /// Call a constant (view) contract method
  Future<List<dynamic>> _triggerConstantContract({
    required String functionSelector,
    String parameter = '',
  }) async {
    final ownerHex = _userAddress != null 
        ? _tronAddressToHex(_userAddress!)
        : _tronAddressToHex(_contractAddress); // Use contract as default owner for read calls

    final contractHex = _tronAddressToHex(_contractAddress);
    
    debugPrint('[TronService] Calling $functionSelector');
    debugPrint('[TronService] Owner: $ownerHex');
    debugPrint('[TronService] Contract: $contractHex');
    if (parameter.isNotEmpty) debugPrint('[TronService] Parameter: $parameter');

    final response = await http.post(
      Uri.parse('$_rpcUrl/wallet/triggerconstantcontract'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'owner_address': ownerHex,
        'contract_address': contractHex,
        'function_selector': functionSelector,
        'parameter': parameter,
      }),
    );

    debugPrint('[TronService] Response status: ${response.statusCode}');
    final result = jsonDecode(response.body);
    debugPrint('[TronService] Response body keys: ${result.keys.toList()}');
    
    if (result['result']?['result'] == false) {
      final message = result['result']?['message'] ?? 'Unknown error';
      // Try to decode hex message
      String decodedMessage = message;
      if (message is String && message.isNotEmpty) {
        try {
          decodedMessage = utf8.decode(hex.decode(message));
        } catch (_) {}
      }
      debugPrint('[TronService] Contract call failed: $decodedMessage');
      throw Exception('Contract call failed: $decodedMessage');
    }

    final constantResult = result['constant_result'] as List<dynamic>? ?? [];
    debugPrint('[TronService] constant_result: $constantResult');
    
    // Also check for 'energy_used' which indicates successful execution
    if (result['energy_used'] != null) {
      debugPrint('[TronService] Energy used: ${result['energy_used']}');
    }
    
    return constantResult;
  }

  /// Build, sign, and broadcast a transaction
  Future<String> _sendTransaction({
    required String functionSelector,
    String parameter = '',
    int feeLimit = 150000000, // 150 TRX default
  }) async {
    if (_privateKeyBytes == null || _userAddress == null) {
      throw Exception('Wallet not connected');
    }

    final ownerHex = _tronAddressToHex(_userAddress!);
    final contractHex = _tronAddressToHex(_contractAddress);

    // 1. Build unsigned transaction
    final buildResponse = await http.post(
      Uri.parse('$_rpcUrl/wallet/triggersmartcontract'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'owner_address': ownerHex,
        'contract_address': contractHex,
        'function_selector': functionSelector,
        'parameter': parameter,
        'fee_limit': feeLimit,
        'call_value': 0,
      }),
    );

    final buildResult = jsonDecode(buildResponse.body);
    
    if (buildResult['result']?['result'] != true) {
      final message = buildResult['result']?['message'] ?? 'Failed to build transaction';
      // Decode hex message if present
      String decodedMessage = message;
      if (message is String && message.isNotEmpty) {
        try {
          decodedMessage = utf8.decode(hex.decode(message));
        } catch (_) {}
      }
      throw Exception('Build transaction failed: $decodedMessage');
    }

    final transaction = buildResult['transaction'];
    final txID = transaction['txID'] as String;

    // 2. Sign the transaction
    final signature = _signTransaction(txID);
    transaction['signature'] = [signature];

    // 3. Broadcast
    final broadcastResponse = await http.post(
      Uri.parse('$_rpcUrl/wallet/broadcasttransaction'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(transaction),
    );

    final broadcastResult = jsonDecode(broadcastResponse.body);

    if (broadcastResult['result'] != true) {
      final code = broadcastResult['code'] ?? '';
      final message = broadcastResult['message'] ?? 'Broadcast failed';
      String decodedMessage = message;
      if (message is String && message.isNotEmpty) {
        try {
          decodedMessage = utf8.decode(hex.decode(message));
        } catch (_) {}
      }
      throw Exception('Broadcast failed [$code]: $decodedMessage');
    }

    debugPrint('[TronService] Transaction broadcast successfully: $txID');
    return txID;
  }

  /// Sign a transaction ID using secp256k1
  String _signTransaction(String txID) {
    final txIDBytes = Uint8List.fromList(hex.decode(txID));
    
    // Sign using secp256k1 (same as Ethereum)
    final signature = sign(txIDBytes, _privateKeyBytes!);
    
    // Convert to TRON format: r (32 bytes) + s (32 bytes) + v (1 byte)
    final r = signature.r.toRadixString(16).padLeft(64, '0');
    final s = signature.s.toRadixString(16).padLeft(64, '0');
    // TRON uses recovery id (0 or 1), not Ethereum's 27/28
    final v = ((signature.v - 27) & 0xff).toRadixString(16).padLeft(2, '0');
    
    return r + s + v;
  }

  // ============ BlockchainService Implementation ============

  @override
  Future<BigInt> getThreshold() async {
    final result = await _triggerConstantContract(functionSelector: 'threshold()');
    if (result.isEmpty) throw Exception('Failed to get threshold');
    return _decodeUint256(result[0]);
  }

  @override
  Future<List<String>> getOwners() async {
    final result = await _triggerConstantContract(functionSelector: 'getOwners()');
    if (result.isEmpty) throw Exception('Failed to get owners');
    
    // Decode dynamic array of addresses
    final data = result[0] as String;
    final cleanData = data.startsWith('0x') ? data.substring(2) : data;
    
    // First 32 bytes = offset to array data
    // Next 32 bytes at offset = array length
    // Then array elements (32 bytes each, address in last 20 bytes + 41 prefix)
    
    final offset = _decodeUint256('0x${cleanData.substring(0, 64)}').toInt() * 2;
    final length = _decodeUint256('0x${cleanData.substring(offset, offset + 64)}').toInt();
    
    final owners = <String>[];
    for (int i = 0; i < length; i++) {
      final start = offset + 64 + (i * 64);
      final addrHex = cleanData.substring(start, start + 64);
      owners.add(_decodeAddress(addrHex));
    }
    
    return owners;
  }

  @override
  Future<BigInt> getBalance() async {
    debugPrint('[TronService] Getting balance for contract: $_contractAddress');
    final result = await _triggerConstantContract(functionSelector: 'getBalance()');
    debugPrint('[TronService] getBalance result: $result');
    if (result.isEmpty) {
      debugPrint('[TronService] getBalance returned empty result');
      return BigInt.zero;
    }
    final balance = _decodeUint256(result[0]);
    debugPrint('[TronService] Decoded balance: $balance');
    return balance;
  }

  @override
  Future<String> getUsdtAddress() async {
    final result = await _triggerConstantContract(functionSelector: 'usdt()');
    if (result.isEmpty) throw Exception('Failed to get USDT address');
    final usdtAddr = _decodeAddress(result[0]);
    debugPrint('[TronService] USDT address: $usdtAddr');
    return usdtAddr;
  }

  @override
  Future<BigInt> getNativeBalance() async {
    // Get TRX balance of the contract
    final contractHex = _tronAddressToHex(_contractAddress);
    
    final response = await http.post(
      Uri.parse('$_rpcUrl/wallet/getaccount'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'address': contractHex,
      }),
    );

    final result = jsonDecode(response.body);
    // Balance is in SUN (1 TRX = 1,000,000 SUN)
    final balance = result['balance'] as int? ?? 0;
    debugPrint('[TronService] Native TRX balance: $balance SUN');
    return BigInt.from(balance);
  }

  @override
  Future<int> getTransactionCount() async {
    final result = await _triggerConstantContract(functionSelector: 'getTransactionCount()');
    if (result.isEmpty) throw Exception('Failed to get transaction count');
    return _decodeUint256(result[0]).toInt();
  }

  @override
  Future<TransactionData> getTransaction(int txId) async {
    final param = _encodeUint256(BigInt.from(txId));
    final result = await _triggerConstantContract(
      functionSelector: 'getTransaction(uint256)',
      parameter: param,
    );
    
    if (result.isEmpty) throw Exception('Failed to get transaction');
    
    final data = result[0] as String;
    final cleanData = data.startsWith('0x') ? data.substring(2) : data;
    
    // Returns: (address to, uint256 amount, bool executed, uint256 approvalCount, uint256 createdAt)
    final to = _decodeAddress(cleanData.substring(0, 64));
    final amount = _decodeUint256('0x${cleanData.substring(64, 128)}');
    final executed = _decodeUint256('0x${cleanData.substring(128, 192)}') != BigInt.zero;
    final approvalCount = _decodeUint256('0x${cleanData.substring(192, 256)}').toInt();
    final createdAt = _decodeUint256('0x${cleanData.substring(256, 320)}');
    
    return TransactionData(
      to: to,
      amount: amount,
      executed: executed,
      approvalCount: approvalCount,
      createdAt: createdAt,
    );
  }

  @override
  Future<bool> isTransactionExpired(int txId) async {
    final param = _encodeUint256(BigInt.from(txId));
    final result = await _triggerConstantContract(
      functionSelector: 'isExpired(uint256)',
      parameter: param,
    );
    
    if (result.isEmpty) return false;
    return _decodeUint256(result[0]) != BigInt.zero;
  }

  @override
  Future<int> getExpirationPeriod() async {
    final result = await _triggerConstantContract(
      functionSelector: 'EXPIRATION_PERIOD()',
    );
    if (result.isEmpty) return 86400; // Default fallback
    return _decodeUint256(result[0]).toInt();
  }

  @override
  Future<bool> isApproved(int txId, String owner) async {
    final param = _encodeUint256(BigInt.from(txId)) + _encodeAddress(owner);
    final result = await _triggerConstantContract(
      functionSelector: 'isApproved(uint256,address)',
      parameter: param,
    );
    
    if (result.isEmpty) return false;
    return _decodeUint256(result[0]) != BigInt.zero;
  }

  @override
  Future<bool> checkIsOwner(String address) async {
    final param = _encodeAddress(address);
    final result = await _triggerConstantContract(
      functionSelector: 'isOwner(address)',
      parameter: param,
    );
    
    if (result.isEmpty) return false;
    return _decodeUint256(result[0]) != BigInt.zero;
  }

  @override
  Future<String> submitTransaction(String to, BigInt amount) async {
    final param = _encodeAddress(to) + _encodeUint256(amount);
    return await _sendTransaction(
      functionSelector: 'submitTransaction(address,uint256)',
      parameter: param,
    );
  }

  @override
  Future<String> approveTransaction(int txId) async {
    final param = _encodeUint256(BigInt.from(txId));
    return await _sendTransaction(
      functionSelector: 'approveTransaction(uint256)',
      parameter: param,
    );
  }

  @override
  Future<String> revokeApproval(int txId) async {
    final param = _encodeUint256(BigInt.from(txId));
    return await _sendTransaction(
      functionSelector: 'revokeApproval(uint256)',
      parameter: param,
    );
  }

  @override
  Future<String> cancelExpiredTransaction(int txId) async {
    final param = _encodeUint256(BigInt.from(txId));
    return await _sendTransaction(
      functionSelector: 'cancelExpiredTransaction(uint256)',
      parameter: param,
    );
  }

  @override
  void dispose() {
    // No resources to dispose
  }
}
