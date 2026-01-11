#!/bin/bash

# MoFA Studio - Isolated Environment Setup (uv-based)
# Creates a fresh Python environment with all required Dora nodes
# Uses uv for fast package management
# See DEPENDENCIES.md for detailed dependency specifications

set -e  # Exit on error

# Configuration
ENV_NAME="mofa-studio"
PYTHON_VERSION="3.12"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/../.."
NODE_HUB_DIR="$PROJECT_ROOT/node-hub"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
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

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Install system dependencies
install_system_dependencies() {
    print_header "Installing System Dependencies"

    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        print_info "macOS detected. Checking for Homebrew..."
        if command -v brew &> /dev/null; then
            print_info "Installing system dependencies via Homebrew..."
            brew install gcc openssl libffi portaudio ffmpeg git-lfs
            print_success "System dependencies installed"
        else
            print_warning "Homebrew not found. Please install from https://brew.sh/"
            print_info "Then run: brew install gcc openssl libffi portaudio ffmpeg git-lfs"
        fi
    elif command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        print_info "Installing system dependencies..."
        sudo apt-get update
        sudo apt-get install -y gcc g++ gfortran build-essential make
        sudo apt-get install -y libopenblas-dev openssl libssl-dev
        sudo apt-get install -y portaudio19-dev python3-pyaudio libgomp1 libomp-dev ffmpeg
        sudo apt-get install -y git-lfs
        print_success "System dependencies installed"
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        print_info "Installing system dependencies..."
        sudo yum install -y gcc gcc-c++ gcc-gfortran make
        sudo yum install -y openblas-devel openssl openssl-devel
        sudo yum install -y portaudio-devel libgomp-devel ffmpeg
        sudo yum install -y git-lfs
        print_success "System dependencies installed"
    elif command -v dnf &> /dev/null; then
        # Fedora
        print_info "Installing system dependencies..."
        sudo dnf install -y gcc gcc-c++ gcc-gfortran make
        sudo dnf install -y openblas-devel openssl openssl-devel
        sudo dnf install -y portaudio-devel libgomp-devel ffmpeg
        sudo dnf install -y git-lfs
        print_success "System dependencies installed"
    else
        print_warning "Package manager not detected. Please install dependencies manually"
        print_info "macOS: brew install gcc openssl libffi portaudio ffmpeg git-lfs"
        print_info "Ubuntu/Debian: sudo apt install gcc g++ gfortran build-essential libopenblas-dev openssl libssl-dev portaudio19-dev libgomp1 libomp-dev ffmpeg git-lfs"
        print_info "RHEL/CentOS: sudo yum install gcc gcc-c++ gcc-gfortran openblas-devel openssl-devel portaudio-devel libgomp-devel ffmpeg git-lfs"
    fi
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check uv
    if command -v uv &> /dev/null; then
        print_success "uv found: $(uv --version)"
    else
        print_error "uv not found. Please install uv"
        echo ""
        echo "============================================"
        echo "UV INSTALLATION INSTRUCTIONS"
        echo "============================================"
        echo ""
        echo "Choose ONE of the following options:"
        echo ""
        echo "OPTION A: Install via curl (RECOMMENDED)"
        echo "----------------------------------------"
        echo "curl -LsSf https://astral.sh/uv/install.sh | sh"
        echo ""
        echo "OPTION B: Install via pip"
        echo "-------------------------"
        echo "pip install uv"
        echo ""
        echo "OPTION C: Install via homebrew (macOS)"
        echo "--------------------------------------"
        echo "brew install uv"
        echo ""
        echo "After installation, run this script again."
        echo "============================================"
        exit 1
    fi

    # Check git
    if command -v git &> /dev/null; then
        print_success "Git found: $(git --version)"
    else
        print_error "Git not found. Please install git"
        exit 1
    fi

    # Check cargo (optional, for Rust nodes)
    if command -v cargo &> /dev/null; then
        print_success "Cargo found: $(cargo --version)"
    else
        print_warning "Cargo not found. Rust nodes will not be built"
        print_info "Install from: https://rustup.rs/"
    fi
}

