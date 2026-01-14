import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:web3dart/crypto.dart';
import 'package:blockchain_utils/blockchain_utils.dart' hide hex;
import 'package:convert/convert.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'providers/multisig_provider.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'services/crypto_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Get instance ID from dart-define (compile time) or command line args (runtime)
  String instanceId = const String.fromEnvironment('INSTANCE', defaultValue: '');
  
  // Also check command line args for runtime override
  for (final arg in args) {
    if (arg.startsWith('--instance=')) {
      instanceId = arg.substring('--instance='.length);
      break;
    }
  }
  
  // Set instance ID for isolated storage
  StorageService.setInstanceId(instanceId);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Update window title to show instance
  final title = instanceId.isEmpty ? 'TRON Multisig' : 'TRON Multisig #$instanceId';
  
  runApp(MyApp(title: title, instanceId: instanceId));
}

class MyApp extends StatelessWidget {
  final String title;
  final String instanceId;
  
  const MyApp({super.key, this.title = 'TRON Multisig', this.instanceId = ''});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MultisigProvider(),
      child: MaterialApp(
        title: title,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.white,
          primaryColor: Colors.black,
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            secondary: Colors.black,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              color: Colors.black,
            ),
            headlineMedium: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: Colors.black,
            ),
            titleLarge: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: Colors.black,
            ),
            bodyLarge: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            bodyMedium: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.black54,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              elevation: 0,
              minimumSize: const Size(double.infinity, 56),
              side: const BorderSide(color: Colors.black, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          dividerTheme: DividerThemeData(
            color: Colors.grey.shade200,
            thickness: 1,
          ),
          useMaterial3: true,
        ),
        home: const InitScreen(),
      ),
    );
  }
}

class InitScreen extends StatefulWidget {
  const InitScreen({super.key});

  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  bool _isInitialized = false;
  bool _hasConfig = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Load saved configuration
      final config = await MultisigConfig.load();

