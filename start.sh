#!/bin/bash
set -e  # Exit the script if any statement returns a non-true return value

COMFYUI_DIR="/workspace/runpod-slim/ComfyUI"
VENV_DIR="$COMFYUI_DIR/.venv-cu128"
FILEBROWSER_CONFIG="/root/.config/filebrowser/config.json"
DB_FILE="/workspace/runpod-slim/filebrowser.db"
IMAGE_BROWSER_DIR="/workspace/runpod-slim/sd-webui-infinite-image-browsing"
IMAGE_BROWSER_VENV="$IMAGE_BROWSER_DIR/browser-env"

# ---------------------------------------------------------------------------- #
#                          Function Definitions                                  #
# ---------------------------------------------------------------------------- #

# Setup SSH with optional key or random password
setup_ssh() {
    mkdir -p ~/.ssh
    
    # Generate host keys if they don't exist
    for type in rsa dsa ecdsa ed25519; do
        if [ ! -f "/etc/ssh/ssh_host_${type}_key" ]; then
            ssh-keygen -t ${type} -f "/etc/ssh/ssh_host_${type}_key" -q -N ''
            echo "${type^^} key fingerprint:"
            ssh-keygen -lf "/etc/ssh/ssh_host_${type}_key.pub"
        fi
    done

    # If PUBLIC_KEY is provided, use it
    if [[ $PUBLIC_KEY ]]; then
        echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
        chmod 700 -R ~/.ssh
    else
        # Generate random password if no public key
        RANDOM_PASS=$(openssl rand -base64 12)
        echo "root:${RANDOM_PASS}" | chpasswd
        echo "Generated random SSH password for root: ${RANDOM_PASS}"
    fi

    # Configure SSH to preserve environment variables
    echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config

    # Start SSH service
    /usr/sbin/sshd
}

# Export environment variables
export_env_vars() {
    echo "Exporting environment variables..."
    
    # Create environment files
    ENV_FILE="/etc/environment"
    PAM_ENV_FILE="/etc/security/pam_env.conf"
    SSH_ENV_DIR="/root/.ssh/environment"
    
    # Backup original files
    cp "$ENV_FILE" "${ENV_FILE}.bak" 2>/dev/null || true
    cp "$PAM_ENV_FILE" "${PAM_ENV_FILE}.bak" 2>/dev/null || true
    
    # Clear files
    > "$ENV_FILE"
    > "$PAM_ENV_FILE"
    mkdir -p /root/.ssh
    > "$SSH_ENV_DIR"
    
    # Export to multiple locations for maximum compatibility
    printenv | grep -E '^RUNPOD_|^PATH=|^_=|^CUDA|^LD_LIBRARY_PATH|^PYTHONPATH' | while read -r line; do
        # Get variable name and value
        name=$(echo "$line" | cut -d= -f1)
        value=$(echo "$line" | cut -d= -f2-)
        
        # Add to /etc/environment (system-wide)
        echo "$name=\"$value\"" >> "$ENV_FILE"
        
        # Add to PAM environment
        echo "$name DEFAULT=\"$value\"" >> "$PAM_ENV_FILE"
        
        # Add to SSH environment file
        echo "$name=\"$value\"" >> "$SSH_ENV_DIR"
        
        # Add to current shell
        echo "export $name=\"$value\"" >> /etc/rp_environment
    done
    
    # Add sourcing to shell startup files
    echo 'source /etc/rp_environment' >> ~/.bashrc
    echo 'source /etc/rp_environment' >> /etc/bash.bashrc
    
    # Set permissions
    chmod 644 "$ENV_FILE" "$PAM_ENV_FILE"
    chmod 600 "$SSH_ENV_DIR"
}

