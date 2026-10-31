param([string]$ApiUrl = 'http://10.0.2.2:8080')
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try { flutter pub get; flutter run "--dart-define=API_URL=$ApiUrl" } finally { Pop-Location }
