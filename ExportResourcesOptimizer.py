import os

godot_game_project_path = r"C:\Users\Joel\GodotGames\3d-game-test"
godot_game_project_export_presets_path = r"C:\Users\Joel\GodotGames\3d-game-test\export_presets.cfg"

export_mode_string_filter = 'export_filter="resources"' # only works with this mode
exported_files_to_exclude_start_filter = 'export_files=PackedStringArray('

with open (godot_game_project_export_presets_path, "r") as f:
    data = f.read()
    lines = data.split("\n")
    for line in lines:
        if export_mode_string_filter in line:
            export_files_exclude_mode = True
            break

all_files = []
all_files_to_include = []

def get_files_in_directory_recursive(directory):
    files = []
    for root, dirs, filenames in os.walk(directory):
        for filename in filenames:
            files.append(os.path.join(root, filename))
    return files

all_files = get_files_in_directory_recursive(godot_game_project_path)

def search_for_needed_files_within_scene_file(file_path):
     with open(file_path, "r") as f:
         for file_path in all_files:
             if 

for file in all_files:
    if file.endswith(".tscn"):
        with open(file, "r") as f:


# def search_gd_script_for_classes(script_content):
#     for class_name in classes_disabled_by_build_file:
#         class_not_save_to_disable = False
#         # valid cases
#         if "extends " + class_name in script_content:
#             class_not_save_to_disable = True
        
#         if " " + class_name + "." in script_content:
#             class_not_save_to_disable = True
        
#         if " " + class_name + "(" in script_content:
#            class_not_save_to_disable = True
        
#         if (": " + class_name + " " in script_content) or (":" + class_name + " " in script_content):
#             class_not_save_to_disable = True

#         if class_not_save_to_disable:
#             if not class_name in not_save_to_disable_classes:
#                 not_save_to_disable_classes.append(class_name)
#         else:
#             if not class_name in save_to_disable_classes:
#                 save_to_disable_classes.append(class_name)

# def search_resource_files_for_classes(tscn_content):
#     for class_name in classes_disabled_by_build_file:
#         class_not_save_to_disable = False
    
#         if 'type="' + class_name + '" ' in tscn_content:
#             class_not_save_to_disable = True
        
#         if class_name + "(" in tscn_content:
#             class_not_save_to_disable = True
        
#         if ": " + class_name in tscn_content:
#             class_not_save_to_disable = True

#     if class_not_save_to_disable:
#         if not class_name in not_save_to_disable_classes:
#             not_save_to_disable_classes.append(class_name)
#     else:
#         if not class_name in save_to_disable_classes:
#             save_to_disable_classes.append(class_name)
