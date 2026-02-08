$env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:CC="clang"
$env:CXX="clang++"

$cpuThreads = (Get-ComputerInfo).CsNumberOfLogicalProcessors

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$jsonPath = Join-Path $scriptDir "configs.json"

# Read and convert the JSON content to a PowerShell object
$config = Get-Content -Path $jsonPath | ConvertFrom-Json

# Assign values from the JSON to variables
$godotPath = $config.godotPath
$binPath = $config.binPath
$gradleCacheFolder = $config.gradleCacheFolder

$godotVersion = $config.godotVersion

$disbaled_path_overrides = $config.disable_path_overrides

$buildwithLTO = $config.buildwithLTO

$buildwithLLVM = $config.buildwithLLVM

$supportArm32 = $config.supportArm32

$disable3DforTemplate = $config.disable3DforTemplate

$optimize = $config.optimize

$use_static_cpp = $config.use_static_cpp

$buildAndroidDebugTemplate = $config.buildAndroidDebugTemplate
$buildAndroidReleaseTemplate = $config.buildAndroidReleaseTemplate

$custom_modules_file_windows = $config.custom_modules_file_windows
$custom_modules_file_linux = $config.custom_modules_file_linux
$custom_modules_file_mobile = $config.custom_modules_file_mobile

$custom_build_profile_windows = $config.custom_build_profile_windows
$custom_build_profile_linux = $config.custom_build_profile_linux
$custom_build_profile_mobile = $config.custom_build_profile_mobile

$env:SCRIPT_AES256_ENCRYPTION_KEY = $config.AES_encryption_key

if ($config.amountThreads -lt $cpuThreads) {
    $cpuThreads = $config.amountThreads
}

function getFunctionExecutionTimeString {
    param ([datetime]$startTime)
    $endTime = Get-Date
    $elapsed = $endTime - $startTime
    return "{0:00}:{1:00}:{2:00}" -f $elapsed.Hours, $elapsed.Minutes, $elapsed.Seconds
}

function BuildWindowsEditor {
    $startTime = Get-Date

    Write-Host "Building Windows Editor..." -ForegroundColor Green

    # default build (Windows using minGW)
    Set-Location $godotPath
    scons platform=windows use_mingw=yes use_llvm=yes use_cvtt=yes -j($cpuThreads)

    Write-Host "Windows Editor build finished in $(getFunctionExecutionTimeString $startTime)!" -ForegroundColor Green
}

