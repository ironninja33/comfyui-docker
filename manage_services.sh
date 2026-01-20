#!/bin/bash
set -e

# Configuration
INSTALL_DIR="/workspace"
COMFYUI_DIR="$INSTALL_DIR/ComfyUI"
VENV_DIR="$INSTALL_DIR/venv"
IMAGE_BROWSER_DIR="$INSTALL_DIR/sd-webui-infinite-image-browsing"
IMAGE_BROWSER_VENV="$IMAGE_BROWSER_DIR/browser-env"

# PID Files
COMFYUI_PID_FILE="$INSTALL_DIR/comfyui.pid"
IMAGE_BROWSER_PID_FILE="$INSTALL_DIR/image_browser.pid"

# Log Files
COMFYUI_LOG="$INSTALL_DIR/comfyui.log"
IMAGE_BROWSER_LOG="$INSTALL_DIR/image_browser.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_pid() {
    local pid_file=$1
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0 # Running
        else
            return 1 # Stale PID file
        fi
    else
        return 2 # Not running (no PID file)
    fi
}

start_services() {
    echo -e "${GREEN}Starting services...${NC}"

    # Start Image Browser
    if check_pid "$IMAGE_BROWSER_PID_FILE"; then
        echo -e "${YELLOW}Infinite Image Browser is already running (PID: $(cat "$IMAGE_BROWSER_PID_FILE"))${NC}"
    else
        if [ -d "$IMAGE_BROWSER_DIR" ]; then
            echo "Starting Infinite Image Browser (Port 7888)..."
            cd "$IMAGE_BROWSER_DIR"
            nohup "$IMAGE_BROWSER_VENV/bin/python" app.py --port=7888 --host=0.0.0.0 &> "$IMAGE_BROWSER_LOG" &
            echo $! > "$IMAGE_BROWSER_PID_FILE"
            echo -e "${GREEN}Infinite Image Browser started (PID: $!). Log: $IMAGE_BROWSER_LOG${NC}"
            cd "$INSTALL_DIR" # Return to base
        else
             echo -e "${RED}Error: Infinite Image Browser directory not found at $IMAGE_BROWSER_DIR${NC}"
        fi
    fi

    # Start ComfyUI
    if check_pid "$COMFYUI_PID_FILE"; then
        echo -e "${YELLOW}ComfyUI is already running (PID: $(cat "$COMFYUI_PID_FILE"))${NC}"
    else
        if [ -d "$COMFYUI_DIR" ]; then
            echo "Starting ComfyUI (Port 8188)..."
            cd "$COMFYUI_DIR"
            # Using direct python path instead of activating venv
            ARGS="--listen 0.0.0.0 --port 8188"
            nohup "$VENV_DIR/bin/python" main.py $ARGS &> "$COMFYUI_LOG" &
            echo $! > "$COMFYUI_PID_FILE"
            echo -e "${GREEN}ComfyUI started (PID: $!). Log: $COMFYUI_LOG${NC}"
            cd "$INSTALL_DIR" # Return to base
        else
            echo -e "${RED}Error: ComfyUI directory not found at $COMFYUI_DIR${NC}"
        fi
    fi
}

stop_services() {
    echo -e "${YELLOW}Stopping services...${NC}"

    # Stop ComfyUI
    if [ -f "$COMFYUI_PID_FILE" ]; then
        pid=$(cat "$COMFYUI_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Stopping ComfyUI (PID: $pid)..."
            kill "$pid"
            rm "$COMFYUI_PID_FILE"
            echo -e "${GREEN}ComfyUI stopped.${NC}"
        else
            echo -e "${YELLOW}ComfyUI PID file exists but process is not running. Cleaning up.${NC}"
            rm "$COMFYUI_PID_FILE"
        fi
    else
        echo "ComfyUI is not running."
    fi

    # Stop Image Browser
    if [ -f "$IMAGE_BROWSER_PID_FILE" ]; then
        pid=$(cat "$IMAGE_BROWSER_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Stopping Infinite Image Browser (PID: $pid)..."
            kill "$pid"
            rm "$IMAGE_BROWSER_PID_FILE"
            echo -e "${GREEN}Infinite Image Browser stopped.${NC}"
        else
            echo -e "${YELLOW}Image Browser PID file exists but process is not running. Cleaning up.${NC}"
            rm "$IMAGE_BROWSER_PID_FILE"
        fi
    else
        echo "Infinite Image Browser is not running."
    fi
}

status_services() {
    echo -e "${GREEN}Service Status:${NC}"

    # ComfyUI Status
    if check_pid "$COMFYUI_PID_FILE"; then
        echo -e "ComfyUI: ${GREEN}RUNNING${NC} (PID: $(cat "$COMFYUI_PID_FILE"))"
    else
        echo -e "ComfyUI: ${RED}STOPPED${NC}"
    fi

    # Image Browser Status
    if check_pid "$IMAGE_BROWSER_PID_FILE"; then
        echo -e "Image Browser: ${GREEN}RUNNING${NC} (PID: $(cat "$IMAGE_BROWSER_PID_FILE"))"
    else
        echo -e "Image Browser: ${RED}STOPPED${NC}"
    fi
}

case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 2
        start_services
        ;;
    status)
        status_services
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
