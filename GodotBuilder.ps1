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
$buildwithLTO = $config.buildwithLTO
$disable3DforTemplate = $config.disable3DforTemplate
$buildAndroidDebugTemplate = $config.buildAndroidDebugTemplate
$buildAndroidReleaseTemplate = $config.buildAndroidReleaseTemplate

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
    scons platform=windows use_mingw=yes use_cvtt=yes -j($cpuThreads)

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
        scons platform=windows use_mingw=yes use_cvtt=yes disable_3d=$($disable3DforTemplate) use_lto=yes debug_symbols=no optimize=speed use_static_cpp=yes target=template_release arch=x86_64 -j($cpuThreads)
    } else {
        scons platform=windows use_mingw=yes use_cvtt=yes disable_3d=$($disable3DforTemplate) target=template_release arch=x86_64 -j($cpuThreads)
    }
    
    Write-Host "Windows Release Template build finished in $(getFunctionExecutionTimeString $startTime)!" -ForegroundColor Green

    $startTime = Get-Date
    
    scons platform=windows use_mingw=yes use_cvtt=yes disable_3d=$($disable3DforTemplate) target=template_debug arch=x86_64 -j($cpuThreads)
    
    Write-Host "Windows Debug Template build finished!" -ForegroundColor Green
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
            scons platform=android use_mingw=yes target=template_release disable_3d=$($disable3DforTemplate) use_lto=yes debug_symbols=no optimize=speed no_cache=yes arch=arm32 CC=clang CXX=clang++ -j($cpuThreads)
            scons platform=android use_mingw=yes target=template_release disable_3d=$($disable3DforTemplate) use_lto=yes debug_symbols=no optimize=speed no_cache=yes arch=arm64 CC=clang CXX=clang++ -j($cpuThreads) generate_apk=yes
        } else {
            scons platform=android use_mingw=yes target=template_release disable_3d=$($disable3DforTemplate) debug_symbols=no no_cache=yes arch=arm32 CC=clang CXX=clang++ -j($cpuThreads)
            scons platform=android use_mingw=yes target=template_release disable_3d=$($disable3DforTemplate) debug_symbols=no no_cache=yes arch=arm64 CC=clang CXX=clang++ -j($cpuThreads) generate_apk=yes
        }
        
        Write-Host "Android Release Template build finished in $(getFunctionExecutionTimeString $startTime)!" -ForegroundColor Green
    }

    $startTime = Get-Date
    
    if ($buildAndroidDebugTemplate) {
        scons platform=android use_mingw=yes target=template_debug disable_3d=$($disable3DforTemplate) debug_symbols=yes no_cache=yes arch=arm32 CC=clang CXX=clang++ -j($cpuThreads)
        scons platform=android use_mingw=yes target=template_debug disable_3d=$($disable3DforTemplate) debug_symbols=yes no_cache=yes arch=arm64 CC=clang CXX=clang++ -j($cpuThreads) generate_apk=yes
        
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
    Set-Content -Path $buildVersionFile -Value "4.4.stable"

    New-Item -Path $gdignoreFile -ItemType File

    Write-Host "Android Gradle Build Folder created in $(getFunctionExecutionTimeString $startTime)!" -ForegroundColor Green
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
    Write-Host "1. Clean Scons" -ForegroundColor Yellow
    Write-Host "2. Clean Android Gradle Caches" -ForegroundColor Yellow
    Write-Host "3. Build Editor" -ForegroundColor Cyan
    Write-Host "4. Build Templates" -ForegroundColor Green
    Write-Host "5. Build Windows Templates only" -ForegroundColor Green
    Write-Host "6. Build only Android Templates" -ForegroundColor Green
    Write-Host "7  Create Android Gradle Build Folder" -ForegroundColor Green
    Write-Host "8. Exit Builder" -ForegroundColor Red

    $choice = Read-Host "Enter a valid option between 1 and 8"

    switch ($choice) {
        1 {
            Write-Host "Cleaning Scons..." -ForegroundColor Yellow
            Set-Location $godotPath
            scons --clean
            scons --clean platform=windows
            scons --clean platform=android
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
            BuildAndroidTemplates
            CreateAndroidGradleBuildFolder
            Initialize
        }
        5 {	
            Write-Host "Building only Windows Templates..." -ForegroundColor Green
            BuildWindowsTemplates
            Initialize
        }
        6 {
            Write-Host "Building only Android Templates..." -ForegroundColor Green
            BuildAndroidTemplates
            Initialize
        }
        7 {
            Write-Host "Creating Android Gradle Build Folder..." -ForegroundColor Green
            CreateAndroidGradleBuildFolder
            Initialize
        }
        8 {
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