function BuildWindowsTemplates {
    if ($buildwithLTO) {
        Write-Host "Building Windows Templates with Link Time Optimization..." -ForegroundColor Green
    } else {
        Write-Host "Building Windows Templates..." -ForegroundColor Green
    }

    Set-Location $godotPath

    $startTime = Get-Date
    
    if ($buildwithLTO) {
        scons platform=windows disable_path_overrides=$($disbaled_path_overrides) use_mingw=yes use_llvm=$($buildwithLLVM) use_cvtt=yes production=yes profile=$($custom_modules_file_windows) build_profile=$($custom_build_profile_windows) disable_3d=$($disable3DforTemplate) lto=full debug_symbols=no tools_enabled=no optimize=$($optimize) use_static_cpp=$($use_static_cpp) target=template_release arch=x86_64 -j($cpuThreads)
    } else {
        scons platform=windows disable_path_overrides=$($disbaled_path_overrides) use_mingw=yes use_llvm=$($buildwithLLVM) use_cvtt=yes production=yes profile=$($custom_modules_file_windows) build_profile=$($custom_build_profile_windows) disable_3d=$($disable3DforTemplate) debug_symbols=no tools_enabled=no optimize=$($optimize) use_static_cpp=$($use_static_cpp) target=template_release arch=x86_64 -j($cpuThreads)
    }
    
    Write-Host "Windows Release Template build finished in $(getFunctionExecutionTimeString $startTime)!" -ForegroundColor Green

    $startTime = Get-Date

    scons platform=windows disable_path_overrides=$($disbaled_path_overrides) use_mingw=yes use_llvm=$($buildwithLLVM) use_cvtt=yes profile=$($custom_modules_file_windows) build_profile=$($custom_build_profile_windows) disable_3d=$($disable3DforTemplate) target=template_debug use_static_cpp=$($use_static_cpp) arch=x86_64 -j($cpuThreads)

    Write-Host "Windows Debug Template build finished in $(getFunctionExecutionTimeString $startTime)!" -ForegroundColor Green
}

 function BuildLinuxTemplates {
    # fix dubios owner ship error run: git config --global --add safe.directory /mnt/c/Users/user/.../godot

    # Force Ubuntu
    $distro = "Ubuntu"
    $flagFile = Join-Path $PSScriptRoot ".wsl_deps_installed"

    # Required Linux packages
    $packages = "build-essential scons pkg-config libx11-dev libxcursor-dev libxinerama-dev libxrandr-dev libxi-dev libasound2-dev libpulse-dev libudev-dev libgl1-mesa-dev libglu1-mesa-dev libwayland-dev libxkbcommon-dev"

    # Dependency Check
    if (-not (Test-Path $flagFile)) {
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            Exit
        }

        Write-Host "Checking Ubuntu dependencies..." -ForegroundColor Cyan

        # Explicitly calling Ubuntu as root
        wsl -d $distro -u root sh -c "apt-get update && apt-get install -y $packages"

        if ($LASTEXITCODE -eq 0) {
            New-Item -Path $flagFile -ItemType File -Force | Out-Null
        } else {
            Write-Error "Failed to install packages in Ubuntu. Is Ubuntu working? (Try running 'wsl -d Ubuntu' manually)"
            return
        }
    }

    # Path Conversion
    $drive = $godotPath.Substring(0,1).ToLower()
    $restOfPath = $godotPath.Substring(2).Replace('\', '/')
    $wslPath = "/mnt/$drive$restOfPath"

    Write-Host "Navigating to: $wslPath" -ForegroundColor Gray

    # SCons Argument Logic
    function Get-SconsArgs($target, $isLto) {
        $sArgs = "platform=linuxbsd target=$target arch=x86_64 -j$cpuThreads use_static_cpp=$use_static_cpp disable_3d=$disable3DforTemplate "
        $sArgs += "vulkan=yes opengl3=yes " # force modern graphics APIs
        # Helper to convert Windows path to WSL path for build profiles
        function Convert-ToWslPath($winPath) {
            if ($winPath) {
                $pDrive = $winPath.Substring(0,1).ToLower()
                $pRest = $winPath.Substring(2).Replace('\', '/')
                return "/mnt/$pDrive$pRest"
            }
            return $null
        }

        # Convert the profile paths for Linux consumption
        if ($custom_modules_file_linux) {
            $wslProfile = Convert-ToWslPath $custom_modules_file_linux
            $sArgs += "profile=`"$wslProfile`" "
        }

        # if ($custom_build_profile_linux) {
        #     $wslBuildProfile = Convert-ToWslPath $custom_build_profile_linux
        #     $sArgs += "build_profile=`"$wslBuildProfile`" "
        # }

        if ($target -eq "template_release") {
            $sArgs += "production=yes debug_symbols=no tools_enabled=no optimize=$optimize "
            if ($isLto) { $sArgs += "lto=full " }
        }
        return $sArgs        
    }

    # Build Execution
    $startTime = Get-Date

    # Trust the directory in Git
    wsl -d $distro -u root git config --global --add safe.directory "$wslPath"

    $releaseArgs = Get-SconsArgs "template_release" $buildwithLTO

    Write-Host "Running Linux Release Build in WSL (Ubuntu)..." -ForegroundColor Green
    # Using single quotes for sh -c protects the internal double quotes in $releaseArgs
    wsl -d $distro -u root --cd "$wslPath" sh -c "export SCRIPT_AES256_ENCRYPTION_KEY=$($config.AES_encryption_key) && scons $releaseArgs"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Linux Release build failed."
        return
    }

    $startTime = Get-Date
    $debugArgs = Get-SconsArgs "template_debug" $false

    Write-Host "Running Linux Debug Build in WSL (Ubuntu)..." -ForegroundColor Green
    wsl -d $distro -u root --cd "$wslPath" sh -c "export SCRIPT_AES256_ENCRYPTION_KEY=$($config.AES_encryption_key) && scons $debugArgs"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Linux Debug build failed."
        return
    }

    Write-Host "Linux Templates built successfully!" -ForegroundColor Green
}
function cleanAndroidGradleCaches {
    Write-Host "Clearing Gradle Cache..." -ForegroundColor Green
    # Check if the folder exists
    if (Test-Path -Path $gradleCacheFolder) {
        try {
            # Delete all files and subfolders in the folder
            Get-ChildItem -Path $gradleCacheFolder -Recurse | Remove-Item -Recurse -Force
            Write-Host "All files and subfolders within '$gradleCacheFolder' have been deleted successfully." -ForegroundColor Green
        } catch {
            Write-Host "An error occurred while attempting to delete items in '$gradleCacheFolder'. $_" -ForegroundColor Red
        }
    } else {
        Write-Host "The folder '$gradleCacheFolder' does not exist." -ForegroundColor Yellow
    }
}