# Create uv environment
create_environment() {
    print_header "Creating UV Environment: $ENV_NAME"

    # Check if environment already exists
    ENV_DIR="$PROJECT_ROOT/.venv"
    if [ -d "$ENV_DIR" ]; then
        print_warning "Virtual environment already exists at $ENV_DIR"
        read -p "Do you want to remove and recreate it? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing existing environment..."
            rm -rf "$ENV_DIR"
        else
            print_info "Using existing environment"
            return
        fi
    fi

    print_info "Creating new uv virtual environment with Python $PYTHON_VERSION..."
    cd "$PROJECT_ROOT"
    uv venv --python $PYTHON_VERSION
    print_success "Environment created successfully"
}

# Activate environment and install dependencies
install_dependencies() {
    print_header "Installing Dependencies"

    cd "$PROJECT_ROOT"

    # Check if pyproject.toml exists, if not create it
    if [ ! -f "pyproject.toml" ]; then
        print_warning "pyproject.toml not found. Creating default configuration..."
        # The pyproject.toml should exist in the project root
        # If it doesn't, something is wrong
        print_error "Please ensure pyproject.toml exists in project root"
        exit 1
    fi

    print_info "Active Python: $(uv run which python 2>/dev/null || echo 'not initialized')"
    print_info "Python version: $(uv run python --version 2>/dev/null || echo 'not initialized')"

    # Sync dependencies from pyproject.toml
    print_info "Installing dependencies from pyproject.toml..."
    uv sync

    # Install MLX backend (macOS only - Apple Silicon GPU acceleration)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "MLX audio backend is available for macOS (Apple Silicon GPU)"
        print_warning "Skipping automatic MLX installation - it requires transformers>=4.49.0"
        print_info "To install MLX manually (will upgrade transformers):"
        print_info "  uv pip install mlx-audio --upgrade transformers"
    else
        print_info "MLX backend is macOS-only, using CPU backend for TTS"
    fi

    # Download NLTK data for TTS text processing
    print_info "Downloading NLTK data for text processing..."
    uv run python -c "import nltk; nltk.download('averaged_perceptron_tagger_eng', quiet=True); nltk.download('averaged_perceptron_tagger', quiet=True); nltk.download('cmudict', quiet=True)"
    print_success "NLTK data downloaded"

    print_success "Core dependencies installed"
}

