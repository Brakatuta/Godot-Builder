import os
import secrets

script_dir = os.path.dirname(os.path.abspath(__file__))

hex_key = secrets.token_hex(32).upper()

file_path = os.path.join(script_dir, "godot.gdkey")
with open(file_path, "w") as f:
    f.write(hex_key)

# Ausgabe
print(f"godot.gdkey generated successfully: {hex_key}\n")