function BuildAndroidTemplates {
    # needed for godot android: https://github.com/godotengine/godot-swappy/releases (swappy-frame-pacing = folder name in thirdparty dir)

    Stop-Process -Name "java" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "adb" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "jdk" -Force -ErrorAction SilentlyContinue
    Get-Process | Where-Object { $_.ProcessName -match "java|gradle" } | Stop-Process -Force

    if ($buildwithLTO) {
        Write-Host "Building Android Templates with Link Time Optimization..." -ForegroundColor Green
    } else {
        Write-Host "Building Android Templates..." -ForegroundColor Green
    }
    
    Set-Location $godotPath

    $startTime = Get-Date

    if ($buildAndroidReleaseTemplate) {
        if ($buildwithLTO) {
            if ($supportArm32) {
                scons platform=android target=template_release production=yes profile=$($custom_modules_file_mobile) build_profile=$($custom_build_profile_mobile) disable_3d=$($disable3DforTemplate) lto=full debug_symbols=no tools_enabled=no optimize=$($optimize) arch=arm32 CC=clang CXX=clang++ -j($cpuThreads)
            }
            scons platform=android target=template_release production=yes profile=$($custom_modules_file_mobile) build_profile=$($custom_build_profile_mobile) disable_3d=$($disable3DforTemplate) lto=full debug_symbols=no tools_enabled=no optimize=$($optimize) arch=arm64 CC=clang CXX=clang++ -j($cpuThreads) generate_apk=yes
        } else {
            if ($supportArm32) {
                scons platform=android target=template_release production=yes profile=$($custom_modules_file_mobile) build_profile=$($custom_build_profile_mobile) disable_3d=$($disable3DforTemplate) debug_symbols=no tools_enabled=no optimize=$($optimize) arch=arm32 CC=clang CXX=clang++ -j($cpuThreads)
            }
            scons platform=android target=template_release production=yes profile=$($custom_modules_file_mobile) build_profile=$($custom_build_profile_mobile) disable_3d=$($disable3DforTemplate) debug_symbols=no tools_enabled=no optimize=$($optimize) arch=arm64 CC=clang CXX=clang++ -j($cpuThreads) generate_apk=yes
        }
        
        Write-Host "Android Release Template build finished in $(getFunctionExecutionTimeString $startTime)!" -ForegroundColor Green
    }

    $startTime = Get-Date
    
    if ($buildAndroidDebugTemplate) {
        if ($supportArm32) {
            scons platform=android target=template_debug disable_3d=$($disable3DforTemplate) debug_symbols=yes arch=arm32 CC=clang CXX=clang++ -j($cpuThreads)
        }
        scons platform=android target=template_debug disable_3d=$($disable3DforTemplate) debug_symbols=yes arch=arm64 CC=clang CXX=clang++ -j($cpuThreads) generate_apk=yes
        
        Write-Host "Android Debug Template build finished in $(getFunctionExecutionTimeString $startTime)!" -ForegroundColor Green
    }
}

