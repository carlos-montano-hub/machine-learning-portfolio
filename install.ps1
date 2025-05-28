$originalLocation = Get-Location

$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Set-Location -Path $scriptPath
if (-Not (Test-Path -Path ".\.venv")) {
    Write-Host "Virtual environment not found. Creating one..."
    python -m venv .venv
}

$env:Path = ".\.venv\Scripts;" + $env:Path

& ".\.venv\Scripts\Activate.ps1"

python -m pip install --upgrade pip

python -m pip install -r .\requirements.txt

Set-Location -Path $originalLocation