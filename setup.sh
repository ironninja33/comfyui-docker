#!/bin/bash
set -e

# Start Timer
START_TIME=$(date +%s)

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
INSTALL_DIR="/workspace"
COMFYUI_DIR="${COMFYUI_DIR:-$INSTALL_DIR/ComfyUI}"
VENV_DIR="$INSTALL_DIR/comfyui-env"
IMAGE_BROWSER_DIR="$INSTALL_DIR/sd-webui-infinite-image-browsing"
IMAGE_BROWSER_VENV="$IMAGE_BROWSER_DIR/browser-env"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting ComfyUI Setup Script...${NC}"
echo -e "${YELLOW}This script will install dependencies, compile FFmpeg 7.0, and setup ComfyUI in: $INSTALL_DIR${NC}"

# Check for sudo/root for system dependencies
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Basic system dependencies and FFmpeg installation require root privileges.${NC}"
    echo -e "${YELLOW}Please run with sudo or as root if you need to install system packages.${NC}"
    read -p "Do you want to attempt installing system dependencies (requires sudo)? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SUDO="sudo"
    else
        echo -e "${YELLOW}Skipping system dependency installation. Ensure you have them installed manually.${NC}"
        SUDO=""
    fi
else
    SUDO=""
fi

# 1. Install System Dependencies
if [ ! -z "$SUDO" ] || [ "$EUID" -eq 0 ]; then
    echo -e "${GREEN}[1/8] Installing system dependencies...${NC}"
    $SUDO apt-get update
    $SUDO apt-get install -y build-essential pkg-config python3-dev cython3 git wget yasm nasm python3-venv
fi

# 2. Build FFmpeg 7 from source
FFMPEG_DIR="$INSTALL_DIR/ffmpeg"
export PATH="$FFMPEG_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$FFMPEG_DIR/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$FFMPEG_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"

echo "PATH, including ffmpeg: {$PATH}"

if [ ! -f "$FFMPEG_DIR/bin/ffmpeg" ]; then
    echo -e "${GREEN}[2/8] Compiling FFmpeg 7.0...${NC}"
    echo -e "${GREEN}Downloading and compiling FFmpeg 7.0 to $FFMPEG_DIR...${NC}"
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    wget https://ffmpeg.org/releases/ffmpeg-7.0.tar.gz
    tar xvf ffmpeg-7.0.tar.gz
    cd ffmpeg-7.0
    ./configure --prefix="$FFMPEG_DIR" --disable-doc --disable-debug --enable-shared
    make -j$(nproc)
    make install
    cd "$INSTALL_DIR"
    rm -rf "$TEMP_DIR"
else
    echo -e "${GREEN}FFmpeg 7 detected, skipping compilation.${NC}"
fi

# Add FFmpeg to .bashrc for persistence
if ! grep -q "$FFMPEG_DIR/bin" ~/.bashrc; then
    echo "export PATH=\"$FFMPEG_DIR/bin:\$PATH\"" >> ~/.bashrc
    echo "export LD_LIBRARY_PATH=\"$FFMPEG_DIR/lib:\$LD_LIBRARY_PATH\"" >> ~/.bashrc
    echo "export PKG_CONFIG_PATH=\"$FFMPEG_DIR/lib/pkgconfig:\$PKG_CONFIG_PATH\"" >> ~/.bashrc
    echo -e "${GREEN}Added FFmpeg to ~/.bashrc for persistence.${NC}"
fi

