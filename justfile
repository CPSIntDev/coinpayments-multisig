# USDT Multisig - Development Commands
# =====================================

# Default recipe - show help
default:
    @just --list

# =====================================
# Solidity Contract Commands
# =====================================

# Build/compile Solidity contracts
build:
    @echo "🔨 Building contracts..."
    forge build

# Run all Solidity tests
test:
    @echo "🧪 Running tests..."
    forge test -vvv

# Run tests with gas report
test-gas:
    @echo "🧪 Running tests with gas report..."
    forge test -vvv --gas-report

# Run specific test
test-match pattern:
    @echo "🧪 Running tests matching '{{pattern}}'..."
    forge test -vvv --match-test {{pattern}}

# Format Solidity code
fmt:
    @echo "✨ Formatting Solidity code..."
    forge fmt

# Check formatting
fmt-check:
    @echo "🔍 Checking Solidity formatting..."
    forge fmt --check

# Clean build artifacts
clean:
    @echo "🧹 Cleaning build artifacts..."
    forge clean
    rm -rf out cache

# =====================================
# Anvil Local Network
# =====================================

# Start Anvil local Ethereum node
anvil:
    @echo "⛏️  Starting Anvil local node..."
    @echo "Default accounts will be created with 10000 ETH each"
    @echo ""
    anvil

# Start Anvil with specific chain ID
anvil-chain chain_id="31337":
    @echo "⛏️  Starting Anvil with chain ID {{chain_id}}..."
    anvil --chain-id {{chain_id}}

# =====================================
# Contract Deployment
# =====================================

# Build TRC20 USDT contracts (legacy Solidity 0.4.x)
build-trc20:
    @echo "🔨 Building TRC20 USDT contracts (Solidity 0.4.x)..."
    FOUNDRY_PROFILE=trc20 forge build

# Deploy TetherToken (real TRC20 USDT) to Anvil
# Constructor: TetherToken(uint _initialSupply, string _name, string _symbol, uint8 _decimals)
deploy-tether:
    @echo "🚀 Deploying TetherToken to Anvil..."
    @echo "Initial Supply: 1,000,000,000 USDT (1B)"
    FOUNDRY_PROFILE=trc20 forge create TRC20_USDT/TetherToken.sol:TetherToken \
        --rpc-url http://localhost:8545 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
        --constructor-args 1000000000000000 "Tether USD" "USDT" 6

# Deploy USDTMultisig to Anvil with default test config
# Uses first 3 Anvil accounts as owners, threshold=2
deploy-multisig usdt_address:
    @echo "🚀 Deploying USDTMultisig to Anvil..."
    @echo "USDT Address: {{usdt_address}}"
    @echo "Owners: First 3 Anvil accounts"
    @echo "Threshold: 2"
    forge create src/Multisig.sol:USDTMultisig \
        --rpc-url http://localhost:8545 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
        --constructor-args \
            {{usdt_address}} \
            "[0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,0x70997970C51812dc3A010C7d01b50e0d17dc79C8,0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC]" \
            2

