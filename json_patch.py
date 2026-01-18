import argparse
import json
import os
import sys

def patch_json(source_path, target_path):
    if not os.path.exists(source_path):
        print(f"Source file not found: {source_path}")
        return
    
    if not os.path.exists(target_path):
        print(f"Target file not found: {target_path}")
        return

    try:
        with open(source_path, 'r') as f:
            source_data = json.load(f)
        
        with open(target_path, 'r') as f:
            target_data = json.load(f)
            
        if 'models' in source_data and isinstance(source_data['models'], list):
            if 'models' not in target_data:
                target_data['models'] = []
            
            # Create a set of existing filenames to avoid duplicates
            existing_filenames = {m.get('filename') for m in target_data['models'] if 'filename' in m}
            
            count = 0
            for model in source_data['models']:
                filename = model.get('filename')
                if filename and filename not in existing_filenames:
                    target_data['models'].append(model)
                    existing_filenames.add(filename)
                    count += 1
                elif not filename:
                    # If no filename, maybe compare by name?
                    # For now, just add if no filename (unlikely for models)
                    target_data['models'].append(model)
                    count += 1
            
            print(f"Added {count} models from {source_path} to {target_path}")
            
            with open(target_path, 'w') as f:
                json.dump(target_data, f, indent=4)
        else:
            print("Source file does not contain a 'models' list.")
            
    except Exception as e:
        print(f"Error patching JSON: {e}")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, help="Source JSON file")
    parser.add_argument("--target", required=True, help="Target JSON file")
    args = parser.parse_args()
    
    patch_json(args.source, args.target)
