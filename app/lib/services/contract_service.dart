import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'blockchain_service.dart';

class ContractService implements BlockchainService {
  late Web3Client _client;
  late DeployedContract _contract;
  late EthereumAddress _contractAddressEth;
  EthPrivateKey? _credentials;
  EthereumAddress? _userAddressEth;

  static const String _abi = '''
[
  {
    "inputs": [{"internalType": "address", "name": "_usdt", "type": "address"}, {"internalType": "address[]", "name": "_owners", "type": "address[]"}, {"internalType": "uint256", "name": "_threshold", "type": "uint256"}],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [],
    "name": "usdt",
    "outputs": [{"internalType": "contract IERC20", "name": "", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "threshold",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "EXPIRATION_PERIOD",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getOwners",
    "outputs": [{"internalType": "address[]", "name": "", "type": "address[]"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getOwnerCount",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getBalance",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getTransactionCount",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256", "name": "_txId", "type": "uint256"}],
    "name": "getTransaction",
    "outputs": [
      {"internalType": "address", "name": "to", "type": "address"},
      {"internalType": "uint256", "name": "amount", "type": "uint256"},
      {"internalType": "bool", "name": "executed", "type": "bool"},
      {"internalType": "uint256", "name": "approvalCount", "type": "uint256"},
      {"internalType": "uint256", "name": "createdAt", "type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256", "name": "_txId", "type": "uint256"}, {"internalType": "address", "name": "_owner", "type": "address"}],
    "name": "isApproved",
    "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address", "name": "", "type": "address"}],
    "name": "isOwner",
    "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256", "name": "_txId", "type": "uint256"}],
    "name": "isExpired",
    "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address", "name": "_to", "type": "address"}, {"internalType": "uint256", "name": "_amount", "type": "uint256"}],
    "name": "submitTransaction",
    "outputs": [{"internalType": "uint256", "name": "txId", "type": "uint256"}],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256", "name": "_txId", "type": "uint256"}],
    "name": "approveTransaction",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256", "name": "_txId", "type": "uint256"}],
    "name": "revokeApproval",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256", "name": "_txId", "type": "uint256"}],
    "name": "cancelExpiredTransaction",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
''';

  String? _privateKeyHex;

  @override
  bool get isConnected => _credentials != null;
  
  @override
  String? get userAddress => _userAddressEth?.hexEip55;
  
  @override
  String get contractAddress => _contractAddressEth.hexEip55;

  @override
  String? get privateKey => _privateKeyHex;

  // Legacy getters for compatibility
  EthereumAddress? get userAddressEth => _userAddressEth;
  EthereumAddress get contractAddressEth => _contractAddressEth;

  @override
  Future<void> init({
    required String rpcUrl,
    required String contractAddress,
  }) async {
    _client = Web3Client(rpcUrl, http.Client());
    _contractAddressEth = EthereumAddress.fromHex(contractAddress);
    _contract = DeployedContract(
      ContractAbi.fromJson(_abi, 'USDTMultisig'),
      _contractAddressEth,
    );
  }

  @override
  Future<void> connectWallet(String privateKey) async {
    _privateKeyHex = privateKey.startsWith('0x') ? privateKey.substring(2) : privateKey;
    _credentials = EthPrivateKey.fromHex(privateKey);
    _userAddressEth = _credentials!.address;
  }

  @override
  void disconnect() {
    _credentials = null;
    _userAddressEth = null;
    _privateKeyHex = null;
  }

  // Read functions
  @override
  Future<BigInt> getThreshold() async {
    final result = await _client.call(
      contract: _contract,
      function: _contract.function('threshold'),
      params: [],
    );
    return result.first as BigInt;
  }

  @override
  Future<List<String>> getOwners() async {
    final result = await _client.call(
      contract: _contract,
      function: _contract.function('getOwners'),
      params: [],
    );
    return (result.first as List)
        .cast<EthereumAddress>()
        .map((e) => e.hexEip55)
        .toList();
  }

  @override
  Future<BigInt> getBalance() async {
    final result = await _client.call(
      contract: _contract,
      function: _contract.function('getBalance'),
      params: [],
    );
    return result.first as BigInt;
  }

  @override
  Future<BigInt> getNativeBalance() async {
    // Get ETH balance of the contract address
    final balance = await _client.getBalance(_contractAddressEth);
    return balance.getInWei;
  }

