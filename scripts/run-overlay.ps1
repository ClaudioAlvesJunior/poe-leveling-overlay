$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$candidates = @(
    $env:POE_OVERLAY_AHK
    (Join-Path $env:ProgramFiles 'AutoHotkey\AutoHotkeyU64.exe')
    (Join-Path $env:ProgramFiles 'AutoHotkey\v1.1\AutoHotkeyU64.exe')
)
$interpreter = $candidates | Where-Object {
    $_ -and (Test-Path -LiteralPath $_ -PathType Leaf)
} | Select-Object -First 1

if (!$interpreter) {
    throw 'Instale o AutoHotkey 1.1 de 64 bits ou aponte POE_OVERLAY_AHK para AutoHotkeyU64.exe.'
}

$script = Join-Path $root 'Exile UI.ahk'
Start-Process -FilePath $interpreter -ArgumentList ('"' + $script + '"') -WorkingDirectory $root