# Deploy everything to Anvil (TetherToken + Multisig)
# 8 owners, threshold of 2
deploy-all:
    #!/usr/bin/env bash
    set -e
    echo "🚀 Deploying all contracts to Anvil..."
    echo "   8 owners, threshold 2"
    echo ""
    
    # Deploy TetherToken (real TRC20 USDT)
    echo "📝 Step 1: Deploying TetherToken (TRC20 USDT)..."
    USDT_OUTPUT=$(FOUNDRY_PROFILE=trc20 forge create TRC20_USDT/TetherToken.sol:TetherToken \
        --rpc-url http://localhost:8545 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
        --constructor-args 1000000000000000 "Tether USD" "USDT" 6 2>&1)
    
    USDT_ADDRESS=$(echo "$USDT_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
    echo "✅ TetherToken deployed at: $USDT_ADDRESS"
    echo ""
    
    # Deploy Multisig with 8 owners
    echo "📝 Step 2: Deploying USDTMultisig (8 owners, threshold 2)..."
    MULTISIG_OUTPUT=$(forge create src/Multisig.sol:USDTMultisig \
        --rpc-url http://localhost:8545 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
        --constructor-args \
            "$USDT_ADDRESS" \
            "[0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,0x70997970C51812dc3A010C7d01b50e0d17dc79C8,0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,0x90F79bf6EB2c4f870365E785982E1f101E93b906,0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,0x976EA74026E726554dB657fA54763abd0C3a0aa9,0x14dC79964da2C08b23698B3D3cc7Ca32193d9955]" \
            2 2>&1)
    
    MULTISIG_ADDRESS=$(echo "$MULTISIG_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
    echo "✅ USDTMultisig deployed at: $MULTISIG_ADDRESS"
    echo ""
    
    # Transfer USDT from owner to multisig (TetherToken owner is deployer)
    echo "📝 Step 3: Transferring 1,000,000 USDT to Multisig..."
    cast send $USDT_ADDRESS "transfer(address,uint256)" $MULTISIG_ADDRESS 1000000000000 \
        --rpc-url http://localhost:8545 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    echo "✅ Transferred 1,000,000 USDT to Multisig"
    echo ""
    
    echo "=========================================="
    echo "🎉 Deployment Complete!"
    echo "=========================================="
    echo ""
    echo "TetherToken (USDT): $USDT_ADDRESS"
    echo "Multisig:           $MULTISIG_ADDRESS"
    echo ""
    echo "Owners (8 Anvil default accounts):"
    echo "  Owner 1: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    echo "  Owner 2: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
    echo "  Owner 3: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
    echo "  Owner 4: 0x90F79bf6EB2c4f870365E785982E1f101E93b906"
    echo "  Owner 5: 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"
    echo "  Owner 6: 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc"
    echo "  Owner 7: 0x976EA74026E726554dB657fA54763abd0C3a0aa9"
    echo "  Owner 8: 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955"
    echo ""
    echo "Private Keys (for testing only!):"
    echo "  Owner 1: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    echo "  Owner 2: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
    echo "  Owner 3: 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
    echo "  Owner 4: 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
    echo "  Owner 5: 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a"
    echo "  Owner 6: 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba"
    echo "  Owner 7: 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e"
    echo "  Owner 8: 0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356"
    echo ""
    echo "Threshold: 2 of 8"
    echo ""
    echo "To use with Flutter app:"
    echo "  RPC URL:          http://localhost:8545"
    echo "  Contract Address: $MULTISIG_ADDRESS"

# =====================================
# Contract Interaction (via cast)
# =====================================

# Get multisig balance
balance contract:
    @echo "💰 Getting USDT balance..."
    cast call {{contract}} "getBalance()(uint256)" --rpc-url http://localhost:8545

# Get owners
owners contract:
    @echo "👥 Getting owners..."
    cast call {{contract}} "getOwners()(address[])" --rpc-url http://localhost:8545

# Get threshold
threshold contract:
    @echo "🔐 Getting threshold..."
    cast call {{contract}} "threshold()(uint256)" --rpc-url http://localhost:8545

# Get transaction count
tx-count contract:
    @echo "📊 Getting transaction count..."
    cast call {{contract}} "getTransactionCount()(uint256)" --rpc-url http://localhost:8545

# Get transaction details
tx-details contract tx_id:
    @echo "📋 Getting transaction #{{tx_id}} details..."
    cast call {{contract}} "getTransaction(uint256)(address,uint256,bool,uint256)" {{tx_id}} --rpc-url http://localhost:8545

# Submit a transaction (from owner 1)
submit contract to amount:
    @echo "📤 Submitting transaction..."
    @echo "To: {{to}}"
    @echo "Amount: {{amount}}"
    cast send {{contract}} "submitTransaction(address,uint256)" {{to}} {{amount}} \
        --rpc-url http://localhost:8545 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Approve transaction (specify which owner: 1-8)
approve contract tx_id owner="1":
    #!/usr/bin/env bash
    echo "✅ Approving transaction #{{tx_id}} as owner {{owner}}..."
    case {{owner}} in
        1) KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" ;;
        2) KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" ;;
        3) KEY="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" ;;
        4) KEY="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6" ;;
        5) KEY="0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a" ;;
        6) KEY="0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba" ;;
        7) KEY="0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e" ;;
        8) KEY="0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356" ;;
        *) echo "Invalid owner. Use 1-8"; exit 1 ;;
    esac
    cast send {{contract}} "approveTransaction(uint256)" {{tx_id}} \
        --rpc-url http://localhost:8545 \
        --private-key $KEY

