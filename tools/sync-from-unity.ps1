# Copies the shader folder from the Unity project into this repo (mirror, so deleted files are removed too).
param(
    [string]$Source = "D:\2026 Backup\Documents\Unity Projects\Ravens_Midnight\Assets\Ravens Midnight\Psychedelic Shaders"
)
$dest = Join-Path (Split-Path $PSScriptRoot -Parent) "Psychedelic Shaders"
if (-not (Test-Path $Source)) { throw "Source not found: $Source" }
robocopy $Source $dest /MIR /XD Library Temp /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
Write-Host "Synced $Source -> $dest"
