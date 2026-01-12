# USDT Multisig

A multi-signature wallet for USDT on EVM-compatible chains (Ethereum, TRON) with a Flutter cross-platform app.

## Prerequisites

Before you begin, install the following tools:

### 1. Foundry (Smart Contract Development)

Foundry is a blazing fast toolkit for Ethereum application development written in Rust.

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Foundry includes:
- **Forge** - Ethereum testing framework
- **Cast** - CLI for interacting with smart contracts
- **Anvil** - Local Ethereum node

📖 [Foundry Documentation](https://book.getfoundry.sh/)

### 2. Flutter (Mobile/Desktop App)

```bash
# macOS (Homebrew)
brew install flutter

# Or download from https://flutter.dev/docs/get-started/install
```

### 3. Rust & Cargo (TRON Utils)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### 4. Just (Command Runner)

```bash
# macOS
brew install just

# Or see https://github.com/casey/just#installation
```

## Quick Start

```bash
# List all available commands
just

# Run smart contract tests
just test

# Start local Ethereum node
just anvil

# Deploy contracts (in another terminal)
just deploy-all

# Run the Flutter app
just app-macos
```

## Smart Contract Commands

| Command | Description |
|---------|-------------|
| `just build` | Compile Solidity contracts |
| `just test` | Run all tests with `forge test` |
| `just test-gas` | Run tests with gas report |
| `just test-match <pattern>` | Run tests matching pattern |
| `just fmt` | Format Solidity code |
| `just clean` | Clean build artifacts |

### Local Development

```bash
# Terminal 1: Start local node
just anvil

# Terminal 2: Deploy contracts
just deploy-all

# Terminal 3: Run app
just app-macos
```

### Contract Interaction

```bash
just balance <contract>         # Get USDT balance
just owners <contract>          # List owners
just threshold <contract>       # Get threshold
just tx-count <contract>        # Get transaction count
just submit <contract> <to> <amount>  # Submit transaction
just approve <contract> <tx_id> [owner]  # Approve transaction
just execute <contract> <tx_id>  # Execute transaction
```

## Flutter App Commands

| Command | Description |
|---------|-------------|
| `just app-deps` | Install Flutter dependencies |
| `just app-macos` | Run on macOS |
| `just app-ios` | Run on iOS simulator |
| `just app-android` | Run on Android |
| `just app-web` | Run on Chrome (web) |
| `just build-macos` | Build macOS release |
| `just build-web` | Build web release |
| `just app-analyze` | Analyze Flutter code |
| `just app-fmt` | Format Dart code |
| `just app-clean` | Clean Flutter build |

### Multi-Instance Testing

Run multiple app instances with isolated storage for testing different owners:

```bash
just app1  # Owner 1 instance
just app2  # Owner 2 instance
just app3  # Owner 3 instance
# ... up to just app8
```

## TRON Deployment

```bash
# Build TRON utilities
just build-tron-utils

# Generate TRON wallet
just tron-generate-key

# Deploy to TRON Nile testnet
just deploy-all-tron

# Deploy to TRON mainnet
just tron-deploy-mainnet <private_key> <usdt> <owners> <threshold>
```

## Project Structure

```
multisig/
├── src/                    # Solidity contracts
│   └── Multisig.sol       # Main multisig contract
├── test/                   # Forge tests
│   └── Multisig.t.sol     # Contract tests
├── app/                    # Flutter application
├── tron-utils/            # Rust CLI for TRON deployment
├── TRC20_USDT/            # TRC20 USDT reference contracts
└── justfile               # All development commands
```

## License

MIT

---

## Auditor Notes

This section provides guidance for security auditors reviewing this project.

### 1. Smart Contract Audit (`src/Multisig.sol`)

**This is the primary component requiring security verification.**

#### Contract Overview

- **Purpose**: Multi-signature wallet for USDT transfers requiring N-of-M owner approvals
- **Lines of Code**: ~294 lines of Solidity
- **Compiler**: Solidity ^0.8.13
- **Dependencies**: OpenZeppelin contracts (audited, industry standard)

#### Security Checklist

| Area | What to Verify |
|------|----------------|
| **Access Control** | Only owners can submit/approve/revoke transactions |
| **Threshold Logic** | Threshold must be > 0 and ≤ owner count |
| **No Backdoors** | No admin functions to drain funds or bypass threshold |
| **No Privileged Roles** | All owners have equal rights, no super-admin |
| **Reentrancy** | Protected via OpenZeppelin `ReentrancyGuard` |
| **Integer Overflow** | Solidity 0.8.x has built-in overflow protection |
| **Fund Withdrawal** | Only via approved multisig transactions |

#### Key Security Properties to Verify

1. **No single owner can withdraw funds** - Requires `threshold` approvals
2. **No external party can withdraw funds** - Only owners can interact
3. **No hidden owner addition** - No functions to add/remove owners post-deployment
4. **Immutable USDT address** - Cannot be changed after deployment
5. **Balance verification** - Transfer success verified by balance change (handles legacy USDT quirks)

#### Attack Vectors to Test

- [ ] Can a non-owner submit/approve transactions?
- [ ] Can threshold be bypassed?
- [ ] Can the same owner approve twice?
- [ ] Can executed transactions be re-executed?
- [ ] Reentrancy during execution?
- [ ] Front-running attacks?
- [ ] Self-transfer edge cases?

#### External Dependencies

| Dependency | Source | Audit Status |
|------------|--------|--------------|
| `@openzeppelin/contracts/token/ERC20/IERC20.sol` | [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) | ✅ Audited multiple times |
| `@openzeppelin/contracts/utils/ReentrancyGuard.sol` | [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) | ✅ Audited multiple times |

OpenZeppelin contracts are the industry standard and have been audited by Trail of Bits, OpenZeppelin's internal team, and others. See: https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/audits

---

### 2. TRC20 USDT Reference (`TRC20_USDT/`)

**These contracts are NOT deployed by this project - they are reference copies.**

#### Purpose

The `TRC20_USDT/` folder contains an exact copy of the USDT TRC20 token deployed on TRON mainnet by Tether. This is used for:
- Local testing against realistic USDT behavior
- Understanding legacy Solidity 0.4.x behavior (no return value on `transfer()`)

#### Verification Required

| Check | Description |
|-------|-------------|
| ✅ **Source verification** | Compare against Tether's official deployed contract on TRON |
| ✅ **No modifications** | Verify no backdoors or changes were added |
| ⚠️ **Trust assumption** | We trust Tether's deployed contract as it holds billions in value |

#### Official TRON USDT Contract

- **Mainnet**: `TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t`
- **Source**: https://tronscan.org/#/contract/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t/code

**Action**: Diff the `TRC20_USDT/TetherToken.sol` against the official deployed source to verify no modifications.

---

### 3. Flutter App Dependencies

The mobile/desktop app uses these third-party packages. Auditors should verify:
- No malicious code in dependencies
- Secure cryptographic implementations
- No data exfiltration

#### Critical Dependencies (Crypto/Security)

| Package | Version | Purpose | Security Notes |
|---------|---------|---------|----------------|
| `web3dart` | ^2.7.3 | Ethereum/EVM interaction | ✅ [Open source](https://github.com/xclud/web3dart), 500+ GitHub stars, widely used |
| `cryptography` | ^2.7.0 | AES-GCM encryption | ✅ [Open source](https://github.com/nickvanderlinden/cryptography), modern Dart crypto library, authenticated encryption |
| `cryptography_flutter` | ^2.3.2 | Platform-optimized crypto | ✅ [Open source](https://pub.dev/packages/cryptography_flutter), uses native platform APIs (Apple CryptoKit, etc.) |
| `pointycastle` | ^3.9.1 | secp256k1 curve operations | ✅ [Dart port of BouncyCastle](https://github.com/bcgit/pc-dart), used for TRON address derivation |
| `blockchain_utils` | ^4.0.0 | Blockchain utilities | ✅ [Open source](https://github.com/nickvanderlinden/blockchain_utils), comprehensive library for Base58, addresses, key derivation |

**Cryptography Implementation Notes:**
- Uses **AES-256-GCM** (authenticated encryption) instead of AES-CBC
- GCM mode provides both confidentiality AND integrity verification (tamper detection)
- PBKDF2-HMAC-SHA256 with 100,000 iterations for key derivation
- `cryptography_flutter` leverages native platform crypto (Apple CryptoKit, Android Keystore) when available

#### Non-Critical Dependencies

| Package | Version | Purpose | Security Notes |
|---------|---------|---------|----------------|
| `http` | ^1.2.0 | HTTP client | ✅ Official Dart team package |
| `provider` | ^6.1.2 | State management | ✅ Flutter team recommended |
| `shared_preferences` | ^2.3.3 | Local storage | ✅ Official Flutter plugin |
| `intl` | ^0.19.0 | Internationalization | ✅ Official Dart team package |
| `convert` | ^3.1.1 | Encoding utilities | ✅ Official Dart team package |
| `cupertino_icons` | ^1.0.8 | iOS icons | ✅ Official Flutter package |

#### Dependency Verification Commands

```bash
# Check for known vulnerabilities (if using OSV scanner)
cd app && flutter pub outdated

# View dependency tree
cd app && flutter pub deps

# Audit package sources
# All packages can be inspected at https://pub.dev/packages/<package_name>
```

#### Key Security Considerations for App

1. **Private Key Storage**: How are private keys stored? (should use secure enclave/keychain)
2. **RPC Communication**: Is HTTPS enforced? Certificate pinning?
3. **Input Validation**: Are addresses and amounts validated before sending?
4. **No Telemetry**: Verify no analytics/tracking that could leak sensitive data

---

### 4. Test Coverage

Run the test suite to verify contract behavior:

```bash
# Run all tests with verbose output
just test

# Run with gas report
just test-gas

# View test file
cat test/Multisig.t.sol
```

Tests cover:
- Constructor validation
- Transaction submission
- Multi-owner approval flow
- Threshold enforcement
- Edge cases (zero amounts, duplicate approvals, etc.)

---

### 5. Audit Recommendations

1. **Smart Contract**: Focus on `src/Multisig.sol` - verify no fund extraction without threshold
2. **TRC20 Reference**: Diff against official Tether source - should be identical
3. **Flutter App**: Review key management and RPC security
4. **Dependencies**: All are open source and verifiable on pub.dev and GitHub

### Contact

For audit questions or to report vulnerabilities, please write in out commmon Signal group