# Execute transaction (from owner 1)
execute contract tx_id:
    @echo "🚀 Executing transaction #{{tx_id}}..."
    cast send {{contract}} "executeTransaction(uint256)" {{tx_id}} \
        --rpc-url http://localhost:8545 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# =====================================
# Flutter App Commands
# =====================================

# Install Flutter dependencies
app-deps:
    @echo "📦 Installing Flutter dependencies..."
    cd app && flutter pub get

# Run Flutter app on macOS (with optional instance number for isolated storage)
# Usage: just app-macos [instance]
# Examples:
#   just app-macos       - Run default instance
#   just app-macos 2     - Run instance 2 (separate storage)
#   just app-macos 3     - Run instance 3 (separate storage)
app-macos instance="":
    #!/usr/bin/env bash
    if [ -z "{{instance}}" ]; then
        echo "🍎 Running Flutter app on macOS (default instance)..."
        cd app && flutter run -d macos
    else
        echo "🍎 Running Flutter app on macOS (instance #{{instance}})..."
        echo "📦 Storage isolated with prefix: {{instance}}_"
        cd app && flutter run -d macos --dart-define=INSTANCE={{instance}}
    fi

# Run Flutter app on Chrome (web)
app-web:
    @echo "🌐 Running Flutter app on Chrome..."
    cd app && flutter run -d chrome

# Run Flutter app on iOS simulator
app-ios:
    @echo "📱 Running Flutter app on iOS..."
    cd app && flutter run -d ios

# Run Flutter app on Android
app-android:
    @echo "🤖 Running Flutter app on Android..."
    cd app && flutter run -d android

# Build macOS app
build-macos:
    @echo "🔨 Building macOS app..."
    cd app && flutter build macos

# Build web app
build-web:
    @echo "🔨 Building web app..."
    cd app && flutter build web

# Analyze Flutter code
app-analyze:
    @echo "🔍 Analyzing Flutter code..."
    cd app && flutter analyze

# Format Flutter code
app-fmt:
    @echo "✨ Formatting Flutter code..."
    cd app && dart format lib/

# Clean Flutter build
app-clean:
    @echo "🧹 Cleaning Flutter build..."
    cd app && flutter clean

# =====================================
# Full Development Workflow
# =====================================

# Full test cycle: format, build, test
check: fmt build test
    @echo "✅ All checks passed!"

# Start development environment (anvil + deploy + app)
dev:
    @echo "🚀 Starting development environment..."
    @echo ""
    @echo "This will:"
    @echo "  1. Start Anvil in background"
    @echo "  2. Deploy contracts"
    @echo "  3. Run Flutter app"
    @echo ""
    @echo "Press Ctrl+C to stop"
    @echo ""
    @echo "⚠️  Run 'just anvil' in a separate terminal first!"
    @echo "Then run 'just deploy-all' to deploy contracts"
    @echo "Finally run 'just app-macos' to start the app"

# Show test account info
accounts:
    @echo "📋 Anvil Default Test Accounts (8 Owners)"
    @echo "=========================================="
    @echo ""
    @echo "Account #0 (Owner 1):"
    @echo "  Address:     0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    @echo "  Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    @echo ""
    @echo "Account #1 (Owner 2):"
    @echo "  Address:     0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
    @echo "  Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
    @echo ""
    @echo "Account #2 (Owner 3):"
    @echo "  Address:     0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
    @echo "  Private Key: 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
    @echo ""
    @echo "Account #3 (Owner 4):"
    @echo "  Address:     0x90F79bf6EB2c4f870365E785982E1f101E93b906"
    @echo "  Private Key: 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
    @echo ""
    @echo "Account #4 (Owner 5):"
    @echo "  Address:     0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"
    @echo "  Private Key: 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a"
    @echo ""
    @echo "Account #5 (Owner 6):"
    @echo "  Address:     0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc"
    @echo "  Private Key: 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba"
    @echo ""
    @echo "Account #6 (Owner 7):"
    @echo "  Address:     0x976EA74026E726554dB657fA54763abd0C3a0aa9"
    @echo "  Private Key: 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e"
    @echo ""
    @echo "Account #7 (Owner 8):"
    @echo "  Address:     0x14dC79964da2C08b23698B3D3cc7Ca32193d9955"
    @echo "  Private Key: 0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356"
    @echo ""
    @echo "Account #8 (Recipient for testing):"
    @echo "  Address:     0xa0Ee7A142d267C1f36714E4a8F75612F20a79720"
    @echo "  Private Key: 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6"

