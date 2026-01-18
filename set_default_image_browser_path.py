import sys
import os
import json
import time
import argparse
import sqlite3

def setup_default_path(path, project_path, mode="scanned", snapshot_name="Default View", db_name="iib.db"):
    # 1. Add project path to sys.path to import application modules
    if not os.path.exists(project_path):
        print(f"Error: Project path '{project_path}' does not exist.")
        sys.exit(1)
    
    sys.path.append(project_path)

    try:
        from scripts.iib.db.datamodel import DataBase
    except ImportError as e:
        print(f"Error: Could not import project modules from '{project_path}'.\nDetails: {e}")
        sys.exit(1)

    # 2. Configure DB Path
    # The app uses IIB_DB_PATH env var, or defaults to iib.db in CWD
    # We want it to be in the project directory usually
    db_path = os.path.join(project_path, db_name)
    os.environ["IIB_DB_PATH"] = db_path
    
    # 3. Initialize Database (Create Tables)
    # This is crucial for a fresh install
    DataBase.init()
    print(f"Database initialized at {DataBase.get_db_file_path()}")

    # 4. Perform Data Injection
    conn = DataBase.get_conn()
    cursor = conn.cursor()

    # Create Snapshot ID
    snapshot_id = str(int(time.time() * 1000))
    snapshot_key = f"workspace_snapshot_{snapshot_id}"

    # Construct Snapshot Data
    snapshot_data = {
        "id": snapshot_id,
        "name": snapshot_name,
        "tabs": [
            {
                "id": "default_tab",
                "key": "default_pane",
                "panes": [
                    {
                        "type": "local",
                        "name": "Local",
                        "key": "default_pane",
                        "path": path,
                        "mode": mode  # 'walk', 'scanned', or 'scanned-fixed'
                    }
                ]
            }
        ]
    }

    now = time.strftime('%Y-%m-%dT%H:%M:%S')

    # Insert Snapshot
    cursor.execute("""
        INSERT OR REPLACE INTO global_setting (name, setting_json, created_time, modified_time)
        VALUES (?, ?, ?, ?)
    """, (snapshot_key, json.dumps(snapshot_data), now, now))

    # Update Global Config to use Snapshot
    cursor.execute("SELECT setting_json FROM global_setting WHERE name = 'global'")
    row = cursor.fetchone()
    
    global_settings = json.loads(row[0]) if row else {}
    global_settings["defaultInitinalPage"] = snapshot_key

    cursor.execute("""
        INSERT OR REPLACE INTO global_setting (name, setting_json, created_time, modified_time)
        VALUES (?, ?, ?, ?)
    """, ("global", json.dumps(global_settings), now, now))

    conn.commit()
    conn.close()
    print(f"Successfully configured default path: {path} ({mode})")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("path", help="The absolute path to the images folder you want to browse")
    parser.add_argument("--project-path", required=True, help="Path to the sd-webui-infinite-image-browsing root directory")
    parser.add_argument("--mode", default="walk", choices=["walk", "scanned", "scanned-fixed"], help="Browsing mode")
    parser.add_argument("--db-name", default="iib.db", help="Name of the database file")
    
    args = parser.parse_args()

    setup_default_path(args.path, args.project_path, args.mode, snapshot_name="Default View", db_name=args.db_name)