  @override
  Future<String> getUsdtAddress() async {
    final result = await _client.call(
      contract: _contract,
      function: _contract.function('usdt'),
      params: [],
    );
    return (result.first as EthereumAddress).hexEip55;
  }

  @override
  Future<int> getTransactionCount() async {
    final result = await _client.call(
      contract: _contract,
      function: _contract.function('getTransactionCount'),
      params: [],
    );
    return (result.first as BigInt).toInt();
  }

  @override
  Future<TransactionData> getTransaction(int txId) async {
    final result = await _client.call(
      contract: _contract,
      function: _contract.function('getTransaction'),
      params: [BigInt.from(txId)],
    );
    return TransactionData(
      to: (result[0] as EthereumAddress).hexEip55,
      amount: result[1] as BigInt,
      executed: result[2] as bool,
      approvalCount: (result[3] as BigInt).toInt(),
      createdAt: result[4] as BigInt,
    );
  }

  @override
  Future<bool> isTransactionExpired(int txId) async {
    final result = await _client.call(
      contract: _contract,
      function: _contract.function('isExpired'),
      params: [BigInt.from(txId)],
    );
    return result.first as bool;
  }

  @override
  Future<int> getExpirationPeriod() async {
    final result = await _client.call(
      contract: _contract,
      function: _contract.function('EXPIRATION_PERIOD'),
      params: [],
    );
    return (result.first as BigInt).toInt();
  }

  @override
  Future<bool> isApproved(int txId, String owner) async {
    final result = await _client.call(
      contract: _contract,
      function: _contract.function('isApproved'),
      params: [BigInt.from(txId), EthereumAddress.fromHex(owner)],
    );
    return result.first as bool;
  }

  @override
  Future<bool> checkIsOwner(String address) async {
    final result = await _client.call(
      contract: _contract,
      function: _contract.function('isOwner'),
      params: [EthereumAddress.fromHex(address)],
    );
    return result.first as bool;
  }

  // Write functions
  @override
  Future<String> submitTransaction(String to, BigInt amount) async {
    if (_credentials == null) throw Exception('Wallet not connected');

    final chainId = await _client.getChainId();
    final tx = Transaction.callContract(
      contract: _contract,
      function: _contract.function('submitTransaction'),
      parameters: [EthereumAddress.fromHex(to), amount],
    );

    return await _client.sendTransaction(
      _credentials!,
      tx,
      chainId: chainId.toInt(),
    );
  }

  @override
  Future<String> approveTransaction(int txId) async {
    if (_credentials == null) throw Exception('Wallet not connected');

    debugPrint('[ContractService] approveTransaction($txId) called');
    debugPrint('[ContractService] User address: ${_userAddressEth?.hexEip55}');
    
    final chainId = await _client.getChainId();
    debugPrint('[ContractService] Chain ID: $chainId');
    
    final tx = Transaction.callContract(
      contract: _contract,
      function: _contract.function('approveTransaction'),
      parameters: [BigInt.from(txId)],
    );

    debugPrint('[ContractService] Sending transaction...');
    final result = await _client.sendTransaction(
      _credentials!,
      tx,
      chainId: chainId.toInt(),
    );
    debugPrint('[ContractService] Transaction sent: $result');
    return result;
  }

  @override
  Future<String> revokeApproval(int txId) async {
    if (_credentials == null) throw Exception('Wallet not connected');

    final chainId = await _client.getChainId();
    final tx = Transaction.callContract(
      contract: _contract,
      function: _contract.function('revokeApproval'),
      parameters: [BigInt.from(txId)],
    );

    return await _client.sendTransaction(
      _credentials!,
      tx,
      chainId: chainId.toInt(),
    );
  }

  @override
  Future<String> cancelExpiredTransaction(int txId) async {
    if (_credentials == null) throw Exception('Wallet not connected');

    final chainId = await _client.getChainId();
    final tx = Transaction.callContract(
      contract: _contract,
      function: _contract.function('cancelExpiredTransaction'),
      parameters: [BigInt.from(txId)],
    );

    return await _client.sendTransaction(
      _credentials!,
      tx,
      chainId: chainId.toInt(),
    );
  }

  @override
  void dispose() {
    _client.dispose();
  }
}