# =====================================
# Wallet / Key Management
# =====================================

# Generate a new random private key and address
generate-key:
    @echo "🔑 Generating new wallet..."
    @cast wallet new

# Generate multiple wallets
generate-keys count="3":
    @echo "🔑 Generating {{count}} new wallets..."
    @for i in $(seq 1 {{count}}); do \
        echo ""; \
        echo "Wallet #$$i:"; \
        cast wallet new; \
    done

# Get address from private key
address-from-key key:
    @echo "📍 Getting address from private key..."
    @cast wallet address --private-key {{key}}

# Verify a private key matches an address
verify-key key address:
    #!/usr/bin/env bash
    DERIVED=$(cast wallet address --private-key {{key}} 2>/dev/null)
    if [ "$DERIVED" = "{{address}}" ]; then
        echo "✅ Private key matches address {{address}}"
    else
        echo "❌ Mismatch!"
        echo "   Expected: {{address}}"
        echo "   Got:      $DERIVED"
    fi

# Check if address is owner in multisig contract
is-owner contract address:
    @echo "🔍 Checking if {{address}} is owner..."
    @cast call {{contract}} "isOwner(address)(bool)" {{address}} --rpc-url http://localhost:8545

# =====================================
# Aliases for multi-instance testing
# =====================================

# Run owner 1 instance (Account #0)
app1:
    @just app-macos 1

# Run owner 2 instance (Account #1)
app2:
    @just app-macos 2

# Run owner 3 instance (Account #2)
app3:
    @just app-macos 3

# Run owner 4 instance (Account #3)
app4:
    @just app-macos 4

# Run owner 5 instance (Account #4)
app5:
    @just app-macos 5

# Run owner 6 instance (Account #5)
app6:
    @just app-macos 6

# Run owner 7 instance (Account #6)
app7:
    @just app-macos 7

# Run owner 8 instance (Account #7)
app8:
    @just app-macos 8

# =====================================
# TRON Deployment Commands
# =====================================

# Build TRON utils CLI
build-tron-utils:
    @echo "🔨 Building tron-utils..."
    cd tron-utils && cargo build --release
    @echo "✅ Built: tron-utils/target/release/tron-utils"

# Generate a new TRON private key and address
tron-generate-key:
    @cd tron-utils && cargo run --release -- generate-key

# Generate a new TRON private key and address (JSON output)
tron-generate-key-json:
    @cd tron-utils && cargo run --release --quiet -- generate-key --json

# Get TRON address from private key
tron-address key:
    @cd tron-utils && cargo run --release -- address --private-key {{key}}

# Convert hex to TRON base58 address
tron-to-base58 hex:
    @cd tron-utils && cargo run --release -- to-base58 --hex {{hex}}

# Convert TRON base58 to hex address
tron-to-hex address:
    @cd tron-utils && cargo run --release -- to-hex --address {{address}}

# Deploy multisig contract to TRON
# Usage: just tron-deploy <rpc_url> <private_key> <usdt_address> <owner1,owner2,...> <threshold>
tron-deploy rpc_url private_key usdt owners threshold:
    @echo "🚀 Deploying USDTMultisig to TRON..."
    cd tron-utils && cargo run --release -- deploy \
        --rpc-url {{rpc_url}} \
        --private-key {{private_key}} \
        --usdt {{usdt}} \
        --owners {{owners}} \
        --threshold {{threshold}} \
        --contract-json ../out/Multisig.sol/USDTMultisig.json

# Deploy to TRON Shasta testnet (example)
# Replace with your actual values
tron-deploy-shasta private_key usdt owners threshold:
    @just tron-deploy "https://api.shasta.trongrid.io" {{private_key}} {{usdt}} {{owners}} {{threshold}}

# Deploy to TRON mainnet
tron-deploy-mainnet private_key usdt owners threshold:
    @just tron-deploy "https://api.trongrid.io" {{private_key}} {{usdt}} {{owners}} {{threshold}}

