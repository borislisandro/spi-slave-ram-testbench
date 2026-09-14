param(
    [ValidateSet('setup', 'compile', 'simulate', 'waves', 'kill-waves', 'lint', 'coverage', 'coverage-open', 'check', 'clean')]
    [string]$Target = 'simulate'
)

$projectRoot = Split-Path -Parent $PSScriptRoot

# WSL interop inherits this process's PATH, and long-lived terminals (VS Code
# tasks) carry a stale copy. Re-read the persisted Windows PATH so tools added
# since the terminal started -- gtkwave.exe, for one -- resolve inside WSL.
$env:PATH = @(
    [Environment]::GetEnvironmentVariable('PATH', 'Machine'),
    [Environment]::GetEnvironmentVariable('PATH', 'User')
) -join ';'

& wsl.exe --cd $projectRoot make $Target
exit $LASTEXITCODE
