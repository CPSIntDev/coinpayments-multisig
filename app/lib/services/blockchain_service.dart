/// Abstract interface for blockchain services (EVM/TVM)
/// Both ContractService (EVM) and TronService (TVM) implement this
abstract class BlockchainService {
  bool get isConnected;
  String? get userAddress;
  String get contractAddress;
  String? get privateKey; // For contract switching

  Future<void> init({
    required String rpcUrl,
    required String contractAddress,
  });

  Future<void> connectWallet(String privateKey);
  void disconnect();

  // Read functions
  Future<BigInt> getThreshold();
  Future<List<String>> getOwners();
  Future<BigInt> getBalance();
  Future<BigInt> getNativeBalance(); // TRX for TVM, ETH for EVM
  Future<String> getUsdtAddress();
  Future<int> getTransactionCount();
  Future<TransactionData> getTransaction(int txId);
  Future<bool> isApproved(int txId, String owner);
  Future<bool> checkIsOwner(String address);
  Future<bool> isTransactionExpired(int txId);
  Future<int> getExpirationPeriod();

  // Write functions
  Future<String> submitTransaction(String to, BigInt amount);
  Future<String> approveTransaction(int txId);
  Future<String> revokeApproval(int txId);
  Future<String> cancelExpiredTransaction(int txId);

  void dispose();
}

/// Network-agnostic transaction data
class TransactionData {
  final String to;
  final BigInt amount;
  final bool executed;
  final int approvalCount;
  final BigInt createdAt;

  TransactionData({
    required this.to,
    required this.amount,
    required this.executed,
    required this.approvalCount,
    required this.createdAt,
  });
}
