#!/bin/bash

# MoFA Studio - Isolated Environment Setup
# Creates a fresh Python environment with all required Dora nodes
# Uses standardized dependency versions to avoid conflicts
# See DEPENDENCIES.md for detailed dependency specifications

set -e  # Exit on error

# Configuration
ENV_NAME=".venv"
PYTHON_VERSION="3.12"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/../.."  # Assumes script is in examples/setup-new-chatbot
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

    # Install all required system dependencies
    if command -v apt-get &> /dev/null; then
        print_info "Installing system dependencies..."
        sudo apt-get update
        # Install essential build tools
        sudo apt-get install -y gcc g++ gfortran build-essential make
        # Install required libraries
        sudo apt-get install -y libopenblas-dev openssl libssl-dev
        # Install audio and multimedia libraries
        sudo apt-get install -y portaudio19-dev python3-pyaudio libgomp1 libomp-dev ffmpeg
        # Install git-lfs for large file support
        sudo apt-get install -y git-lfs
        print_success "All system dependencies installed"
    elif command -v yum &> /dev/null; then
        print_info "Installing system dependencies..."
        sudo yum install -y gcc gcc-c++ gcc-gfortran make
        sudo yum install -y openblas-devel openssl openssl-devel
        sudo yum install -y portaudio-devel libgomp-devel ffmpeg
        sudo yum install -y git-lfs
        print_success "All system dependencies installed"
    elif command -v dnf &> /dev/null; then
        print_info "Installing system dependencies..."
        sudo dnf install -y gcc gcc-c++ gcc-gfortran make
        sudo dnf install -y openblas-devel openssl openssl-devel
        sudo dnf install -y portaudio-devel libgomp-devel ffmpeg
        sudo dnf install -y git-lfs
        print_success "All system dependencies installed"
    else
        print_warning "Package manager not detected. Please install dependencies manually"
        print_info "Ubuntu/Debian: sudo apt install gcc g++ gfortran build-essential libopenblas-dev openssl libssl-dev portaudio19-dev libgomp1 libomp-dev ffmpeg git-lfs"
        print_info "RHEL/CentOS: sudo yum install gcc gcc-c++ gcc-gfortran openblas-devel openssl-devel portaudio-devel libgomp-devel ffmpeg git-lfs"
        print_info "Fedora: sudo dnf install gcc gcc-c++ gcc-gfortran openblas-devel openssl-devel portaudio-devel libgomp-devel ffmpeg git-lfs"
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
        echo "OPTION A: Install via pip (RECOMMENDED)"
        echo "----------------------------------------------------------------"
        echo "pip install uv"
        echo ""
        echo "OPTION B: Install via official installer script"
        echo "----------------------------------------------------------------"
        echo "curl -LsSf https://astral.sh/uv/install.sh | sh"
        echo ""
        echo "OPTION C: Install via Homebrew (macOS/Linux)"
        echo "----------------------------------------------------------------"
        echo "brew install uv"
        echo ""
        echo "After installation, run this script again."
        echo "============================================"
        exit 1
    fi

    # Check python
    if command -v python3 &> /dev/null; then
        print_success "Python found: $(python3 --version)"
    else
        print_error "Python3 not found. Please install Python 3.12 or later"
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

# Create virtual environment with uv
create_environment() {
    print_header "Creating Virtual Environment: $ENV_NAME"

    # Check if environment already exists
    if [ -d "$SCRIPT_DIR/$ENV_NAME" ]; then
        print_warning "Environment '$ENV_NAME' already exists"
        read -p "Do you want to remove and recreate it? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing existing environment..."
            rm -rf "$SCRIPT_DIR/$ENV_NAME"
        else
            print_info "Using existing environment"
            return
        fi
    fi

    print_info "Creating new virtual environment with Python $PYTHON_VERSION..."
    uv venv --python $PYTHON_VERSION "$SCRIPT_DIR/$ENV_NAME"
    print_success "Environment created successfully"
}

