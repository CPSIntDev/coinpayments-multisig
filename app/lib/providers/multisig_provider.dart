import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/multisig_info.dart';
import '../services/blockchain_service.dart';
import '../services/contract_service.dart';
import '../services/tron_service.dart';
import '../services/contracts_service.dart';

class MultisigProvider extends ChangeNotifier {
  BlockchainService? _blockchainService;
  NetworkType _networkType = NetworkType.evm;

  MultisigInfo? _info;
  List<MultisigTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;
  bool _isOwner = false;

  MultisigInfo? get info => _info;
  List<MultisigTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConnected => _blockchainService?.isConnected ?? false;
  bool get isOwner => _isOwner;
  String? get userAddress => _blockchainService?.userAddress;
  NetworkType get networkType => _networkType;
  BlockchainService? get blockchainService => _blockchainService;

  Future<void> init({
    required String rpcUrl,
    required String contractAddress,
    NetworkType networkType = NetworkType.evm,
  }) async {
    _networkType = networkType;
    
    // Create appropriate service based on network type
    if (networkType == NetworkType.tvm) {
      _blockchainService = TronService();
    } else {
      _blockchainService = ContractService();
    }
    
    await _blockchainService!.init(
      rpcUrl: rpcUrl,
      contractAddress: contractAddress,
    );
    await loadData();
  }

  Future<void> connectWallet(String privateKey) async {
    if (_blockchainService == null) {
      throw Exception('Provider not initialized');
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('Connecting wallet with key length: ${privateKey.length}');
      await _blockchainService!.connectWallet(privateKey);

      if (_blockchainService!.userAddress != null) {
        debugPrint('Connected wallet: ${_blockchainService!.userAddress}');
        
        // Load data first to get owners list
        await loadData();
        
        // Check owner status using owners list (more reliable)
        if (_info != null) {
          final userAddr = _blockchainService!.userAddress!.toLowerCase();
          _isOwner = _info!.owners.any(
            (owner) => owner.toLowerCase() == userAddr
          );
          debugPrint('User address: $userAddr');
          debugPrint('Owners: ${_info!.owners}');
          debugPrint('Is owner (from list): $_isOwner');
        }
        
        // Also try contract call as backup
        if (!_isOwner) {
          try {
            _isOwner = await _blockchainService!.checkIsOwner(
              _blockchainService!.userAddress!,
            );
            debugPrint('Is owner (from contract): $_isOwner');
          } catch (e) {
            debugPrint('Error checking owner via contract: $e');
          }
        }
        
        debugPrint('Final owner status: $_isOwner');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Connect wallet error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _blockchainService?.disconnect();
    _isOwner = false;
    _info = null;
    _transactions = [];
    notifyListeners();
  }

  /// Switch to a different contract while preserving wallet connection
  /// This is used when changing contracts in settings without logging out
  Future<void> switchContract({
    required String rpcUrl,
    required String contractAddress,
    required NetworkType networkType,
    required String privateKey,
  }) async {
    _networkType = networkType;
    
    // Dispose old service
    _blockchainService?.dispose();
    
    // Create appropriate service based on network type
    if (networkType == NetworkType.tvm) {
      _blockchainService = TronService();
    } else {
      _blockchainService = ContractService();
    }
    
    await _blockchainService!.init(
      rpcUrl: rpcUrl,
      contractAddress: contractAddress,
    );
    
    // Reconnect wallet with the same private key
    await _blockchainService!.connectWallet(privateKey);
    
    // Reload data
    await loadData();
    
    // Re-check owner status
    if (_blockchainService!.userAddress != null && _info != null) {
      final userAddr = _blockchainService!.userAddress!.toLowerCase();
      _isOwner = _info!.owners.any(
        (owner) => owner.toLowerCase() == userAddr
      );
      debugPrint('Owner status after switch: $_isOwner');
    }
    
    notifyListeners();
  }

  String? get contractAddress => _blockchainService?.contractAddress;

  Future<void> loadData() async {
    if (_blockchainService == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final owners = await _blockchainService!.getOwners();
      final threshold = await _blockchainService!.getThreshold();
      final balance = await _blockchainService!.getBalance();
      final nativeBalance = await _blockchainService!.getNativeBalance();
      final usdtAddress = await _blockchainService!.getUsdtAddress();
      final expirationPeriod = await _blockchainService!.getExpirationPeriod();

      _info = MultisigInfo(
        owners: owners,
        threshold: threshold.toInt(),
        balance: balance,
        nativeBalance: nativeBalance,
        usdtAddress: usdtAddress,
        isTron: _networkType == NetworkType.tvm,
        expirationPeriod: expirationPeriod,
      );

      // Re-check owner status when data is reloaded
      if (_blockchainService!.userAddress != null && _info != null) {
        final userAddr = _blockchainService!.userAddress!.toLowerCase();
        final wasOwner = _isOwner;
        _isOwner = _info!.owners.any(
          (owner) => owner.toLowerCase() == userAddr
        );
        if (wasOwner != _isOwner) {
          debugPrint('Owner status updated: $_isOwner');
        }
      }

      await loadTransactions();
    } catch (e) {
      _error = e.toString();
      debugPrint('Load data error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTransactions() async {
    if (_blockchainService == null) return;

    try {
      final count = await _blockchainService!.getTransactionCount();
      final txs = <MultisigTransaction>[];
      final expirationPeriod = _info?.expirationPeriod ?? 86400; // Fallback to 1 day

      for (int i = count - 1; i >= 0; i--) {
        final data = await _blockchainService!.getTransaction(i);
        txs.add(MultisigTransaction(
          id: i,
          to: data.to,
          amount: data.amount,
          executed: data.executed,
          approvalCount: data.approvalCount,
          createdAt: data.createdAt,
          expirationPeriod: expirationPeriod,
        ));
      }

      _transactions = txs;
    } catch (e) {
      _error = e.toString();
      debugPrint('Load transactions error: $e');
    }
    notifyListeners();
  }

  Future<bool> isTransactionApproved(int txId) async {
    if (_blockchainService?.userAddress == null) return false;
    return await _blockchainService!.isApproved(
      txId,
      _blockchainService!.userAddress!,
    );
  }

  Future<String?> submitTransaction(String toAddress, double amount) async {
    if (_blockchainService == null) return null;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Convert to USDT amount (6 decimals)
      final amountBigInt = BigInt.from(amount * 1000000);

      final txHash = await _blockchainService!.submitTransaction(toAddress, amountBigInt);
      await loadData();
      return txHash;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> approveTransaction(int txId) async {
    if (_blockchainService == null) return null;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('[Provider] Approving transaction $txId...');
      final txHash = await _blockchainService!.approveTransaction(txId);
      debugPrint('[Provider] Approval txHash: $txHash');
      await loadData();
      return txHash;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Provider] Approval error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> revokeApproval(int txId) async {
    if (_blockchainService == null) return null;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final txHash = await _blockchainService!.revokeApproval(txId);
      await loadData();
      return txHash;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> cancelExpiredTransaction(int txId) async {
    if (_blockchainService == null) return null;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('[Provider] Cancelling expired transaction $txId...');
      final txHash = await _blockchainService!.cancelExpiredTransaction(txId);
      debugPrint('[Provider] Cancel txHash: $txHash');
      await loadData();
      return txHash;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Provider] Cancel error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _blockchainService?.dispose();
    super.dispose();
  }
}
