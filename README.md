# Godot Engine Custom Build System

A powerful PowerShell-based automation framework for building Godot Engine and export templates from source with fine-grained control over compilation settings.

![Godot Version](https://img.shields.io/badge/Godot-4.6.stable-blue)
![Platform](https://img.shields.io/badge/Platforms-Windows%20%7C%20Linux%20%7C%20Android-green)

## 🎯 Overview

This build system streamlines the process of compiling Godot Engine and custom export templates for multiple platforms. All compilation settings are controlled through a simple JSON configuration file, eliminating the need to modify build scripts.

**Key Features:**
- ✅ **Single-file configuration** - All settings in `configs.json`
- ✅ **Multi-platform support** - Windows, Linux, and Android builds
- ✅ **Custom modules & build profiles** - Per-platform customization
- ✅ **Performance optimization** - LTO, LLVM, multi-threaded compilation
- ✅ **Android Gradle automation** - Auto-creates build folders
- ✅ **Interactive menu system** - User-friendly PowerShell UI
- ✅ **Encryption key generation** - Built-in GDScript encryption support
- ✅ **WSL integration** - Native Linux builds on Windows

---

## 📋 Prerequisites

### System Requirements
- **Windows 10/11** with PowerShell 5.0+
- **16+ GB RAM** (32 GB recommended for multi-platform builds)
- **16+ GB free disk space** for builds and caches
- **8+ CPU cores** recommended (configurable in settings)

### Required Software

#### For Windows, Linux and Android
- [Godot Engine source](https://github.com/godotengine/godot)
- [SCons](https://scons.org/) 4.0+
- [LLVM/Clang](https://llvm.org/) (or MinGW)
- Python 3.8+
- Git

#### Windows Specific
- MinGW or MSVC toolchain
- Visual Studio Build Tools (optional)

#### Linux Specific (via WSL2)
- Windows Subsystem for Linux 2 (WSL2)
- Ubuntu 20.04 LTS or newer in WSL
- The script auto-installs build dependencies (more infos can be found here: https://docs.godotengine.org/en/4.4/contributing/development/compiling/compiling_for_linuxbsd.html):
  ```
  build-essential scons pkg-config libx11-dev libxcursor-dev 
  libxinerama-dev libxrandr-dev libxi-dev libasound2-dev libpulse-dev 
  libudev-dev libgl1-mesa-dev libglu1-mesa-dev libwayland-dev libxkbcommon-dev
  ```

#### Android Specific
- Android NDK (r23 or newer)
- Android SDK (API level 33+)
- Java Development Kit (JDK 11+)
- Gradle

---

## 🚀 Quick Start

### 1. Initial Setup

```powershell
# Clone or prepare your Godot source
git clone https://github.com/godotengine/godot.git
cd godot

# Clone/extract the builder scripts into your project
# Place all files in: GodotBuilder/ directory
```

### 2. Configure `configs.json`

Edit `configs.json` with your paths and build preferences:

```json
{
    "godotPath": "C:\\Path\\To\\Godot\\Source\\",
    "binPath": "C:\\Path\\To\\Godot\\Source\\bin\\",
    "godotVersion": "4.6.stable.Custom",
    "amountThreads": 16,
    "buildwithLTO": true,
    "buildwithLLVM": true,
    "buildAndroidDebugTemplate": true,
    "buildAndroidReleaseTemplate": true
    ...
}
```

### 3. Run the Builder

```powershell
# Running as Administrator is required for WSL dependency installation
# You can also use the run.bat file to automaticly start the tool within a powershell window
powershell -ExecutionPolicy Bypass -File "GodotBuilder.ps1"
```

Select from the interactive menu to build, clean, or manage your templates.

### 4. Optional: Generate Encryption Key

```powershell
powershell -ExecutionPolicy Bypass -File "generateGodotKey.ps1"
```

This creates `godot.gdkey` for GDScript encryption.

---

## ⚙️ Configuration Reference

### `configs.json` - Complete Guide

#### Paths
```json
"godotPath": "C:\\Users\\You\\Projects\\GodotProjects\\Godot4.6\\godot\\",
"binPath": "C:\\Users\\You\\Projects\\GodotProjects\\Godot4.6\\godot\\bin\\",
"gradleCacheFolder": "C:\\Users\\You\\.gradle\\caches"
```
Set these to your Godot source directory, binary output directory, and Gradle cache location.

#### Build Version
```json
"godotVersion": "4.6.stable.Custom"
```
Used to label built binaries and templates.

#### Compilation Options
```json
"amountThreads": 16,              // CPU threads for parallel compilation (0 = auto-detect)
"buildwithLTO": true,             // Link-Time Optimization (slower build, faster exe)
"buildwithLLVM": true,            // Use LLVM/Clang instead of MinGW
"use_all_debug_symbols": false,   // Include all debug symbols in template debug builds
"use_static_cpp": "yes",          // Statically link C++ runtime (recommended)
"optimize": "speed"               // Optimize for "speed" or "size" (speed is usualy the better option for release builds)
```

#### Module Customization
```json
"build_with_custom_windows_modules": false,
"build_with_custom_windows_build_profile": false,
"custom_modules_file_windows": "path/to/custom.py",
"custom_build_profile_windows": "path/to/custom.build"
```
Enable per-platform custom modules and build profiles (example files included).

#### Feature Flags
```json
"disable3DforTemplate": "no",     // Remove 3D support (lighter templates)
"disable_path_overrides": "no"    // Disable path overrides in build
```

#### Android Specific
```json
"buildAndroidDebugTemplate": true,
"buildAndroidReleaseTemplate": true,
"AES_encryption_key": "your generated key"
```

---

## 🛠️ Menu Options

Run `GodotBuilder.ps1` to access the interactive menu:

```
1.  Clean Scons               → Remove all build artifacts (slow, full clean)
2.  Clean Android Gradle      → Clear Gradle cache (for Android rebuilds)
3.  Build Editor              → Build the Windows Godot Editor
4.  Build Templates           → Build ALL templates in one go (Windows, Linux, Android)
5.  Build Win + Linux Only    → Skip Android
6.  Build Windows Only        → Windows templates only
7.  Build Linux Only          → Linux templates (via WSL2)
8.  Clean Linux Templates     → Clean Linux artifacts in WSL
9.  Build Android Only        → Android templates only
10. Create Android Gradle     → Generate Gradle build folder
11. Exit Builder              → Quit the application
```

---

## 📁 Platform-Specific Customization

### Module Customization Files

The builder supports per-platform custom module configs:

#### `custom.py` (Module Disabling)
Controls which Godot modules are compiled in:

```python
# Disable physics (reduce binary size)
module_bullet_enabled = "no"
module_godot_physics_3d_enabled = "no"

# Keep essential rendering
module_csg_enabled = "yes"
module_video_player_enabled = "yes"
```

**Included Examples:**
- `windows_custom.py` - Windows optimizations
- `linux_custom.py` - Linux optimizations
- `android_custom.py` - Mobile optimizations

#### `custom.build` (Build Profile)
Fine-tune compiler flags and advanced options:

```scons
# Compiler optimizations
ccflags = "-O3 -march=native"

# Feature flags
debug_symbols = "no"
lto = "full"
```

---

## 🔧 Common Workflows

### Build Lightweight Mobile Templates
```json
{
    "disable3DforTemplate": "yes",
    "buildAndroidDebugTemplate": true,
    "buildAndroidReleaseTemplate": true,
    "build_with_custom_mobile_modules": true,
    "custom_modules_file_mobile": "path/to/android_custom.py"
}
```

### Build Full-Featured Desktop
```json
{
    "buildwithLTO": true,
    "buildwithLLVM": true,
    "optimize": "speed",
    "use_all_debug_symbols": false,
    "amountThreads": 16
}
```

### Debug Build with all Symbols
```json
{
    "use_all_debug_symbols": true,
    "optimize": "size",
    "buildwithLTO": false
}
```

### Fastest Development Build
```json
{
    "buildwithLTO": false,
    "buildwithLLVM": false,
    "amountThreads": 16,
    "optimize": "size"
}
```

---

## 🔐 Encryption Key Management

### Generate a New Encryption Key

```powershell
.\generateGodotKey.ps1
```

Creates `godot.gdkey` containing a 256-bit AES key in hex format.

### Use in Godot Projects

1. Place `godot.gdkey` in your project's root
2. In Project Settings → Debug → GDScript:
   - Set "Encryption Key" to the key value
3. Export builds will encrypt GDScript bytecode

---

## 📊 Output Structure

After building, binaries and templates are organized as:

```
godot/bin/
├── godot.windows.editor.x86_64.exe
├── godot.windows.template_release.x86_64.exe
├── godot.windows.template_debug.x86_64.exe
├── godot.linuxbsd.template_release.x86_64
├── godot.linuxbsd.template_debug.x86_64
├── android/
│   ├── godot-lib.release.aar
│   ├── godot-lib.debug.aar
│   └── build/
│       └── gradle/...
└── android_source.zip
```

Import these into your Godot project:
- **Editor**: Use directly for daily development
- **Templates**: `Project → Export → Add → Select template binaries`
- **Android**: Use Gradle folder for custom APK builds

---

## ⚠️ Troubleshooting

### Build Fails on Linux (WSL)

```powershell
# Error: Permission denied or ownership issues
git config --global --add safe.directory /mnt/c/Users/YourName/.../godot

# Ubuntu dependencies not installing
wsl -d Ubuntu -u root apt-get update
wsl -d Ubuntu -u root apt-get install build-essential scons [...]
```

### SCons Cache Corruption

```powershell
# Full clean of build artifacts
scons --clean

# Delete persistent database
Remove-Item .sconsign5.dblite
Remove-Item bin/obj -Recurse -Force
```

### Android Build Errors

```powershell
# Clear Gradle cache (option 2 in menu)
rm C:\Users\YourName\.gradle\caches -Recurse -Force

# Regenerate build folder (option 10 in menu)
```

### Out of Disk Space

- Check `binPath` directory size: `[io.path]::GetDirectorySize("path")`
- Clear `gradleCacheFolder` if not in use
- Consider moving builds to external SSD

### Module Not Found

Verify `custom.py` paths in `configs.json` are correct and files exist.

---

## 🔄 Updating Godot Source

When updating to a new Godot version:

```powershell
# 1. Update godotVersion in configs.json
"godotVersion": "4.7.0"

# 2. Clean old builds
# Menu option 1: Clean Scons

# 3. Pull latest source
cd $godotPath
git pull origin master

# 4. Rebuild templates
# Menu option 4: Build Templates
```

---

## 📚 Advanced Topics

### Custom Build Profiles

Create `custom.build` for advanced SCons options to exclude components you definetly don not need.
Usualy this is not necessary but if you are aiming for size for example it can be usefull.
This can be verry test-intensive on a bigger project.
Always make sure you did not disable an important node, class or module before compiling!

### Module Disabling Strategy

Trim down templates by disabling unused modules:

```python
# 3D-only game (disable 2D-specific modules)
module_gridmap_enabled = "no"
module_navigation_enabled = "no"

# 2D-only game (disable 3D-specific modules)
module_bullet_enabled = "no"          # 3D physics
module_xatlas_unwrap_enabled = "no"   # 3D UV unwrapping
```

---

## 📖 Related Resources

- **Godot Docs**: https://docs.godotengine.org/
- **Compiling Godot**: https://docs.godotengine.org/en/stable/development/compiling/
- **SCons Documentation**: https://scons.org/doc/
- **WSL Setup**: https://docs.microsoft.com/en-us/windows/wsl/

---

## 📝 License

This build system is provided as-is. Godot Engine itself is licensed under the MIT License.

---

## 💡 Tips & Best Practices

1. **Start with standard build** before tweaking LTO/LLVM settings
2. **Use SSD** for Godot source and builds (massive speed improvement)
3. **Monitor disk space** during initial builds (can grow 16+ GB in some cases)
4. **Backup configurations** before experimenting with module changes
5. **Test templates** in a small project before production use
6. **Use WSL2** for Linux builds instead of dual-booting
7. **Enable LTO** only after confirming stable builds
8. **Keep custom.py** files under version control

---

## ❓ FAQ

**Q: Can I use MinGW instead of LLVM?**
A: Yes, set `"buildwithLLVM": false` in configs.json.

**Q: Do I need WSL2 to build Linux templates?**
A: Yes, the builder uses WSL2 Ubuntu for native Linux compilation on Windows.

**Q: How do I reduce template size?**
A: Use `custom.py` to disable unused modules and set `"optimize": "size"`.

**Q: Can I build for ARM64?**
A: Yes, modify the SCons arguments in the script to include `arch=arm64`.

**Q: How often should I clean build artifacts?**
A: Only when updating Godot version or drastically changing settings. Incremental builds are faster.

---

**Happy Building! 🎮**
