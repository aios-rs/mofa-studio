#!/bin/bash

# Install All Packages Script for MoFA Studio (Linux & macOS)
# This script reinstalls required Python packages and builds Rust components
# Uses uv for fast package management (alternative to conda/pip)

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored messages
print_info() {
    echo -e "${BLUE}ℹ ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}   $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
}

# Detect platform
OS_TYPE="linux"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
fi

# Get the script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV_DIR="$PROJECT_ROOT/.venv"

print_info "Project root: $PROJECT_ROOT"
print_info "Environment directory: $ENV_DIR"

# Check if uv is installed
print_header "Checking uv"
if command -v uv &> /dev/null; then
    print_success "uv found: $(uv --version)"
else
    print_error "uv not found. Please install uv first:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "  or: pip install uv"
    exit 1
fi

# Create virtual environment if it doesn't exist
print_header "Setting up Virtual Environment"
if [ -d "$ENV_DIR" ]; then
    print_success "Virtual environment already exists at $ENV_DIR"
else
    print_info "Creating virtual environment..."
    cd "$PROJECT_ROOT"
    uv venv --python 3.12
    print_success "Virtual environment created"
fi

# OS-specific dependency hints
print_header "Checking System Dependencies"
if [[ "$OS_TYPE" == "linux" ]]; then
    print_info "Installing essential build tools and libraries via apt..."
    sudo apt-get update
    sudo apt-get install -y gcc gfortran libopenblas-dev build-essential openssl libssl-dev
    print_success "System dependencies installed"
else
    print_info "macOS detected. Ensure command line tools/Homebrew packages are installed if builds fail."
    print_info "Run: brew install gcc openssl libffi portaudio ffmpeg git-lfs"
fi

# Install all packages
print_header "Installing Python Packages"
cd "$PROJECT_ROOT"

# First, sync core dependencies from pyproject.toml
print_info "Syncing core dependencies from pyproject.toml..."
uv sync
print_success "Core dependencies installed"

# Then, install local Dora packages in editable mode
print_info "Installing local Dora packages in editable mode..."

print_info "Installing dora-common (shared library)..."
uv pip install -e libs/dora-common
print_success "dora-common installed"

print_info "Installing dora-primespeech..."
uv pip install -e node-hub/dora-primespeech
print_success "dora-primespeech installed"

print_info "Installing dora-asr..."
uv pip install -e node-hub/dora-asr
print_success "dora-asr installed"

print_info "Installing dora-speechmonitor..."
uv pip install -e node-hub/dora-speechmonitor
print_success "dora-speechmonitor installed"

print_info "Installing dora-text-segmenter..."
uv pip install -e node-hub/dora-text-segmenter
print_success "dora-text-segmenter installed"

print_info "Installing additional nodes..."
# Install other nodes if they exist
for node in dora-kokoro-tts dora-qwen3; do
    if [ -d "node-hub/$node" ]; then
        print_info "Installing $node..."
        uv pip install -e "node-hub/$node" 2>/dev/null || print_info "$node install failed, skipping"
    fi
done
print_success "Additional nodes installed"

print_info "MLX backend note:"
if [[ "$OS_TYPE" == "macos" ]]; then
    print_info "MLX audio backend is available for macOS (Apple Silicon GPU)"
    print_warning "Skipping automatic MLX installation - it requires transformers>=4.49.0"
    print_info "To install MLX manually (will upgrade transformers):"
    print_info "  uv pip install mlx-audio --upgrade transformers"
else
    print_info "MLX backend is macOS-only"
fi

# Install Rust if not already installed
print_header "Setting up Rust"
if command -v cargo &> /dev/null; then
    print_info "Rust is already installed"
    rustc --version
    cargo --version
else
    print_info "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    print_success "Rust installed successfully"
fi

# Install Dora CLI
print_header "Installing Dora CLI"
if command -v dora &> /dev/null; then
    current_version=$(dora --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
    print_info "Dora CLI is already installed (version: $current_version)"
    read -p "Do you want to reinstall/update Dora CLI? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cargo install dora-cli --version 0.3.12 --locked --force
        # Link to virtual environment
        mkdir -p "$ENV_DIR/bin"
        ln -sf "$HOME/.cargo/bin/dora" "$ENV_DIR/bin/dora"
        print_success "Dora CLI updated"
    fi
else
    print_info "Installing Dora CLI..."
    cargo install dora-cli --version 0.3.12 --locked
    # Link to virtual environment
    mkdir -p "$ENV_DIR/bin"
    ln -sf "$HOME/.cargo/bin/dora" "$ENV_DIR/bin/dora"
    print_success "Dora CLI installed"
fi

# Build Rust-based nodes
print_header "Building Rust Components"

print_info "Building dora-maas-client..."
if [ -d "$PROJECT_ROOT/node-hub/dora-maas-client" ]; then
    cargo build --release --manifest-path "$PROJECT_ROOT/node-hub/dora-maas-client/Cargo.toml"
    print_success "dora-maas-client built"
else
    print_info "dora-maas-client not found, skipping"
fi

print_info "Building dora-conference-bridge..."
if [ -d "$PROJECT_ROOT/node-hub/dora-conference-bridge" ]; then
    cargo build --release --manifest-path "$PROJECT_ROOT/node-hub/dora-conference-bridge/Cargo.toml"
    print_success "dora-conference-bridge built"
else
    print_info "dora-conference-bridge not found, skipping"
fi

print_info "Building dora-conference-controller..."
if [ -d "$PROJECT_ROOT/node-hub/dora-conference-controller" ]; then
    cargo build --release --manifest-path "$PROJECT_ROOT/node-hub/dora-conference-controller/Cargo.toml"
    print_success "dora-conference-controller built"
else
    print_info "dora-conference-controller not found, skipping"
fi

print_info "Building dora-openai-websocket..."
if [ -d "$PROJECT_ROOT/node-hub/dora-openai-websocket" ]; then
    cargo build --release --manifest-path "$PROJECT_ROOT/node-hub/dora-openai-websocket/Cargo.toml" -p dora-openai-websocket
    print_success "dora-openai-websocket built"
else
    print_info "dora-openai-websocket not found, skipping"
fi

# Summary
print_header "Installation Complete!"
echo -e "${GREEN}All packages have been successfully installed!${NC}"
echo ""
echo "Summary:"
if [[ "$OS_TYPE" == "linux" ]]; then
    echo "  ✓ Linux system dependencies installed"
else
    echo "  ✓ macOS system dependencies assumed ready"
fi
echo "  ✓ Core dependencies installed from pyproject.toml (via uv sync)"
echo "  ✓ Local Dora packages installed in editable mode (via uv add -e)"
echo "  ✓ Rust and Dora CLI installed"
echo "  ✓ Rust components built"
echo ""
echo "Virtual Environment:"
echo "  Location: $ENV_DIR"
echo "  Managed by: uv with pyproject.toml"
echo ""
echo "To activate the environment:"
echo "  source $ENV_DIR/bin/activate"
echo ""
echo "Or use uv run directly:"
echo "  uv run <command>"
echo ""
echo "To update dependencies later:"
echo "  uv sync  # Sync with pyproject.toml"
echo ""
echo "Next steps:"
echo "  1. Download models: cd examples/model-manager && uv run python download_models.py --download primespeech"
echo "  2. Download additional models (funasr, kokoro, qwen) as needed"
echo "  3. Configure any required API keys (e.g. OpenAI)"
echo "  4. Run voice-chat examples under examples/mac-aec-chat"
echo ""
print_success "Ready to use Dora Voice Chat!"