function CreateAndroidGradleBuildFolder {
    $startTime = Get-Date

    Write-Host "Creating Android Gradle Build Folder..." -ForegroundColor Green

    Set-Location $binPath

    $zipFile = $binPath + "android_source.zip"
    $androidDir = $binPath + "android"
    $buildVersionFile = Join-Path -Path $androidDir -ChildPath ".build_version"
    $gdignoreFile = Join-Path -Path $androidDir -ChildPath ".gdignore"
    $buildDir = Join-Path -Path $androidDir -ChildPath "build"

    # delete old android directory
    if (Test-Path -Path $androidDir) {
      Remove-Item -Path $androidDir -Recurse -Force
    }

    # Create the android directory if it doesn't exist
    if (!(Test-Path -Path $androidDir)) {
      New-Item -Path $androidDir -ItemType Directory
    }

    # Create the build directory if it doesn't exist
    if (!(Test-Path -Path $buildDir)) {
      New-Item -Path $buildDir -ItemType Directory
    }

    # Extract the zip file to the build directory
    Expand-Archive -Path $zipFile -DestinationPath $buildDir -Force

    New-Item -Path $buildVersionFile -ItemType File
    Set-Content -Path $buildVersionFile -Value $godotVersion

    New-Item -Path $gdignoreFile -ItemType File

    Write-Host "Android Gradle Build Folder created in $(getFunctionExecutionTimeString $startTime)!" -ForegroundColor Green
}