      if (config != null) {
        if (!mounted) return;
        final provider = context.read<MultisigProvider>();
        await provider.init(
          rpcUrl: config.rpcUrl,
          multisigAddress: config.multisigAddress,
          usdtAddress: config.usdtAddress,
        );
        if (!mounted) return;
        setState(() {
          _hasConfig = true;
          _isInitialized = true;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _hasConfig = false;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.black),
              SizedBox(height: 24),
              Text(
                'TRON Multisig',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Native Account Permissions',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

    if (!_hasConfig) {
      return const ConfigurationScreen();
    }

    return const HomeScreen();
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ResponsiveContainer(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.black),
                  const SizedBox(height: 24),
                  const Text(
                    'Connection Error',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error ?? 'Unknown error',
                    style: const TextStyle(color: Colors.black54, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _hasConfig = false;
                        });
                      },
                      child: const Text('Configure'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  final _nameController = TextEditingController();
  final _rpcController = TextEditingController();
  final _addressController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _isMainnet = true;
  bool _createFromPrivateKey = true; // Default to create from private key
  bool _obscureKey = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _derivedAddress;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  void _loadDefaults() {
    _nameController.text = 'My Multisig';
    _rpcController.text = 'https://api.trongrid.io';
  }

  void _switchNetwork(bool isMainnet) {
    setState(() {
      _isMainnet = isMainnet;
      if (isMainnet) {
        _rpcController.text = 'https://api.trongrid.io';
      } else {
        _rpcController.text = 'https://nile.trongrid.io';
      }
    });
  }

  void _onPrivateKeyChanged(String value) {
    final cleanKey = value.trim();
    final normalizedKey = cleanKey.startsWith('0x') ? cleanKey.substring(2) : cleanKey;
    
    if (normalizedKey.length == 64 && RegExp(r'^[a-fA-F0-9]+$').hasMatch(normalizedKey)) {
      // Derive address from private key
      final address = _deriveAddressFromPrivateKey(normalizedKey);
      setState(() {
        _derivedAddress = address;
        _error = null;
      });
    } else {
      setState(() {
        _derivedAddress = null;
      });
    }
  }

  String _deriveAddressFromPrivateKey(String hexKey) {
    // Use the crypto libraries to derive address
    final privateKeyBytes = Uint8List.fromList(hex.decode(hexKey));
    
    // Get secp256k1 curve
    final ecDomainParams = ECCurve_secp256k1();
    final privateKeyNum = bytesToUnsignedInt(privateKeyBytes);
    final publicKeyPoint = ecDomainParams.G * privateKeyNum;
    final pubKeyBytes = publicKeyPoint!.getEncoded(false);
    
    // Keccak256 hash of public key (without 0x04 prefix)
    final hashBytes = keccak256(Uint8List.fromList(pubKeyBytes.sublist(1)));
    
    // Take last 20 bytes and add 0x41 prefix for TRON
    final addressBytes = Uint8List.fromList([0x41, ...hashBytes.sublist(12)]);
    
    // Base58Check encode
    return Base58Encoder.checkEncode(addressBytes);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final rpc = _rpcController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    String address;
    String? normalizedKey;

    if (_createFromPrivateKey) {
      if (_derivedAddress == null) {
        setState(() => _error = 'Please enter a valid private key');
        return;
      }
      address = _derivedAddress!;
      
      // Get the normalized private key
      final key = _privateKeyController.text.trim();
      normalizedKey = key.startsWith('0x') ? key.substring(2) : key;
      
      // Validate password
      if (password.length < 6) {
        setState(() => _error = 'Password must be at least 6 characters');
        return;
      }
      if (password != confirmPassword) {
        setState(() => _error = 'Passwords do not match');
        return;
      }
    } else {
      address = _addressController.text.trim();
      if (address.isEmpty) {
        setState(() => _error = 'Please enter the multisig account address');
        return;
      }
      if (!address.startsWith('T') || address.length != 34) {
        setState(() => _error = 'Invalid TRON address (must start with T and be 34 characters)');
        return;
      }
    }

    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name');
      return;
    }
    if (rpc.isEmpty) {
      setState(() => _error = 'Please enter the RPC URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Save configuration
      final config = MultisigConfig(
        name: name,
        rpcUrl: rpc,
        multisigAddress: address,
        usdtAddress: null,
        isMainnet: _isMainnet,
      );
      await config.save();

      if (!mounted) return;
      final provider = context.read<MultisigProvider>();
      await provider.init(
        rpcUrl: rpc,
        multisigAddress: address,
        usdtAddress: null,
      );

      if (provider.accountInfo == null) {
        throw Exception('Account not found. Make sure the address has been activated on the network (needs some TRX).');
      }

      // Save encrypted key if using private key mode
      if (_createFromPrivateKey && normalizedKey != null) {
        await CryptoService.saveEncryptedKey(normalizedKey, password);
        await provider.connectWallet(normalizedKey);
      }

      if (!provider.isMultisigAccount) {
        // Warning but allow to continue
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This account is not yet configured as multisig. Go to "Manage Signers" to set it up.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rpcController.dispose();
    _addressController.dispose();
    _privateKeyController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ResponsiveContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  const Center(
                    child: Icon(
                      Icons.security,
                      size: 48,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'TRON Multisig',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Native account permissions multisig',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Network selector
                  const Text(
                    'Network',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _switchNetwork(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _isMainnet ? Colors.black : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isMainnet ? Colors.black : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Mainnet',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _isMainnet ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Production',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _isMainnet ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _switchNetwork(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: !_isMainnet ? Colors.black : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: !_isMainnet ? Colors.black : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Nile Testnet',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: !_isMainnet ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Testing',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: !_isMainnet ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'My Multisig',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'RPC URL',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rpcController,
                    decoration: const InputDecoration(
                      hintText: 'https://api.trongrid.io',
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Mode selector: Create from Private Key or Import Existing
                  const Text(
                    'Account Setup',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _createFromPrivateKey = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _createFromPrivateKey ? Colors.black : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _createFromPrivateKey ? Colors.black : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.key,
                                  size: 20,
                                  color: _createFromPrivateKey ? Colors.white : Colors.black54,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'From Private Key',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _createFromPrivateKey ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _createFromPrivateKey = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: !_createFromPrivateKey ? Colors.black : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: !_createFromPrivateKey ? Colors.black : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.link,
                                  size: 20,
                                  color: !_createFromPrivateKey ? Colors.white : Colors.black54,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Existing Address',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: !_createFromPrivateKey ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  if (_createFromPrivateKey) ...[
                    const Text(
                      'Private Key',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _privateKeyController,
                      obscureText: _obscureKey,
                      onChanged: _onPrivateKeyChanged,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '64-character hex key',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.black54,
                          ),
                          onPressed: () => setState(() => _obscureKey = !_obscureKey),
                        ),
                      ),
                    ),
                    if (_derivedAddress != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Derived Address',
                                    style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _derivedAddress!,
                                    style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.green.shade900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // Password field
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Create password (min 6 chars)',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.black54,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Confirm password field
                    const Text(
                      'Confirm Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Confirm password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.black54,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your private key will be encrypted with AES-256 and stored locally.',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ] else ...[
                    const Text(
                      'Multisig Account Address',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        hintText: 'T...',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enter an existing TRON address to use as your multisig account',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 20, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(fontSize: 14, color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Continue'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'How It Works',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _createFromPrivateKey
                              ? '1. Enter your private key to derive your TRON address\n'
                                '2. Make sure the account has some TRX (is activated)\n'
                                '3. Import your wallet and go to "Manage Signers"\n'
                                '4. Set up multisig by adding signers with weights'
                              : '1. Enter an existing TRON address\n'
                                '2. The account must be activated on the network\n'
                                '3. Import your signer key to manage the multisig',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Configuration storage for multisig settings
class MultisigConfig {
  final String name;
  final String rpcUrl;
  final String multisigAddress;
  final String? usdtAddress;
  final bool isMainnet;

  MultisigConfig({
    required this.name,
    required this.rpcUrl,
    required this.multisigAddress,
    this.usdtAddress,
    this.isMainnet = true,
  });

  static const _key = 'multisig_config';

  /// Network RPC URLs
  static const mainnetRpc = 'https://api.trongrid.io';
  static const nileRpc = 'https://nile.trongrid.io';

  static Future<MultisigConfig?> load() async {
    final data = await StorageService.getString(_key);
    if (data == null || data.isEmpty) return null;
    
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return MultisigConfig(
        name: json['name'] as String? ?? 'Multisig',
        rpcUrl: json['rpcUrl'] as String,
        multisigAddress: json['multisigAddress'] as String,
        usdtAddress: json['usdtAddress'] as String?,
        isMainnet: json['isMainnet'] as bool? ?? true,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> save() async {
    final data = jsonEncode({
      'name': name,
      'rpcUrl': rpcUrl,
      'multisigAddress': multisigAddress,
      'usdtAddress': usdtAddress,
      'isMainnet': isMainnet,
    });
    await StorageService.setString(_key, data);
  }

  /// Update just the network setting
  static Future<void> updateNetwork(bool isMainnet) async {
    final current = await load();
    if (current == null) return;
    
    final newRpc = isMainnet ? mainnetRpc : nileRpc;
    final updated = MultisigConfig(
      name: current.name,
      rpcUrl: newRpc,
      multisigAddress: current.multisigAddress,
      usdtAddress: current.usdtAddress,
      isMainnet: isMainnet,
    );
    await updated.save();
  }

  static Future<void> clear() async {
    await StorageService.remove(_key);
  }

  String get networkName => isMainnet ? 'Mainnet' : 'Nile Testnet';
}

/// A responsive container that constrains content width on larger screens
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 500,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );
  }
}
