param(
    [ValidateSet('setup', 'compile', 'simulate', 'waves', 'lint', 'coverage', 'coverage-open', 'coverage-gui', 'check', 'clean')]
    [string]$Target = 'simulate'
)

$projectRoot = Split-Path -Parent $PSScriptRoot
& wsl.exe --cd $projectRoot make $Target
exit $LASTEXITCODE