# Start Jupyter Lab server for remote access
start_jupyter() {
    mkdir -p /workspace
    echo "Starting Jupyter Lab on port 8888..."
    nohup jupyter lab \
        --allow-root \
        --no-browser \
        --port=8888 \
        --ip=0.0.0.0 \
        --FileContentsManager.delete_to_trash=False \
        --FileContentsManager.preferred_dir=/workspace \
        --ServerApp.root_dir=/workspace \
        --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
        --IdentityProvider.token="${JUPYTER_PASSWORD:-}" \
        --ServerApp.allow_origin=* &> /jupyter.log &
    echo "Jupyter Lab started"
}


# Start Infinite Image Browsing
start_image_browser() {
    echo "Starting Infinite Image Browsing on port 7888..."
    cd "$IMAGE_BROWSER_DIR"
    nohup "$IMAGE_BROWSER_VENV/bin/python" app.py --port=7888 --host=0.0.0.0 &> /workspace/runpod-slim/image_browser.log &
    echo "Infinite Image Browsing started"
}

# ---------------------------------------------------------------------------- #
#                               Main Program                                     #
# ---------------------------------------------------------------------------- #

# Setup environment
setup_ssh
export_env_vars

# Initialize FileBrowser if not already done
if [ ! -f "$DB_FILE" ]; then
    echo "Initializing FileBrowser..."
    filebrowser config init
    filebrowser config set --address 0.0.0.0
    filebrowser config set --port 8080
    filebrowser config set --root /workspace
    filebrowser config set --auth.method=json
    filebrowser users add admin adminadmin12 --perm.admin
else
    echo "Using existing FileBrowser configuration..."
fi

# Start FileBrowser
echo "Starting FileBrowser on port 8080..."
nohup filebrowser &> /filebrowser.log &

start_jupyter

# Create default comfyui_args.txt if it doesn't exist
ARGS_FILE="/workspace/runpod-slim/comfyui_args.txt"
if [ ! -f "$ARGS_FILE" ]; then
    echo "# Add your custom ComfyUI arguments here (one per line)" > "$ARGS_FILE"
    echo "Created empty ComfyUI arguments file at $ARGS_FILE"
fi

# Setup Infinite Image Browsing if needed
if [ ! -d "$IMAGE_BROWSER_DIR" ]; then
    echo "Installing Infinite Image Browsing..."
    cd /workspace/runpod-slim
    git clone https://github.com/zanllp/sd-webui-infinite-image-browsing.git
fi

if [ ! -d "$IMAGE_BROWSER_VENV" ]; then
    echo "Setting up Infinite Image Browsing virtual environment..."
    cd "$IMAGE_BROWSER_DIR"
    python3.12 -m venv browser-env
    source browser-env/bin/activate
    pip install --no-cache-dir -r requirements.txt
    deactivate
fi

# Configure Infinite Image Browsing default path
echo "Configuring Image Browser default path..."
"$IMAGE_BROWSER_VENV/bin/python" /set_default_image_browser_path.py "$COMFYUI_DIR/output" --project-path "$IMAGE_BROWSER_DIR" --mode scanned

start_image_browser

# Setup ComfyUI if needed
if [ ! -d "$COMFYUI_DIR" ]; then
    echo "Cloning ComfyUI..."
    cd /workspace/runpod-slim
    git clone https://github.com/comfyanonymous/ComfyUI.git
fi

# Setup ComfyUI Manager config
if [ -f "/config.ini" ]; then
    echo "Setting up ComfyUI Manager config..."
    mkdir -p "$COMFYUI_DIR/user/__manager"
    cp /config.ini "$COMFYUI_DIR/user/__manager/config.ini"
fi

# Install ComfyUI-Manager if not present
if [ ! -d "$COMFYUI_DIR/custom_nodes/ComfyUI-Manager" ]; then
    echo "Installing ComfyUI-Manager..."
    mkdir -p "$COMFYUI_DIR/custom_nodes"
    cd "$COMFYUI_DIR/custom_nodes"
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git
fi

# Create/Activate virtual environment
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    cd $COMFYUI_DIR
    python3.12 -m venv --system-site-packages $VENV_DIR
    source $VENV_DIR/bin/activate
