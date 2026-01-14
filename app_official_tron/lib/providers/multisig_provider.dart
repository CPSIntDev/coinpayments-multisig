import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/tron_permission.dart';
import '../models/pending_transaction.dart';
import '../services/tron_native_multisig_service.dart';
import '../services/storage_service.dart';

/// Provider for TRON native multisig functionality
class MultisigProvider extends ChangeNotifier {
  final TronNativeMultisigService _service = TronNativeMultisigService();
  
  // Account state
  TronAccountInfo? _accountInfo;
  String? _multisigAddress;
  BigInt _trxBalance = BigInt.zero;
  BigInt _usdtBalance = BigInt.zero;
  String? _usdtAddress; // TRC20 USDT contract address
  
  // Pending transactions (stored locally)
  List<PendingTransaction> _pendingTransactions = [];
  
  // UI state
  bool _isLoading = false;
  String? _error;
  bool _isOwner = false;

  // Getters
  TronAccountInfo? get accountInfo => _accountInfo;
  String? get multisigAddress => _multisigAddress;
  BigInt get trxBalance => _trxBalance;
  BigInt get usdtBalance => _usdtBalance;
  String? get usdtAddress => _usdtAddress;
  List<PendingTransaction> get pendingTransactions => _pendingTransactions;
  List<PendingTransaction> get activePendingTransactions => 
      _pendingTransactions.where((tx) => tx.isPending).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConnected => _service.isConnected;
  bool get isOwner => _isOwner;
  String? get userAddress => _service.userAddress;
  String? get privateKey => _service.privateKey;
  
  // Multisig info
  int get threshold => _accountInfo?.activeThreshold ?? 1;
  List<String> get owners => _accountInfo?.allOwners ?? [];
  bool get isMultisigAccount => _accountInfo?.isMultisig ?? false;
  TronPermission? get activePermission => _accountInfo?.transferPermission;

  // USDT contract addresses
  static const _mainnetUsdt = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t';
  static const _nileUsdt = 'TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf';

  /// Initialize the provider with RPC URL
  Future<void> init({
    required String rpcUrl,
    String? multisigAddress,
    String? usdtAddress,
  }) async {
    await _service.init(rpcUrl: rpcUrl, multisigAddress: multisigAddress);
    _multisigAddress = multisigAddress;
    
    // Auto-detect USDT address based on network
    if (usdtAddress != null) {
      _usdtAddress = usdtAddress;
    } else {
      // Check if it's Nile testnet based on RPC URL
      final isNile = rpcUrl.toLowerCase().contains('nile');
      _usdtAddress = isNile ? _nileUsdt : _mainnetUsdt;
      debugPrint('[Provider] Using ${isNile ? 'Nile' : 'Mainnet'} USDT: $_usdtAddress');
    }
    
    if (multisigAddress != null) {
      await loadAccountData();
    }
    
    // Load pending transactions from storage
    await _loadPendingTransactions();
  }

  /// Connect wallet with private key
  Future<void> connectWallet(String privateKey) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _service.connectWallet(privateKey);
      debugPrint('[Provider] Connected wallet: ${_service.userAddress}');
      
      // Check if user is an owner
      _checkOwnerStatus();
      