# Install and check dora CLI
install_dora_cli() {
    print_header "Installing Dora CLI"

    # Check if cargo is available
    if command -v cargo &> /dev/null; then
        print_info "Installing dora-cli v0.3.12 via cargo..."
        cargo install dora-cli --version 0.3.12 --locked

        # Check if installation was successful
        if [ -f "$HOME/.cargo/bin/dora" ]; then
            VERSION=$($HOME/.cargo/bin/dora --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")
            if [ "$VERSION" = "0.3.12" ]; then
                # Link to virtual environment
                mkdir -p "$ENV_DIR/bin"
                ln -sf "$HOME/.cargo/bin/dora" "$ENV_DIR/bin/dora"
                print_success "Dora CLI version 0.3.12 installed and linked to environment"
            else
                print_warning "Dora CLI installed but version is $VERSION (expected 0.3.12)"
            fi
        else
            print_warning "Dora CLI installation failed"
        fi
    else
        print_warning "Cargo not found. Cannot install dora-cli via cargo."
        print_info "Install Rust from https://rustup.rs/ to get the latest dora-cli"
        print_info "Using dora from pip installation instead"
    fi
}

# Install Dora nodes
install_dora_nodes() {
    print_header "Installing Dora Nodes"

    # List of Python nodes to install
    NODES=(
        "dora-asr"
        "dora-primespeech"
        "dora-kokoro-tts"
        "dora-qwen3"
        "dora-text-segmenter"
        "dora-speechmonitor"
    )

    for node in "${NODES[@]}"; do
        NODE_PATH="$NODE_HUB_DIR/$node"
        if [ -d "$NODE_PATH" ]; then
            print_info "Installing $node..."
            uv pip install -e "$NODE_PATH"
            print_success "$node installed"
        else
            print_warning "$node not found at $NODE_PATH"
        fi
    done

    # Build Rust nodes if cargo is available
    if command -v cargo &> /dev/null; then
        print_info "Building Rust nodes..."

        # Build dora-maas-client
        if [ -d "$NODE_HUB_DIR/dora-maas-client" ]; then
            print_info "Building dora-maas-client..."
            cd "$NODE_HUB_DIR/dora-maas-client"
            cargo build --release
            print_success "dora-maas-client built"
        fi

        # Build dora-openai-websocket
        if [ -d "$NODE_HUB_DIR/dora-openai-websocket" ]; then
            print_info "Building dora-openai-websocket..."
            cd "$NODE_HUB_DIR/dora-openai-websocket"
            cargo build --release -p dora-openai-websocket
            print_success "dora-openai-websocket built"
        fi

        cd "$SCRIPT_DIR"
    else
        print_warning "Skipping Rust node builds (cargo not found)"
    fi
}

# Run tests
run_tests() {
    print_header "Running Node Tests"

    if [ -d "$SCRIPT_DIR/tests" ]; then
        print_info "Running test suite..."
        uv run python "$SCRIPT_DIR/tests/run_all_tests.py"
    else
        print_warning "Test directory not found"
    fi
}

# Print summary
print_summary() {
    print_header "Setup Complete!"

    echo ""
    echo "Environment Location: $ENV_DIR"
    echo "Python Version: $PYTHON_VERSION"
    echo "Dependency Management: uv with pyproject.toml"
    echo ""

    # Check which TTS backends are available
    echo "TTS Backends Installed:"
    echo "  ✓ CPU (kokoro) - Cross-platform, best for short text (<150 chars)"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo ""
        echo "  MLX (mlx-audio) - Apple Silicon GPU, best for long text (>200 chars)"
        echo "  Note: MLX NOT auto-installed due to transformers version conflict."
        echo "  To install manually (will upgrade transformers):"
        echo "    uv pip install mlx-audio --upgrade transformers"
    fi
    echo ""

    echo "Project Structure:"
    echo "  - pyproject.toml: Python dependencies declaration"
    echo "  - uv.lock: Locked dependency versions (auto-generated)"
    echo "  - .venv: Virtual environment"
    echo ""

    echo "To activate the environment:"
    echo "  source $ENV_DIR/bin/activate"
    echo ""
    echo "Or use uv run directly:"
    echo "  uv run <command>"
    echo ""
    echo "To update dependencies later:"
    echo "  uv sync  # Sync with pyproject.toml"
    echo "  uv add <package>  # Add new dependency"
    echo ""
    echo "To test the installation:"
    echo "  cd $SCRIPT_DIR"
    echo "  uv run python tests/run_all_tests.py"
    echo ""
    echo "To run examples:"
    echo "  cd $PROJECT_ROOT/examples/mac-aec-chat"
    echo "  dora up"
    echo "  dora start voice-chat-with-aec.yml"
    echo ""
    echo "To test Kokoro TTS backends:"
    echo "  cd $SCRIPT_DIR/kokoro-tts-validation"
    echo "  ./run_all_tests.sh"
    echo ""
    print_success "Setup completed successfully!"
}

# Main execution
main() {
    print_header "Dora Voice Chat - Isolated Environment Setup (uv)"

    check_prerequisites
    install_system_dependencies
    create_environment

    install_dependencies
    install_dora_cli
    install_dora_nodes

    print_summary
}

# Run main function
main "$@"
