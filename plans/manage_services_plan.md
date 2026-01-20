# Plan for `manage_services.sh`

This script will control the ComfyUI and Infinite Image Browser services, allowing them to be started, stopped, restarted, and checked for status. It mirrors the configuration found in `setup.sh`.

## Configuration Variables
(Derived strictly from `setup.sh`)
- `INSTALL_DIR`: `/workspace`
- `COMFYUI_DIR`: `$INSTALL_DIR/ComfyUI`
- `VENV_DIR`: `$INSTALL_DIR/venv`
- `IMAGE_BROWSER_DIR`: `$INSTALL_DIR/sd-webui-infinite-image-browsing`
- `IMAGE_BROWSER_VENV`: `$IMAGE_BROWSER_DIR/browser-env`

## Functions

### `check_status`
- Checks if the processes are running.
- Uses PID files (`comfyui.pid`, `image_browser.pid`) stored in `$INSTALL_DIR` to track processes.
- Verifies if the PID actually exists in the process table.

### `start_services`
- **Image Browser**:
  - Checks if already running.
  - Command: `nohup "$IMAGE_BROWSER_VENV/bin/python" app.py --port=7888 --host=0.0.0.0 &> "$INSTALL_DIR/image_browser.log" &`
  - Saves PID to `$INSTALL_DIR/image_browser.pid`.
- **ComfyUI**:
  - Checks if already running.
  - Command: `nohup python main.py --listen 0.0.0.0 --port 8188 &> "$INSTALL_DIR/comfyui.log" &` (Executed inside `$COMFYUI_DIR` with `$VENV_DIR` activated).
  - Saves PID to `$INSTALL_DIR/comfyui.pid`.

### `stop_services`
- Reads PIDs from files.
- Kills the processes using `kill`.
- Removes PID files.
- Handles cases where PID file exists but process is gone (stale file).

### `restart_services`
- Calls `stop_services`.
- Calls `start_services`.

## Usage
`./manage_services.sh [start|stop|restart|status]`
