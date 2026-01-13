# Multi-stage Dockerfile for USDT Multisig Project
# Builds: Foundry contracts, Flutter web app, and TRON utilities

# ============================================
# Stage 1: Build Rust TRON utilities
# ============================================
FROM rust:1.83-slim as tron-builder

WORKDIR /build

# Install dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy tron-utils source
COPY tron-utils ./tron-utils

# Build tron-utils
WORKDIR /build/tron-utils
RUN cargo build --release

# ============================================
# Stage 2: Build Solidity contracts with Foundry
# ============================================
FROM ghcr.io/foundry-rs/foundry:latest as foundry-builder

# Run as root to install dependencies
USER root

WORKDIR /build

# Copy contract source files
COPY foundry.toml .
COPY src ./src
COPY test ./test
COPY script ./script
COPY TRC20_USDT ./TRC20_USDT

# Install Foundry dependencies manually
RUN mkdir -p lib && \
    git clone --depth 1 https://github.com/foundry-rs/forge-std.git lib/forge-std && \
    git clone --depth 1 https://github.com/OpenZeppelin/openzeppelin-contracts.git lib/openzeppelin-contracts

# Build contracts
RUN forge build

# Build TRC20 contracts
RUN FOUNDRY_PROFILE=trc20 forge build

# ============================================
# Stage 3: Build Flutter Web App
# ============================================
FROM debian:bookworm-slim as flutter-builder

WORKDIR /build

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for Flutter
RUN useradd -m -s /bin/bash flutter && \
    mkdir -p /opt/flutter && \
    chown -R flutter:flutter /build /opt/flutter

# Install Flutter as non-root user (use stable channel for latest version)
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

USER flutter
RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git ${FLUTTER_HOME} && \
    flutter config --no-analytics && \
    flutter precache --web

# Copy app source and set permissions
USER root
COPY app ./app
RUN chown -R flutter:flutter /build/app

# Build Flutter web app
USER flutter
WORKDIR /build/app
RUN flutter pub get && \
    flutter build web --release

# ============================================
# Stage 4: Final runtime image
# ============================================
FROM ghcr.io/foundry-rs/foundry:latest

# Run as root to install packages
USER root

WORKDIR /app

# Install Node.js (for serving web app) and other utilities
# Foundry image is Debian-based, so use apt-get
RUN apt-get update && apt-get install -y \
    nodejs \
    npm \
    bash \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install http-server for serving Flutter web app
RUN npm install -g http-server

# Copy built artifacts from previous stages
COPY --from=tron-builder /build/tron-utils/target/release/tron-utils /usr/local/bin/
COPY --from=foundry-builder /build/out ./out
COPY --from=foundry-builder /build/out-trc20 ./out-trc20
COPY --from=flutter-builder /build/app/build/web ./web

# Copy source files needed for runtime
COPY foundry.toml .
COPY src ./src
COPY test ./test
COPY script ./script
COPY justfile .

# Environment variables
ENV FLUTTER_WEB_PORT=8080
ENV ANVIL_PORT=8545

# Expose ports
# 8080 - Flutter web app
# 8545 - Anvil (local Ethereum node)
EXPOSE 8080 8545

# Create entrypoint script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "🚀 USDT Multisig Docker Container"\n\
echo "=================================="\n\
echo ""\n\
echo "Available commands:"\n\
echo "  serve-web    - Serve Flutter web app on port 8080"\n\
echo "  anvil        - Start Anvil local Ethereum node"\n\
echo "  deploy       - Deploy contracts to local Anvil"\n\
echo "  shell        - Start interactive shell"\n\
echo "  help         - Show this help"\n\
echo ""\n\
\n\
case "$1" in\n\
  serve-web)\n\
    echo "🌐 Starting Flutter web app on http://localhost:${FLUTTER_WEB_PORT}"\n\
    exec http-server ./web -p ${FLUTTER_WEB_PORT} -c-1\n\
    ;;\n\
  anvil)\n\
    echo "⛏️  Starting Anvil local Ethereum node on port ${ANVIL_PORT}"\n\
    exec anvil --host 0.0.0.0\n\
    ;;\n\
  deploy)\n\
    echo "📦 Deploying contracts to Anvil..."\n\
    echo "Make sure Anvil is running first!"\n\
    echo ""\n\
    echo "Deploying TetherToken..."\n\
    USDT_OUTPUT=$(FOUNDRY_PROFILE=trc20 forge create TRC20_USDT/TetherToken.sol:TetherToken \\\n\
        --rpc-url http://host.docker.internal:8545 \\\n\
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \\\n\
        --constructor-args 1000000000000000 "Tether USD" "USDT" 6 2>&1)\n\
    \n\
    USDT_ADDRESS=$(echo "$USDT_OUTPUT" | grep "Deployed to:" | awk "{print \\$3}")\n\
    echo "✅ TetherToken deployed at: $USDT_ADDRESS"\n\
    echo ""\n\
    echo "Deploying Multisig..."\n\
    MULTISIG_OUTPUT=$(forge create src/Multisig.sol:USDTMultisig \\\n\
        --rpc-url http://host.docker.internal:8545 \\\n\
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \\\n\
        --constructor-args \\\n\
            "$USDT_ADDRESS" \\\n\
            "[0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,0x70997970C51812dc3A010C7d01b50e0d17dc79C8,0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,0x90F79bf6EB2c4f870365E785982E1f101E93b906,0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,0x976EA74026E726554dB657fA54763abd0C3a0aa9,0x14dC79964da2C08b23698B3D3cc7Ca32193d9955]" \\\n\
            2 2>&1)\n\
    \n\
    MULTISIG_ADDRESS=$(echo "$MULTISIG_OUTPUT" | grep "Deployed to:" | awk "{print \\$3}")\n\
    echo "✅ Multisig deployed at: $MULTISIG_ADDRESS"\n\
    echo ""\n\
    echo "🎉 Deployment complete!"\n\
    echo "USDT: $USDT_ADDRESS"\n\
    echo "Multisig: $MULTISIG_ADDRESS"\n\
    ;;\n\
  shell)\n\
    exec /bin/bash\n\
    ;;\n\
  help|--help|-h|"")\n\
    echo "Usage: docker run [OPTIONS] <image> [COMMAND]"\n\
    echo ""\n\
    echo "Commands:"\n\
    echo "  serve-web    Serve Flutter web app (default)"\n\
    echo "  anvil        Start local Ethereum node"\n\
    echo "  deploy       Deploy contracts"\n\
    echo "  shell        Interactive shell"\n\
    echo "  help         Show this help"\n\
    echo ""\n\
    echo "Examples:"\n\
    echo "  docker run -p 8080:8080 <image> serve-web"\n\
    echo "  docker run -p 8545:8545 <image> anvil"\n\
    echo "  docker run --network host <image> deploy"\n\
    ;;\n\
  *)\n\
    echo "❌ Unknown command: $1"\n\
    echo "Run with '\''help'\'' to see available commands"\n\
    exit 1\n\
    ;;\n\
esac\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["serve-web"]
