# Docker Deployment Guide

This guide explains how to build and run the USDT Multisig project using Docker.

## Prerequisites

Install Docker on your system:

### Linux
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io docker-compose

# Arch Linux
sudo pacman -S docker docker-compose

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group (logout/login required)
sudo usermod -aG docker $USER
```

### macOS
```bash
# Install Docker Desktop
brew install --cask docker

# Or download from https://www.docker.com/products/docker-desktop
```

### Windows
Download and install Docker Desktop from https://www.docker.com/products/docker-desktop

## Build the Image

Build the Docker image (this may take 10-15 minutes on first build):

```bash
docker build -t usdt-multisig:latest .
```

The image includes:
- Foundry (forge, cast, anvil)
- Built Solidity contracts
- Flutter web app (production build)
- TRON utilities CLI
- All dependencies

## Usage

### 1. Serve Flutter Web App

Serve the Flutter web application on http://localhost:8080:

```bash
docker run -p 8080:8080 usdt-multisig:latest serve-web
```

Then open your browser to http://localhost:8080

### 2. Run Anvil (Local Ethereum Node)

Start a local Ethereum node for development:

```bash
docker run -p 8545:8545 usdt-multisig:latest anvil
```

The node will be available at http://localhost:8545

### 3. Deploy Contracts

Deploy contracts to a running Anvil instance:

```bash
# Make sure Anvil is running first
docker run --network host usdt-multisig:latest deploy
```

This will deploy:
- TetherToken (USDT)
- USDTMultisig contract with 8 owners

### 4. Interactive Shell

Access the container shell to run custom commands:

```bash
docker run -it usdt-multisig:latest shell
```

Inside the shell you can use:
- `forge` - Compile and test contracts
- `cast` - Interact with contracts
- `anvil` - Run local node
- `tron-utils` - TRON deployment utilities

## Docker Compose

For a complete development environment, use docker-compose:

```bash
# Start all services (Anvil + Web App)
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

This starts:
- Anvil on port 8545
- Flutter web app on port 8080

### Deploy Contracts with Docker Compose

After starting services:

```bash
docker-compose exec web /bin/bash -c "/entrypoint.sh deploy"
```

## Advanced Usage

### Build with Custom Flutter Version

Edit the Dockerfile and change the `FLUTTER_VERSION` variable:

```dockerfile
ENV FLUTTER_VERSION=3.24.0  # Change this
```

### Access Container Files

Copy files from the container:

```bash
# Copy built contracts
docker run --rm usdt-multisig:latest cat /app/out/Multisig.sol/USDTMultisig.json > USDTMultisig.json

# Copy web build
docker run --rm -v $(pwd)/web-output:/output usdt-multisig:latest sh -c "cp -r /app/web/* /output/"
```

### Network Configuration

By default, containers are isolated. To connect to host services:

```bash
# Use host network (Linux only)
docker run --network host usdt-multisig:latest

# Or use host.docker.internal (Mac/Windows)
# The contracts point to http://host.docker.internal:8545 for Anvil
```

### Custom Entrypoint

Override the entrypoint to run custom commands:

```bash
docker run -it --entrypoint /bin/bash usdt-multisig:latest

# Then inside:
forge test
cast --version
tron-utils --help
```

## Image Details

### Image Size
- Approximate size: 3-4 GB (includes all build tools and runtimes)

### Included Tools
- Foundry (forge, cast, anvil, chisel)
- Node.js and npm
- http-server (for serving web app)
- tron-utils CLI
- All built artifacts (contracts, web app)

### Environment Variables

Available environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `FLUTTER_WEB_PORT` | 8080 | Port for Flutter web app |
| `ANVIL_PORT` | 8545 | Port for Anvil node |

Set them with `docker run`:

```bash
docker run -p 9000:9000 -e FLUTTER_WEB_PORT=9000 usdt-multisig:latest serve-web
```

## Troubleshooting

### Build Fails - Out of Memory

If the build fails with memory errors, increase Docker's memory limit:
- Docker Desktop: Preferences → Resources → Memory (increase to 8GB+)

### Port Already in Use

If port 8545 or 8080 is in use:

```bash
# Use different ports
docker run -p 8546:8545 usdt-multisig:latest anvil
docker run -p 8081:8080 usdt-multisig:latest serve-web
```

### Container Exits Immediately

Check logs:

```bash
docker logs <container_id>
```

### Cannot Connect to Anvil from Deploy

Make sure you're using the correct network:

```bash
# Linux: use --network host
docker run --network host usdt-multisig:latest deploy

# Mac/Windows: make sure Anvil is accessible
# The deploy script uses host.docker.internal:8545
```

## Production Deployment

For production, you'll want to:

1. Use a multi-stage build to reduce image size (already implemented)
2. Deploy only the web app (not development tools)
3. Use a proper reverse proxy (nginx, traefik)
4. Configure HTTPS/TLS certificates

Example production setup:

```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  web:
    image: usdt-multisig:latest
    command: serve-web
    restart: always
    environment:
      - FLUTTER_WEB_PORT=8080
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.multisig.rule=Host(`multisig.example.com`)"
      - "traefik.http.routers.multisig.tls=true"
      - "traefik.http.routers.multisig.tls.certresolver=letsencrypt"
```

## Next Steps

1. Build the image: `docker build -t usdt-multisig:latest .`
2. Start Anvil: `docker run -p 8545:8545 usdt-multisig:latest anvil`
3. Deploy contracts: `docker run --network host usdt-multisig:latest deploy`
4. Run web app: `docker run -p 8080:8080 usdt-multisig:latest serve-web`
5. Open http://localhost:8080 in your browser

Or use docker-compose for a one-command setup:

```bash
docker-compose up -d
docker-compose exec web /entrypoint.sh deploy
```

## Support

For issues or questions, please refer to the main README.md or open an issue in the project repository.
