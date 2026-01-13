# Makefile for USDT Multisig Docker operations
.PHONY: help build up down logs shell deploy clean web anvil

# Use DOCKER variable to support both docker and podman
DOCKER ?= $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null)
DOCKER_COMPOSE ?= $(shell command -v podman-compose 2>/dev/null || command -v docker-compose 2>/dev/null)

# Default target
help:
	@echo "USDT Multisig - Docker Commands"
	@echo "================================"
	@echo ""
	@echo "Building:"
	@echo "  make build          Build Docker image"
	@echo ""
	@echo "Docker Compose:"
	@echo "  make up             Start all services (Anvil + Web)"
	@echo "  make down           Stop all services"
	@echo "  make logs           View logs"
	@echo "  make deploy         Deploy contracts to Anvil"
	@echo ""
	@echo "Individual Services:"
	@echo "  make web            Run web app only (port 8080)"
	@echo "  make anvil          Run Anvil only (port 8545)"
	@echo ""
	@echo "Other:"
	@echo "  make shell          Interactive shell in container"
	@echo "  make clean          Remove all containers and images"
	@echo "  make rebuild        Clean rebuild everything"

# Build Docker image
build:
	@echo "Building Docker image with $(DOCKER)..."
	$(DOCKER) build -t usdt-multisig:latest .

# Start all services with docker-compose
up:
	@echo "Starting services with $(DOCKER_COMPOSE)..."
	$(DOCKER_COMPOSE) up -d
	@echo "✅ Services started!"
	@echo "   - Anvil: http://localhost:8545"
	@echo "   - Web:   http://localhost:8080"
	@echo ""
	@echo "Run 'make deploy' to deploy contracts"

# Stop all services
down:
	@echo "Stopping services..."
	$(DOCKER_COMPOSE) down

# View logs
logs:
	$(DOCKER_COMPOSE) logs -f

# Deploy contracts to running Anvil
deploy:
	@echo "Deploying contracts..."
	$(DOCKER_COMPOSE) exec web /entrypoint.sh deploy

# Run web app only
web:
	@echo "Starting web app on http://localhost:8080"
	$(DOCKER) run -p 8080:8080 --rm usdt-multisig:latest serve-web

# Run Anvil only
anvil:
	@echo "Starting Anvil on http://localhost:8545"
	$(DOCKER) run -p 8545:8545 --rm usdt-multisig:latest anvil

# Interactive shell
shell:
	$(DOCKER) run -it --rm usdt-multisig:latest shell

# Clean everything
clean:
	@echo "Cleaning up..."
	$(DOCKER_COMPOSE) down -v
	$(DOCKER) rmi usdt-multisig:latest 2>/dev/null || true
	@echo "✅ Cleanup complete"

# Rebuild everything from scratch
rebuild: clean build
	@echo "✅ Rebuild complete"
