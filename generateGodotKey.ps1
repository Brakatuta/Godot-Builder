$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$bytes = [byte[]]::new(32)
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$hex = ($bytes | ForEach-Object { $_.ToString("X2") }) -join ""
Set-Content -Path "$script_dir\godot.gdkey" -Value $hex

Write-Host "godot.gdkey generated successfully: $hex" -ForegroundColor Green
write-host ""