      await loadAccountData();
    } catch (e) {
      _error = e.toString();
      debugPrint('[Provider] Connect wallet error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Disconnect wallet
  void disconnect() {
    _service.disconnect();
    _isOwner = false;
    notifyListeners();
  }

  /// Set the multisig account address
  Future<void> setMultisigAddress(String address) async {
    _multisigAddress = address;
    _service.setMultisigAddress(address);
    await loadAccountData();
    _checkOwnerStatus();
    notifyListeners();
  }

  /// Load account data from network
  Future<void> loadAccountData() async {
    if (_multisigAddress == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _accountInfo = await _service.getAccountInfo(_multisigAddress!);
      
      if (_accountInfo != null) {
        _trxBalance = BigInt.from(_accountInfo!.balance);
        
        // Load USDT balance if address is set
        if (_usdtAddress != null) {
          _usdtBalance = await _service.getTrc20Balance(_multisigAddress!, _usdtAddress!);
        }
        
        _checkOwnerStatus();
        debugPrint('[Provider] Account loaded: $_multisigAddress');
        debugPrint('[Provider] TRX Balance: $_trxBalance');
        debugPrint('[Provider] USDT Balance: $_usdtBalance');
        debugPrint('[Provider] Is Multisig: $isMultisigAccount');
        debugPrint('[Provider] Threshold: $threshold');
        debugPrint('[Provider] Owners: $owners');
      }

      // Clean up expired transactions
      _cleanupExpiredTransactions();
      
      // Clean up transactions that are already confirmed on network
      await _cleanupConfirmedTransactions();
      
    } catch (e) {
      _error = e.toString();
      debugPrint('[Provider] Load account error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if connected user is an owner/signer
  void _checkOwnerStatus() {
    if (_service.userAddress == null) {
      _isOwner = false;
      return;
    }

    final userAddr = _service.userAddress!;
    final userAddrLower = userAddr.toLowerCase();
    
    // If user address IS the multisig address, they're the owner
    if (_multisigAddress != null && 
        userAddrLower == _multisigAddress!.toLowerCase()) {
      _isOwner = true;
      debugPrint('[Provider] User is the account owner (same address)');
      return;
    }
    
    // Check if user is in the owners list (compare case-insensitive)
    if (_accountInfo != null && owners.isNotEmpty) {
      _isOwner = owners.any((o) {
        // Compare addresses case-insensitively
        final match = o.toLowerCase() == userAddrLower;
        if (match) {
          debugPrint('[Provider] User $userAddr matches owner $o');
        }
        return match;
      });
      
      if (!_isOwner) {
        debugPrint('[Provider] User $userAddr not found in owners: $owners');
      }
    } else {
      // If no account info or empty owners, assume owner if connected
      // This handles accounts that haven't set up permissions yet
      _isOwner = true;
      debugPrint('[Provider] No owners list, assuming owner');
    }
    
    debugPrint('[Provider] User $userAddr isOwner: $_isOwner');
  }

  /// Create a TRX transfer transaction
  Future<PendingTransaction?> createTrxTransfer({
    required String to,
    required BigInt amount,
    String? description,
  }) async {
    if (_multisigAddress == null || !isConnected) {
      _error = 'Not connected';
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final tx = await _service.createTrxTransfer(
        from: _multisigAddress!,
        to: to,
        amount: amount,
      );

      // Sign with current user
      final signedTx = _service.signAndAddToTransaction(tx);
      final signers = await _service.getSignerAddresses(signedTx);

      // Extract actual expiration from transaction (TRON uses milliseconds)
      final expiresAt = _extractExpiration(tx);

      final pendingTx = PendingTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        txId: tx['txID'] as String,
        rawTransaction: signedTx,
        fromAddress: _multisigAddress!,
        toAddress: to,
        amount: amount,
        assetType: 'TRX',
        threshold: threshold,
        signers: signers,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        description: description,
      );

      _pendingTransactions.insert(0, pendingTx);
      await _savePendingTransactions();
      
      debugPrint('[Provider] Created TRX transfer: ${pendingTx.txId}');
      return pendingTx;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Provider] Create TRX transfer error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a USDT (TRC20) transfer transaction
  Future<PendingTransaction?> createUsdtTransfer({
    required String to,
    required BigInt amount,
    String? description,
  }) async {
    if (_multisigAddress == null || !isConnected || _usdtAddress == null) {
      _error = 'Not connected or USDT address not set';
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final tx = await _service.createTrc20Transfer(
        from: _multisigAddress!,
        tokenAddress: _usdtAddress!,
        to: to,
        amount: amount,
      );

      // Sign with current user
      final signedTx = _service.signAndAddToTransaction(tx);
      final signers = await _service.getSignerAddresses(signedTx);

      // Extract actual expiration from transaction
      final expiresAt = _extractExpiration(tx);

      final pendingTx = PendingTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        txId: tx['txID'] as String,
        rawTransaction: signedTx,
        fromAddress: _multisigAddress!,
        toAddress: to,
        amount: amount,
        assetType: _usdtAddress!,
        threshold: threshold,
        signers: signers,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        description: description,
      );

      _pendingTransactions.insert(0, pendingTx);
      await _savePendingTransactions();
      
      debugPrint('[Provider] Created USDT transfer: ${pendingTx.txId}');
      return pendingTx;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Provider] Create USDT transfer error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign a pending transaction
  Future<bool> signTransaction(String pendingTxId) async {
    final index = _pendingTransactions.indexWhere((tx) => tx.id == pendingTxId);
    if (index < 0) {
      _error = 'Transaction not found';
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final pendingTx = _pendingTransactions[index];
      
      // Check if already signed
      final userAddr = _service.userAddress;
      if (userAddr != null && pendingTx.signers.any((s) => s.toLowerCase() == userAddr.toLowerCase())) {
        _error = 'Already signed';
        return false;
      }

      // Sign
      final signedTx = _service.signAndAddToTransaction(pendingTx.rawTransaction);
      final signers = await _service.getSignerAddresses(signedTx);

      // Update pending transaction
      final updated = pendingTx.copyWith(
        rawTransaction: signedTx,
        signers: signers,
        status: signers.length >= pendingTx.threshold 
            ? PendingTxStatus.ready 
            : PendingTxStatus.pending,
      );

      _pendingTransactions[index] = updated;
      await _savePendingTransactions();
      
      debugPrint('[Provider] Signed transaction: ${pendingTx.txId}, signers: ${signers.length}/${pendingTx.threshold}');
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Provider] Sign error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Broadcast a transaction that has enough signatures
  Future<String?> broadcastTransaction(String pendingTxId) async {
    final index = _pendingTransactions.indexWhere((tx) => tx.id == pendingTxId);
    if (index < 0) {
      _error = 'Transaction not found';
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final pendingTx = _pendingTransactions[index];
      
      if (!pendingTx.canBroadcast) {
        _error = 'Not enough signatures or transaction expired';
        return null;
      }

      final txId = await _service.broadcastTransaction(pendingTx.rawTransaction);
      
      // Update status
      final updated = pendingTx.copyWith(
        status: PendingTxStatus.broadcast,
        broadcastTxId: txId,
      );
      
      _pendingTransactions[index] = updated;
      await _savePendingTransactions();
      
      // Reload balances
      await loadAccountData();
      
      debugPrint('[Provider] Broadcast transaction: $txId');
      return txId;
    } catch (e) {
      _error = e.toString();
      
      // Update status to failed
      final pendingTx = _pendingTransactions[index];
      _pendingTransactions[index] = pendingTx.copyWith(
        status: PendingTxStatus.failed,
        errorMessage: e.toString(),
      );
      await _savePendingTransactions();
      
      debugPrint('[Provider] Broadcast error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Import a transaction from another signer
  Future<bool> importTransaction(String jsonData) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final pendingTx = _service.deserializeTransaction(jsonData);
      
      // Check if already exists
      if (_pendingTransactions.any((tx) => tx.txId == pendingTx.txId)) {
        // Merge signatures
        final index = _pendingTransactions.indexWhere((tx) => tx.txId == pendingTx.txId);
        final existing = _pendingTransactions[index];
        
        // Combine signatures
        final combinedSignatures = <String>{
          ...existing.rawTransaction['signature'] as List<dynamic>? ?? [],
          ...pendingTx.rawTransaction['signature'] as List<dynamic>? ?? [],
        }.toList();
        
        final updatedRawTx = Map<String, dynamic>.from(existing.rawTransaction);
        updatedRawTx['signature'] = combinedSignatures;
        
        final signers = await _service.getSignerAddresses(updatedRawTx);
        
        _pendingTransactions[index] = existing.copyWith(
          rawTransaction: updatedRawTx,
          signers: signers,
          status: signers.length >= existing.threshold 
              ? PendingTxStatus.ready 
              : PendingTxStatus.pending,
        );
      } else {
        // Add new
        _pendingTransactions.insert(0, pendingTx);
      }
      
      await _savePendingTransactions();
      debugPrint('[Provider] Imported transaction: ${pendingTx.txId}');
      return true;
    } catch (e) {
      _error = 'Invalid transaction data: $e';
      debugPrint('[Provider] Import error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Export a transaction for sharing
  String? exportTransaction(String pendingTxId) {
    final tx = _pendingTransactions.firstWhere(
      (tx) => tx.id == pendingTxId,
      orElse: () => throw Exception('Not found'),
    );
    return _service.serializeTransaction(tx);
  }

  /// Delete a pending transaction
  Future<void> deleteTransaction(String pendingTxId) async {
    _pendingTransactions.removeWhere((tx) => tx.id == pendingTxId);
    await _savePendingTransactions();
    notifyListeners();
  }

  /// Check if user has signed a specific transaction
  bool hasUserSigned(String pendingTxId) {
    final tx = _pendingTransactions.firstWhere(
      (tx) => tx.id == pendingTxId,
      orElse: () => throw Exception('Not found'),
    );
    
    final userAddr = _service.userAddress;
    if (userAddr == null) return false;
    
    return tx.signers.any((s) => s.toLowerCase() == userAddr.toLowerCase());
  }

  // ============ Permission Management ============

  /// Add a new signer to the multisig account
  Future<PendingTransaction?> addSigner({
    required String newSignerAddress,
    required int weight,
    int? newThreshold,
    String? description,
  }) async {
    if (_multisigAddress == null || !isConnected) {
      _error = 'Not connected';
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final tx = await _service.createAddSignerTransaction(
        accountAddress: _multisigAddress!,
        newSignerAddress: newSignerAddress,
        weight: weight,
        newThreshold: newThreshold,
      );

      // Sign with current user
      final signedTx = _service.signAndAddToTransaction(tx);
      final signers = await _service.getSignerAddresses(signedTx);

      final pendingTx = PendingTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        txId: tx['txID'] as String,
        rawTransaction: signedTx,
        fromAddress: _multisigAddress!,
        toAddress: newSignerAddress,
        amount: BigInt.zero,
        assetType: 'PERMISSION_UPDATE',
        threshold: threshold,
        signers: signers,
        createdAt: DateTime.now(),
        expiresAt: _extractExpiration(tx),
        description: description ?? 'Add signer: ${newSignerAddress.substring(0, 8)}... (weight: $weight)',
      );

      _pendingTransactions.insert(0, pendingTx);
      await _savePendingTransactions();
      
      debugPrint('[Provider] Created add signer tx: ${pendingTx.txId}');
      return pendingTx;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Provider] Add signer error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Remove a signer from the multisig account
  Future<PendingTransaction?> removeSigner({
    required String signerToRemove,
    int? newThreshold,
    String? description,
  }) async {
    if (_multisigAddress == null || !isConnected) {
      _error = 'Not connected';
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final tx = await _service.createRemoveSignerTransaction(
        accountAddress: _multisigAddress!,
        signerToRemove: signerToRemove,
        newThreshold: newThreshold,
      );

      // Sign with current user
      final signedTx = _service.signAndAddToTransaction(tx);
      final signers = await _service.getSignerAddresses(signedTx);

      final pendingTx = PendingTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        txId: tx['txID'] as String,
        rawTransaction: signedTx,
        fromAddress: _multisigAddress!,
        toAddress: signerToRemove,
        amount: BigInt.zero,
        assetType: 'PERMISSION_UPDATE',
        threshold: threshold,
        signers: signers,
        createdAt: DateTime.now(),
        expiresAt: _extractExpiration(tx),
        description: description ?? 'Remove signer: ${signerToRemove.substring(0, 8)}...',
      );

      _pendingTransactions.insert(0, pendingTx);
      await _savePendingTransactions();
      
      debugPrint('[Provider] Created remove signer tx: ${pendingTx.txId}');
      return pendingTx;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Provider] Remove signer error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update the threshold
  Future<PendingTransaction?> updateThreshold({
    required int newThreshold,
    String? description,
  }) async {
    if (_multisigAddress == null || !isConnected) {
      _error = 'Not connected';
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final tx = await _service.createUpdateThresholdTransaction(
        accountAddress: _multisigAddress!,
        newThreshold: newThreshold,
      );

      // Sign with current user
      final signedTx = _service.signAndAddToTransaction(tx);
      final signers = await _service.getSignerAddresses(signedTx);

      final pendingTx = PendingTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        txId: tx['txID'] as String,
        rawTransaction: signedTx,
        fromAddress: _multisigAddress!,
        toAddress: _multisigAddress!,
        amount: BigInt.zero,
        assetType: 'PERMISSION_UPDATE',
        threshold: threshold,
        signers: signers,
        createdAt: DateTime.now(),
        expiresAt: _extractExpiration(tx),
        description: description ?? 'Update threshold to $newThreshold',
      );

      _pendingTransactions.insert(0, pendingTx);
      await _savePendingTransactions();
      
      debugPrint('[Provider] Created update threshold tx: ${pendingTx.txId}');
      return pendingTx;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Provider] Update threshold error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Setup multisig with initial signers
  Future<PendingTransaction?> setupMultisig({
    required List<SignerInfo> signers,
    required int threshold,
    String? description,
  }) async {
    if (_multisigAddress == null || !isConnected) {
      _error = 'Not connected';
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final tx = await _service.createMultisigSetupTransaction(
        accountAddress: _multisigAddress!,
        signers: signers,
        threshold: threshold,
      );

      // Sign with current user
      final signedTx = _service.signAndAddToTransaction(tx);
      final txSigners = await _service.getSignerAddresses(signedTx);

      final pendingTx = PendingTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        txId: tx['txID'] as String,
        rawTransaction: signedTx,
        fromAddress: _multisigAddress!,
        toAddress: _multisigAddress!,
        amount: BigInt.zero,
        assetType: 'PERMISSION_UPDATE',
        threshold: 1, // Current threshold (before update)
        signers: txSigners,
        createdAt: DateTime.now(),
        expiresAt: _extractExpiration(tx),
        description: description ?? 'Setup multisig: ${signers.length} signers, threshold $threshold',
      );

      _pendingTransactions.insert(0, pendingTx);
      await _savePendingTransactions();
      
      debugPrint('[Provider] Created multisig setup tx: ${pendingTx.txId}');
      return pendingTx;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Provider] Setup multisig error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Extract the actual expiration time from a TRON transaction
  /// TRON stores expiration as Unix timestamp in milliseconds in raw_data.expiration
  DateTime _extractExpiration(Map<String, dynamic> tx) {
    try {
      final rawData = tx['raw_data'] as Map<String, dynamic>?;
      if (rawData != null && rawData['expiration'] != null) {
        final expirationMs = rawData['expiration'] as int;
        return DateTime.fromMillisecondsSinceEpoch(expirationMs);
      }
    } catch (e) {
      debugPrint('[Provider] Error extracting expiration: $e');
    }
    // Fallback to 1 minute from now (TRON default is ~60 seconds)
    return DateTime.now().add(const Duration(minutes: 1));
  }

  // Storage methods
  static const _pendingTxKey = 'pending_transactions';

  Future<void> _loadPendingTransactions() async {
    try {
      final data = await StorageService.getString(_pendingTxKey);
      
      if (data != null && data.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(data);
        _pendingTransactions = jsonList
            .map((e) => PendingTransaction.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('[Provider] Loaded ${_pendingTransactions.length} pending transactions');
      }
    } catch (e) {
      debugPrint('[Provider] Load pending tx error: $e');
    }
  }

  Future<void> _savePendingTransactions() async {
    try {
      final data = jsonEncode(_pendingTransactions.map((tx) => tx.toJson()).toList());
      await StorageService.setString(_pendingTxKey, data);
    } catch (e) {
      debugPrint('[Provider] Save pending tx error: $e');
    }
  }

  void _cleanupExpiredTransactions() {
    for (int i = 0; i < _pendingTransactions.length; i++) {
      final tx = _pendingTransactions[i];
      if (tx.isExpired && tx.status == PendingTxStatus.pending) {
        _pendingTransactions[i] = tx.copyWith(status: PendingTxStatus.expired);
      }
    }
  }

  /// Check pending transactions against the network and remove confirmed ones
  Future<void> _cleanupConfirmedTransactions() async {
    if (_pendingTransactions.isEmpty) return;
    
    final toRemove = <String>[];
    
    for (final tx in _pendingTransactions) {
      // Only check transactions that are pending or ready (not already broadcast/failed/expired)
      if (tx.status != PendingTxStatus.pending && 
          tx.status != PendingTxStatus.ready) {
        continue;
      }
      
      try {
        // Check if transaction exists on the network
        final txInfo = await _service.getTransactionInfo(tx.txId);
        
        if (txInfo != null && txInfo.isNotEmpty) {
          // Transaction found on network - it's been confirmed
          // Check if it has a receipt (meaning it was executed)
          if (txInfo['receipt'] != null || txInfo['blockNumber'] != null) {
            debugPrint('[Provider] Transaction ${tx.txId} found on network, removing from pending');
            toRemove.add(tx.id);
          }
        }
      } catch (e) {
        // Ignore errors for individual transaction checks
        debugPrint('[Provider] Error checking tx ${tx.txId}: $e');
      }
    }
    
    // Remove confirmed transactions
    if (toRemove.isNotEmpty) {
      _pendingTransactions.removeWhere((tx) => toRemove.contains(tx.id));
      await _savePendingTransactions();
      debugPrint('[Provider] Removed ${toRemove.length} confirmed transactions');
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