# 3. Setup ComfyUI
echo -e "${GREEN}[3/8] Setting up ComfyUI...${NC}"
if [ ! -d "$COMFYUI_DIR" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git
else
    echo "ComfyUI already cloned."
fi

# 4. Setup Virtual Environment
echo -e "${GREEN}[4/8] Setting up Python Virtual Environment...${NC}"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip setuptools wheel
    
    # Install PyTorch
    pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu118

    # Install base requirements
    if [ -f "$COMFYUI_DIR/requirements.txt" ]; then
        pip install -r "$COMFYUI_DIR/requirements.txt"
    fi
    
    # Fix missing dependencies mentioned in original script
    pip install piexif PyWavelets numba
else
    echo "Virtual environment exists."
    source "$VENV_DIR/bin/activate"
fi

# 5. Install Custom Nodes
echo -e "${GREEN}[5/8] Installing Custom Nodes...${NC}"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
mkdir -p "$CUSTOM_NODES_DIR"

# Install ComfyUI-Manager
if [ ! -d "$CUSTOM_NODES_DIR/ComfyUI-Manager" ]; then
    echo "Installing ComfyUI-Manager..."
    cd "$CUSTOM_NODES_DIR"
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git
    cd "$INSTALL_DIR"
fi

# List of custom nodes from start.sh
NODES=(
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/MoonGoblinDev/Civicomfy"
    "https://github.com/MadiatorLabs/ComfyUI-RunpodDirect"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/ClownsharkBatwing/RES4LYF"
    "https://github.com/receyuki/comfyui-prompt-reader-node"
    "https://github.com/WASasquatch/was-node-suite-comfyui"
    "https://github.com/silveroxides/ComfyUI_SigmoidOffsetScheduler"
)

for repo in "${NODES[@]}"; do
    repo_name=$(basename "$repo")
    if [ ! -d "$CUSTOM_NODES_DIR/$repo_name" ]; then
        echo "Installing $repo_name..."
        cd "$CUSTOM_NODES_DIR"
        git clone --recursive "$repo"
        cd "$INSTALL_DIR"
    fi
done

# Install dependencies for custom nodes
echo "Installing custom node dependencies..."
cd "$CUSTOM_NODES_DIR"
for node_dir in */; do
    if [ -d "$node_dir" ]; then
        cd "$CUSTOM_NODES_DIR/$node_dir"
        echo "Checking dependencies for $node_dir..."
        
        if [ -f "requirements.txt" ]; then
            pip install --no-cache-dir -r requirements.txt
        fi
        
        if [ -f "install.py" ]; then
            python install.py
        fi
        
        if [ -f "setup.py" ]; then
            pip install --no-cache-dir -e .
        fi
    fi
done
cd "$INSTALL_DIR"

# 6. Infinite Image Browser Setup
echo -e "${GREEN}[6/8] Setting up Infinite Image Browser...${NC}"
if [ ! -d "$IMAGE_BROWSER_DIR" ]; then
    git clone https://github.com/zanllp/sd-webui-infinite-image-browsing.git
fi

if [ ! -d "$IMAGE_BROWSER_VENV" ]; then
    echo "Creating Image Browser venv..."
    cd "$IMAGE_BROWSER_DIR"
    python3 -m venv browser-env
    source browser-env/bin/activate
    pip install --no-cache-dir -r requirements.txt
    deactivate
    cd "$INSTALL_DIR"
fi

# Configure Image Browser default path
echo "Configuring Image Browser default path..."
if [ -f "$SCRIPT_DIR/set_default_image_browser_path.py" ]; then
    "$IMAGE_BROWSER_VENV/bin/python" "$SCRIPT_DIR/set_default_image_browser_path.py" "$COMFYUI_DIR/output" --project-path "$IMAGE_BROWSER_DIR" --mode scanned
else
    echo -e "${YELLOW}Warning: set_default_image_browser_path.py not found in $SCRIPT_DIR.${NC}"
fi

# 7. Apply Configuration Patches
echo -e "${GREEN}[7/8] Applying Configurations...${NC}"

# Config.ini
if [ -f "$SCRIPT_DIR/config.ini" ]; then
    mkdir -p "$COMFYUI_DIR/user/__manager"
    cp "$SCRIPT_DIR/config.ini" "$COMFYUI_DIR/user/__manager/config.ini"
    echo "Copied config.ini"
fi

# Patch models.json
if [ -f "$SCRIPT_DIR/json_patch.py" ] && [ -f "$SCRIPT_DIR/models.json" ] && [ -d "$CUSTOM_NODES_DIR/ComfyUI-Manager" ]; then
    echo "Patching ComfyUI-Manager model list..."
    python "$SCRIPT_DIR/json_patch.py" --source "$SCRIPT_DIR/models.json" --target "$CUSTOM_NODES_DIR/ComfyUI-Manager/model-list.json"
fi

# 8. Start Services
echo -e "${GREEN}[8/8] Starting Services...${NC}"

# Start Image Browser
echo "Starting Infinite Image Browsing (Port 7888)..."
cd "$IMAGE_BROWSER_DIR"
nohup "$IMAGE_BROWSER_VENV/bin/python" app.py --port=7888 --host=0.0.0.0 &> "$INSTALL_DIR/image_browser.log" &
echo "Image Browser started. Log: $INSTALL_DIR/image_browser.log"

# Start ComfyUI
echo "Starting ComfyUI (Port 8188)..."
cd "$COMFYUI_DIR"
# Use the main venv
source "$VENV_DIR/bin/activate"

ARGS="--listen 0.0.0.0 --port 8188"
echo "Launching ComfyUI with args: $ARGS"
nohup python main.py $ARGS &> "$INSTALL_DIR/comfyui.log" &
echo "ComfyUI started. Log: $INSTALL_DIR/comfyui.log"

echo -e "${GREEN}Setup Complete! Services are running in the background.${NC}"
echo -e "${GREEN}ComfyUI: http://localhost:8188${NC}"
echo -e "${GREEN}Image Browser: http://localhost:7888${NC}"

# End Timer
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo -e "${GREEN}Setup took $(($ELAPSED / 60)) minutes and $(($ELAPSED % 60)) seconds.${NC}"