function CleanLinuxBuildFiles {
    Write-Host "Cleaning Linux artifacts..." -ForegroundColor Gray
    scons --clean platform=linuxbsd

    # Clean Linux via WSL
    $distro = "Ubuntu"
    # Convert path for WSL
    $drive = $godotPath.Substring(0,1).ToLower()
    $restOfPath = $godotPath.Substring(2).Replace('\', '/')
    $wslPath = "/mnt/$drive$restOfPath"

    Write-Host "Cleaning Linux artifacts in WSL..." -ForegroundColor Gray
    wsl -d $distro -u root --cd "$wslPath" sh -c "rm -rf bin/obj && scons --clean platform=linuxbsd"

    # Remove persistent SCons DB files and object folders on Windows
    $itemsToForceDelete = ".sconsign5.dblite", "bin/obj"
    foreach ($item in $itemsToForceDelete) {
        $fullPath = Join-Path $godotPath $item
        if (Test-Path $fullPath) {
            Write-Host "Removing $item..." -ForegroundColor Gray
            Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function CleanGodotBuildFiles {
    Write-Host "Cleaning Godot build artifacts..." -ForegroundColor Yellow
    Set-Location $godotPath
    
    Write-Host "Cleaning Scons..." -ForegroundColor Yellow
    scons --clean
    Write-Host "Cleaning Windows artifacts..." -ForegroundColor Gray
    scons --clean platform=windows

    CleanLinuxBuildFiles

    Write-Host "Cleaning Android artifacts..." -ForegroundColor Gray
    scons --clean platform=android
    Remove-Item .sconsign5.dblite

    Write-Host "Cleanup finished!" -ForegroundColor Green
}

function Initialize {
    Write-Host "#   _____ ___________ _____ _____  ______ _   _ _____ _    ______ ___________ 
#  |  __ \  _  |  _  \  _  |_   _| | ___ \ | | |_   _| |   |  _  \  ___| ___ \
#  | |  \/ | | | | | | | | | | |   | |_/ / | | | | | | |   | | | | |__ | |_/ /
#  | | __| | | | | | | | | | | |   | ___ \ | | | | | | |   | | | |  __||    / 
#  | |_\ \ \_/ / |/ /\ \_/ / | |   | |_/ / |_| |_| |_| |___| |/ /| |___| |\ \ 
#   \____/\___/|___/  \___/  \_/   \____/ \___/ \___/\_____/___/ \____/\_| \_|
"
    Write-Host "    _____             _          ___                  _____                     
#  |     |___ ___ ___| |_ ___   |  _|___ ___ _____   |   __|___ _ _ ___ ___ ___ 
#  |   --|  _| -_| .'|  _| -_|  |  _|  _| . |     |  |__   | . | | |  _|  _| -_|
#  |_____|_| |___|__,|_| |___|  |_| |_| |___|_|_|_|  |_____|___|___|_| |___|___|
"                                                    
    Write-Host "Make sure you use the right configurations! You can change them in configs.json" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------------------------------"
    Write-Host "Select an action:"
    Write-Host "1.  Clean Scons" -ForegroundColor Yellow
    Write-Host "2.  Clean Android Gradle Caches" -ForegroundColor Yellow
    Write-Host "3.  Build Editor" -ForegroundColor Cyan
    Write-Host "4.  Build Templates" -ForegroundColor Green
    Write-Host "5.  Build Windows and Linux Templates only" -ForegroundColor Green
    Write-Host "6.  Build Windows Templates only" -ForegroundColor Green
    Write-Host "7.  Build Linux Templates only" -ForegroundColor Green
    Write-Host "8.  Clean Linux Templates" -ForegroundColor Yellow
    Write-Host "9.  Build only Android Templates" -ForegroundColor Green
    Write-Host "10. Create Android Gradle Build Folder" -ForegroundColor Green
    Write-Host "11. Exit Builder" -ForegroundColor Red

    $choice = Read-Host "Enter a valid option between 1 and 11"

    switch ($choice) {
        1 {
            CleanGodotBuildFiles
            Initialize
        }
        2 {
            Write-Host "Cleaning Android Gradle Caches..." -ForegroundColor Yellow
            cleanAndroidGradleCaches
            Initialize
        }
        3 {
            Write-Host "Building Editor..." -ForegroundColor Cyan
            BuildWindowsEditor
            Initialize
        }
        4 { 
            Write-Host "Building Templates..." -ForegroundColor Green
            BuildWindowsTemplates
            BuildLinuxTemplates
            BuildAndroidTemplates
            CreateAndroidGradleBuildFolder
            Initialize
        }
        5 {
            Write-Host "Building Windows and Linux Templates..." -ForegroundColor Green
            BuildWindowsTemplates
            BuildLinuxTemplates
            Initialize
        }
        6 {	
            Write-Host "Building only Windows Templates..." -ForegroundColor Green
            BuildWindowsTemplates
            Initialize
        }
        7 {
            Write-Host "Building only Linux Templates..." -ForegroundColor Green
            BuildLinuxTemplates
            Initialize
        }
        8 {
            CleanLinuxBuildFiles
            Write-Host "Cleanup finished!" -ForegroundColor Green
            Initialize
        }
        9 {
            Write-Host "Building only Android Templates..." -ForegroundColor Green
            BuildAndroidTemplates
            Initialize
        }
        10 {
            Write-Host "Creating Android Gradle Build Folder..." -ForegroundColor Green
            CreateAndroidGradleBuildFolder
            Initialize
        }
        11 {
            Write-Host "Exiting Builder..." -ForegroundColor Red
            exit
        }
        default { 
            Write-Host "Invalid choice. Please try again."-ForegroundColor Yellow
            Initialize
        }
    }
}

Initialize

write-host ""