# Activate environment and install dependencies
install_dependencies() {
    print_header "Installing Dependencies"

    # Activate environment
    source "$SCRIPT_DIR/$ENV_NAME/bin/activate"

    print_info "Active Python: $(which python)"
    print_info "Python version: $(python --version)"

    # Install critical dependencies with specific versions using uv pip
    print_info "Installing core dependencies..."
    # Install standardized versions (see DEPENDENCIES.md)
    uv pip install numpy==1.26.4  # Voice chat pipeline standard (1.x compatibility)
    uv pip install torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 --index-url https://download.pytorch.org/whl/cpu

    # Install transformers and related packages
    print_info "Installing ML libraries..."
    uv pip install transformers==4.45.0  # Voice chat pipeline standard (security compliant)
    uv pip install huggingface-hub==0.34.4
    uv pip install datasets accelerate sentencepiece protobuf

    # Install dora-rs
    print_info "Installing dora-rs..."
    uv pip install dora-rs==0.3.12

    # Install other dependencies
    print_info "Installing additional dependencies..."
    uv pip install pyarrow scipy librosa soundfile webrtcvad
    uv pip install openai websockets aiohttp requests
    uv pip install pyyaml toml python-dotenv
    uv pip install pyaudio sounddevice
    uv pip install nltk  # Required for TTS text processing

    # Install llama-cpp-python
    print_info "Installing llama-cpp-python..."
    uv pip install llama-cpp-python

    # Install TTS backends
    print_info "Installing TTS backends..."
    uv pip install kokoro  # CPU backend (cross-platform)

    # Install MLX backend (macOS only - Apple Silicon GPU acceleration)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "Installing MLX audio backend (Apple Silicon GPU acceleration)..."
        uv pip install mlx-audio
        print_success "MLX audio backend installed (GPU-accelerated TTS)"
    else
        print_warning "Skipping MLX audio backend (macOS only)"
        print_info "Using CPU backend for TTS (cross-platform compatible)"
    fi

    # Download NLTK data for TTS text processing
    print_info "Downloading NLTK data for text processing..."
    python -c "import nltk; nltk.download('averaged_perceptron_tagger_eng', quiet=True); nltk.download('averaged_perceptron_tagger', quiet=True); nltk.download('cmudict', quiet=True)"
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
                mkdir -p "$SCRIPT_DIR/$ENV_NAME/bin"
                ln -sf "$HOME/.cargo/bin/dora" "$SCRIPT_DIR/$ENV_NAME/bin/dora"
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

    # Activate environment
    source "$SCRIPT_DIR/$ENV_NAME/bin/activate"

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

# Fix numpy compatibility
fix_numpy_compatibility() {
    print_header "Fixing NumPy Compatibility"

    # Activate environment
    source "$SCRIPT_DIR/$ENV_NAME/bin/activate"

    print_info "Ensuring numpy 1.26.4 is installed..."
    uv pip install numpy==1.26.4 --reinstall  # Ensure 1.x compatibility

    print_success "NumPy compatibility fixed"
}

# Run tests
run_tests() {
    print_header "Running Node Tests"

    # Activate environment
    source "$SCRIPT_DIR/$ENV_NAME/bin/activate"

    if [ -d "$SCRIPT_DIR/tests" ]; then
        print_info "Running test suite..."
        python "$SCRIPT_DIR/tests/run_all_tests.py"
    else
        print_warning "Test directory not found"
    fi
}

# Print summary
print_summary() {
    print_header "Setup Complete!"

    echo ""
    echo "Environment Location: $SCRIPT_DIR/$ENV_NAME"
    echo "Python Version: $PYTHON_VERSION"
    echo ""

    # Check which TTS backends are available
    echo "TTS Backends Installed:"
    echo "  ✓ CPU (kokoro) - Cross-platform, best for short text (<150 chars)"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  ✓ MLX (mlx-audio) - Apple Silicon GPU, best for long text (>200 chars)"
        echo ""
        echo "TTS Backend Selection:"
        echo "  Set BACKEND=cpu   for CPU backend (1.8x faster for short text)"
        echo "  Set BACKEND=mlx   for MLX backend (up to 3x faster for long text)"
        echo "  Set BACKEND=auto  to auto-detect (default)"
    fi
    echo ""

    echo "To activate the environment:"
    echo "  source $SCRIPT_DIR/$ENV_NAME/bin/activate"
    echo ""
    echo "To test the installation:"
    echo "  cd $SCRIPT_DIR"
    echo "  python tests/run_all_tests.py"
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
    print_header "Dora Voice Chat - Isolated Environment Setup"

    check_prerequisites
    install_system_dependencies
    create_environment

    install_dependencies
    install_dora_cli
    install_dora_nodes
    fix_numpy_compatibility

    print_summary
}

# Run main function
main "$@"