else
    echo "Activating virtual environment..."
    source $VENV_DIR/bin/activate
fi

# Ensure base dependencies
echo "Installing/Updating base dependencies..."
python -m ensurepip --upgrade
python -m pip install --upgrade pip setuptools wheel
python -m pip install -r /workspace/runpod-slim/ComfyUI/requirements.txt
# Fix missing dependencies for some nodes
python -m pip install piexif PyWavelets numba

# Install additional custom nodes
CUSTOM_NODES=(
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

for repo in "${CUSTOM_NODES[@]}"; do
    repo_name=$(basename "$repo")
    if [ ! -d "$COMFYUI_DIR/custom_nodes/$repo_name" ]; then
        echo "Installing $repo_name..."
        cd "$COMFYUI_DIR/custom_nodes"
        git clone --recursive "$repo"
    fi
done

# Install dependencies for all custom nodes
echo "Installing custom node dependencies..."
cd "$COMFYUI_DIR/custom_nodes"
for node_dir in */; do
    if [ -d "$node_dir" ]; then
        echo "Checking dependencies for $node_dir..."
        cd "$COMFYUI_DIR/custom_nodes/$node_dir"
        
        # Initialize submodules if present
        if [ -f ".gitmodules" ]; then
            echo "Initializing submodules for $node_dir"
            git submodule update --init --recursive
        fi

        # Check for requirements.txt
        if [ -f "requirements.txt" ]; then
            echo "Installing requirements.txt for $node_dir"
            python -m pip install --no-cache-dir -r requirements.txt
        fi
        
        # Check for install.py
        if [ -f "install.py" ]; then
            echo "Running install.py for $node_dir"
            python install.py
        fi
        
        # Check for setup.py
        if [ -f "setup.py" ]; then
            echo "Running setup.py for $node_dir"
            python -m pip install --no-cache-dir -e .
        fi
    fi
done

# Patch ComfyUI-Manager model-list.json with custom models
if [ -d "$COMFYUI_DIR/custom_nodes/ComfyUI-Manager" ] && [ -f "/models.json" ]; then
    echo "Patching ComfyUI-Manager model-list.json..."
    python /json_patch.py --source /models.json --target "$COMFYUI_DIR/custom_nodes/ComfyUI-Manager/model-list.json"

    # Patch cached model list
    CACHE_DIR="$COMFYUI_DIR/user/__manager/cache"
    if [ -d "$CACHE_DIR" ]; then
        echo "Searching for cached model list in $CACHE_DIR..."
        CACHE_FILE=$(find "$CACHE_DIR" -maxdepth 1 -name "*_model-list.json" | head -n 1)
        if [ ! -z "$CACHE_FILE" ]; then
            echo "Patching cached model list: $CACHE_FILE"
            python /json_patch.py --source /models.json --target "$CACHE_FILE"
        fi
    fi
fi

# Start ComfyUI with custom arguments if provided
cd $COMFYUI_DIR
FIXED_ARGS="--listen 0.0.0.0 --port 8188"
if [ -s "$ARGS_FILE" ]; then
    # File exists and is not empty, combine fixed args with custom args
    CUSTOM_ARGS=$(grep -v '^#' "$ARGS_FILE" | tr '\n' ' ')
    if [ ! -z "$CUSTOM_ARGS" ]; then
        echo "Starting ComfyUI with additional arguments: $CUSTOM_ARGS"
        nohup python main.py $FIXED_ARGS $CUSTOM_ARGS &> /workspace/runpod-slim/comfyui.log &
    else
        echo "Starting ComfyUI with default arguments"
        nohup python main.py $FIXED_ARGS &> /workspace/runpod-slim/comfyui.log &
    fi
else
    # File is empty, use only fixed args
    echo "Starting ComfyUI with default arguments"
    nohup python main.py $FIXED_ARGS &> /workspace/runpod-slim/comfyui.log &
fi

# Tail the log file
tail -f /workspace/runpod-slim/comfyui.log