# Deploy all contracts to TRON Nile testnet
# Uses pre-funded account: TLu74WiSAfdwCnawzF6EEXPYkgjSWDbK5b
# Default USDT: TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf (Nile testnet)
deploy-all-tron usdt_address="TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf" private_key="" rpc="":
    #!/usr/bin/env bash
    set -e
    echo "🚀 Deploying USDTMultisig to TRON..."
    echo "   8 owners, threshold 2"
    echo ""
    
    # Use provided private key or default (Nile testnet pre-funded account)
    if [ -n "{{private_key}}" ]; then
        DEPLOYER_KEY="{{private_key}}"
        # Derive address from private key
        DEPLOYER_JSON=$(cd tron-utils && cargo run --release --quiet -- derive-address --private-key "$DEPLOYER_KEY" --json 2>/dev/null || echo '{"address":"unknown"}')
        DEPLOYER_ADDR=$(echo "$DEPLOYER_JSON" | grep -o '"address"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        if [ -z "$DEPLOYER_ADDR" ] || [ "$DEPLOYER_ADDR" = "unknown" ]; then
            DEPLOYER_ADDR="(derived from provided key)"
        fi
    else
        DEPLOYER_KEY="c88c165be5e6d8c58eca95747f8811aa956fa6227c9e0276543bc30d49252d76"
        DEPLOYER_ADDR="TLu74WiSAfdwCnawzF6EEXPYkgjSWDbK5b"
    fi
    
    # Use provided RPC or default (Nile testnet)
    if [ -n "{{rpc}}" ]; then
        RPC_URL="{{rpc}}"
    else
        RPC_URL="https://nile.trongrid.io"
    fi
    
    USDT_ADDRESS="{{usdt_address}}"
    
    echo "📋 Configuration:"
    echo "   RPC:      $RPC_URL"
    echo "   Deployer: $DEPLOYER_ADDR"
    echo "   USDT:     $USDT_ADDRESS"
    echo ""
    
    # Generate 8 owner keys
    echo "🔑 Generating 8 owner wallets..."
    
    OWNER1_JSON=$(cd tron-utils && cargo run --release --quiet -- generate-key --json)
    OWNER1_KEY=$(echo "$OWNER1_JSON" | grep privateKey | cut -d'"' -f4)
    OWNER1_ADDR=$(echo "$OWNER1_JSON" | grep address | cut -d'"' -f4)
    echo "   Owner 1: $OWNER1_ADDR"
    
    OWNER2_JSON=$(cd tron-utils && cargo run --release --quiet -- generate-key --json)
    OWNER2_KEY=$(echo "$OWNER2_JSON" | grep privateKey | cut -d'"' -f4)
    OWNER2_ADDR=$(echo "$OWNER2_JSON" | grep address | cut -d'"' -f4)
    echo "   Owner 2: $OWNER2_ADDR"
    
    OWNER3_JSON=$(cd tron-utils && cargo run --release --quiet -- generate-key --json)
    OWNER3_KEY=$(echo "$OWNER3_JSON" | grep privateKey | cut -d'"' -f4)
    OWNER3_ADDR=$(echo "$OWNER3_JSON" | grep address | cut -d'"' -f4)
    echo "   Owner 3: $OWNER3_ADDR"
    
    OWNER4_JSON=$(cd tron-utils && cargo run --release --quiet -- generate-key --json)
    OWNER4_KEY=$(echo "$OWNER4_JSON" | grep privateKey | cut -d'"' -f4)
    OWNER4_ADDR=$(echo "$OWNER4_JSON" | grep address | cut -d'"' -f4)
    echo "   Owner 4: $OWNER4_ADDR"
    
    OWNER5_JSON=$(cd tron-utils && cargo run --release --quiet -- generate-key --json)
    OWNER5_KEY=$(echo "$OWNER5_JSON" | grep privateKey | cut -d'"' -f4)
    OWNER5_ADDR=$(echo "$OWNER5_JSON" | grep address | cut -d'"' -f4)
    echo "   Owner 5: $OWNER5_ADDR"
    
    OWNER6_JSON=$(cd tron-utils && cargo run --release --quiet -- generate-key --json)
    OWNER6_KEY=$(echo "$OWNER6_JSON" | grep privateKey | cut -d'"' -f4)
    OWNER6_ADDR=$(echo "$OWNER6_JSON" | grep address | cut -d'"' -f4)
    echo "   Owner 6: $OWNER6_ADDR"
    
    OWNER7_JSON=$(cd tron-utils && cargo run --release --quiet -- generate-key --json)
    OWNER7_KEY=$(echo "$OWNER7_JSON" | grep privateKey | cut -d'"' -f4)
    OWNER7_ADDR=$(echo "$OWNER7_JSON" | grep address | cut -d'"' -f4)
    echo "   Owner 7: $OWNER7_ADDR"
    
    OWNER8_JSON=$(cd tron-utils && cargo run --release --quiet -- generate-key --json)
    OWNER8_KEY=$(echo "$OWNER8_JSON" | grep privateKey | cut -d'"' -f4)
    OWNER8_ADDR=$(echo "$OWNER8_JSON" | grep address | cut -d'"' -f4)
    echo "   Owner 8: $OWNER8_ADDR"
    echo ""
    
    # Build contract first
    echo "📦 Building contract..."
    forge build
    echo ""
    
    # Deploy multisig with 8 owners, threshold 2
    echo "📝 Deploying USDTMultisig (8 owners, threshold 2)..."
    cd tron-utils && cargo run --release -- deploy \
        --rpc-url "$RPC_URL" \
        --private-key "$DEPLOYER_KEY" \
        --usdt "$USDT_ADDRESS" \
        --owners "$OWNER1_ADDR,$OWNER2_ADDR,$OWNER3_ADDR,$OWNER4_ADDR,$OWNER5_ADDR,$OWNER6_ADDR,$OWNER7_ADDR,$OWNER8_ADDR" \
        --threshold 2 \
        --contract-json ../out/Multisig.sol/USDTMultisig.json
    
    echo ""
    echo "=========================================="
    echo "🎉 Deployment Complete!"
    echo "=========================================="
    echo ""
    echo "Network: TRON Nile Testnet"
    echo "USDT:    $USDT_ADDRESS"
    echo ""
    echo "Owners (8 generated wallets):"
    echo "  Owner 1: $OWNER1_ADDR"
    echo "    Key:   $OWNER1_KEY"
    echo ""
    echo "  Owner 2: $OWNER2_ADDR"
    echo "    Key:   $OWNER2_KEY"
    echo ""
    echo "  Owner 3: $OWNER3_ADDR"
    echo "    Key:   $OWNER3_KEY"
    echo ""
    echo "  Owner 4: $OWNER4_ADDR"
    echo "    Key:   $OWNER4_KEY"
    echo ""
    echo "  Owner 5: $OWNER5_ADDR"
    echo "    Key:   $OWNER5_KEY"
    echo ""
    echo "  Owner 6: $OWNER6_ADDR"
    echo "    Key:   $OWNER6_KEY"
    echo ""
    echo "  Owner 7: $OWNER7_ADDR"
    echo "    Key:   $OWNER7_KEY"
    echo ""
    echo "  Owner 8: $OWNER8_ADDR"
    echo "    Key:   $OWNER8_KEY"
    echo ""
    echo "Threshold: 2 of 8"
    echo ""
    echo "⚠️  Save these private keys securely!"
    echo "💡 Get test TRX from: https://nileex.io/join/getJoinPage"

# Quick deploy to Nile with deployer as single owner (for testing)
# Default USDT: TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf (Nile testnet)
deploy-test-tron usdt_address="TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf":
    #!/usr/bin/env bash
    set -e
    echo "🚀 Quick test deployment to TRON Nile..."
    
    DEPLOYER_KEY="c88c165be5e6d8c58eca95747f8811aa956fa6227c9e0276543bc30d49252d76"
    DEPLOYER_ADDR="TLu74WiSAfdwCnawzF6EEXPYkgjSWDbK5b"
    
    # Build contract
    forge build
    
    # Deploy with single owner
    cd tron-utils && cargo run --release -- deploy \
        --rpc-url "https://nile.trongrid.io" \
        --private-key "$DEPLOYER_KEY" \
        --usdt "{{usdt_address}}" \
        --owners "$DEPLOYER_ADDR" \
        --threshold 1 \
        --contract-json ../out/Multisig.sol/USDTMultisig.json
    
    echo ""
    echo "Owner: $DEPLOYER_ADDR (threshold 1)"

# Verify/publish contract source code on Tronscan
# contract_address: The deployed contract address (TRON base58 format)
# usdt_address: The USDT token address used in constructor
# owners: Comma-separated owner addresses used in constructor
# threshold: The threshold value used in constructor
# network: "nile" for testnet or "mainnet" for mainnet
verify-tron contract_address usdt_address owners threshold network="nile":
    #!/usr/bin/env bash
    set -e
    
    CONTRACT_ADDRESS="{{contract_address}}"
    USDT_ADDRESS="{{usdt_address}}"
    OWNERS="{{owners}}"
    THRESHOLD="{{threshold}}"
    NETWORK="{{network}}"
    
    echo "🔍 Verifying USDTMultisig contract on Tronscan..."
    echo ""
    echo "📋 Configuration:"
    echo "   Contract:  $CONTRACT_ADDRESS"
    echo "   Network:   $NETWORK"
    echo "   USDT:      $USDT_ADDRESS"
    echo "   Owners:    $OWNERS"
    echo "   Threshold: $THRESHOLD"
    echo ""
    
    # Set API URL based on network
    if [ "$NETWORK" = "mainnet" ]; then
        API_URL="https://apilist.tronscanapi.com/api/solidity/contract/verify"
        TRONSCAN_URL="https://tronscan.org/#/contract/$CONTRACT_ADDRESS/code"
    else
        API_URL="https://nileapi.tronscan.org/api/solidity/contract/verify"
        TRONSCAN_URL="https://nile.tronscan.org/#/contract/$CONTRACT_ADDRESS/code"
    fi
    
    # Flatten the contract source
    echo "📦 Flattening contract source..."
    FLATTENED_SOURCE=$(forge flatten src/Multisig.sol)
    
    # Convert addresses from base58 to hex for ABI encoding
    echo "🔧 Encoding constructor arguments..."
    USDT_HEX=$(cd tron-utils && cargo run --release --quiet -- to-hex --address "$USDT_ADDRESS" 2>/dev/null | tr -d '[:space:]')
    
    # Convert owner addresses to hex array
    OWNERS_HEX=""
    IFS=',' read -ra OWNER_ARRAY <<< "$OWNERS"
    for owner in "${OWNER_ARRAY[@]}"; do
        owner_hex=$(cd tron-utils && cargo run --release --quiet -- to-hex --address "$owner" 2>/dev/null | tr -d '[:space:]')
        if [ -n "$OWNERS_HEX" ]; then
            OWNERS_HEX="$OWNERS_HEX,$owner_hex"
        else
            OWNERS_HEX="$owner_hex"
        fi
    done
    
    # Get compiler version from foundry.toml
    SOLC_VERSION="v0.8.28"
    
    # Create JSON payload for verification
    echo "📤 Submitting verification request..."
    
    # Build JSON payload using jq to handle escaping properly
    JSON_PAYLOAD=$(jq -n \
        --arg addr "$CONTRACT_ADDRESS" \
        --arg name "USDTMultisig" \
        --arg compiler "$SOLC_VERSION" \
        --arg source "$FLATTENED_SOURCE" \
        --arg license "MIT" \
        '{
            address: $addr,
            contractName: $name,
            compilerVersion: $compiler,
            optimization: false,
            optimizationRuns: 200,
            sourceCode: $source,
            licenseType: $license
        }')
    
    # Create the verification request
    RESPONSE=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD")
    
    echo ""
    echo "📋 Response from Tronscan:"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    echo ""
    echo "🔗 View contract on Tronscan:"
    echo "   $TRONSCAN_URL"
    echo ""
    echo "💡 If automatic verification fails, you can verify manually:"
    echo "   1. Go to: $TRONSCAN_URL"
    echo "   2. Click 'Verify & Publish'"
    echo "   3. Use these settings:"
    echo "      - Contract Name: USDTMultisig"
    echo "      - Compiler: $SOLC_VERSION"
    echo "      - Optimization: No"
    echo "      - License: MIT"
    echo "   4. Paste the flattened source (run: forge flatten src/Multisig.sol)"

# Generate flattened source code for manual Tronscan verification
flatten-tron:
    #!/usr/bin/env bash
    echo "📦 Generating flattened source code for USDTMultisig..."
    echo ""
    forge flatten src/Multisig.sol
    echo ""
    echo "💡 Copy the above source code for Tronscan verification"

# Export flattened Multisig.sol to a file
flatten-multisig output="Multisig.flat.sol":
    #!/usr/bin/env bash
    echo "📦 Flattening Multisig.sol to {{output}}..."
    forge flatten src/Multisig.sol > "{{output}}"
    echo "✅ Saved to {{output}}"