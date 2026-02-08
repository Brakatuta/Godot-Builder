import os
import json

godot_game_project_path = r"C:\Users\Joel\GodotGames\Side Scroller"
godot_game_project_export_presets_path = r"C:\Users\Joel\GodotGames\Side Scroller\export_presets.cfg"

custom_build_file_path = os.path.join(os.path.dirname(__file__), "custom.build")

resources_and_scripts_to_ignore = []
classes_disabled_by_build_file = []

save_to_disable_classes = []
not_save_to_disable_classes = []

with open (godot_game_project_export_presets_path, "r") as f:
    data = f.read()
    lines = data.split("\n")
    for line in lines:
        if 'export_filter="exclude"' in line:
            next_line = lines[lines.index(line) + 1]
            next_line = next_line.replace("export_files=PackedStringArray(", "").replace(")", "").replace(" ", "").replace("/", "\\").replace('res:\\\\', godot_game_project_path + "\\")
            for asset in next_line.split(","):
                if asset.__contains__(".gd") or asset.__contains__(".tscn") or asset.__contains__(".tres"):
                    resources_and_scripts_to_ignore.append(asset.replace('"', ""))
            break

with open(custom_build_file_path, "r") as f:
    data = json.load(f)
    classes_disabled_by_build_file = data["disabled_classes"]

def search_gd_script_for_classes(script_content):
    for class_name in classes_disabled_by_build_file:
        class_not_save_to_disable = False
        # valid cases
        if "extends " + class_name in script_content:
            class_not_save_to_disable = True
        
        if " " + class_name + "." in script_content:
            class_not_save_to_disable = True
        
        if " " + class_name + "(" in script_content:
           class_not_save_to_disable = True
        
        if (": " + class_name + " " in script_content) or (":" + class_name + " " in script_content):
            class_not_save_to_disable = True

        if class_not_save_to_disable:
            if not class_name in not_save_to_disable_classes:
                not_save_to_disable_classes.append(class_name)
        else:
            if not class_name in save_to_disable_classes:
                save_to_disable_classes.append(class_name)

def search_resource_files_for_classes(tscn_content):
    for class_name in classes_disabled_by_build_file:
        class_not_save_to_disable = False
    
        if 'type="' + class_name + '" ' in tscn_content:
            class_not_save_to_disable = True
        
        if class_name + "(" in tscn_content:
            class_not_save_to_disable = True
        
        if ": " + class_name in tscn_content:
            class_not_save_to_disable = True

    if class_not_save_to_disable:
        if not class_name in not_save_to_disable_classes:
            not_save_to_disable_classes.append(class_name)
    else:
        if not class_name in save_to_disable_classes:
            save_to_disable_classes.append(class_name)

def search_for_classes_in_project_files():
    for root, dirs, files in os.walk(godot_game_project_path):
        for file in files:
            file_path = os.path.join(root, file)
            if file_path in resources_and_scripts_to_ignore:
                continue
            if file.endswith(".gd"):
                with open(file_path, "r") as f:
                    content = f.read()
                    search_gd_script_for_classes(content)
            elif file.endswith(".tscn") or file.endswith(".tres"):
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                    search_resource_files_for_classes(content)

search_for_classes_in_project_files()
print("Not save to disable classes:", not_save_to_disable_classes)

amount_disabled_classes_by_build_file = len(classes_disabled_by_build_file)

for class_name in not_save_to_disable_classes:
    classes_disabled_by_build_file.remove(class_name)

print("Removed {} classes from build file due to not being save to disable".format(amount_disabled_classes_by_build_file - len(classes_disabled_by_build_file)))

new_json_data = {}

with open(custom_build_file_path, "r") as f:
    new_json_data = json.load(f)
    new_json_data["disabled_classes"] = classes_disabled_by_build_file

print("Node" in classes_disabled_by_build_file)
    
with open(custom_build_file_path, "w") as f:
    json.dump(new_json_data, f)