# Creates your Google Play UPLOAD key (do this ONCE) and android\key.properties.
#
#   powershell -ExecutionPolicy Bypass -File tool\release\create_upload_key.ps1
#
# The key is saved OUTSIDE the project (default: your user folder) so it can
# never be uploaded to GitHub by accident. BACK IT UP with its password.
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..\..')

$keystore = Join-Path $HOME 'toffee-twist-upload.jks'
if (Test-Path $keystore) { Write-Host "The key $keystore already exists - not overwriting it."; exit 1 }

$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool) {
  $candidate = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
  if (Test-Path $candidate) { $keytool = $candidate }
}
if (-not $keytool) { Write-Host 'keytool was not found. Install Android Studio (it includes Java) and try again.'; exit 1 }

$p1 = Read-Host 'Choose a password for your upload key (at least 6 characters)' -AsSecureString
$p2 = Read-Host 'Type the same password again' -AsSecureString
$pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1))
$pass2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2))
if ($pass -ne $pass2) { Write-Host 'The passwords are different. Try again.'; exit 1 }
if ($pass.Length -lt 6) { Write-Host 'The password must have at least 6 characters.'; exit 1 }
$name = Read-Host 'Your name or studio name'
if (-not $name) { $name = 'Toffee Twist' }

& $keytool -genkeypair -keystore $keystore -storetype PKCS12 -alias upload `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass $pass -keypass $pass -dname "CN=$name"
if ($LASTEXITCODE -ne 0) { Write-Host 'keytool failed.'; exit 1 }

$storeFile = $keystore -replace '\\', '/'
@"
storePassword=$pass
keyPassword=$pass
keyAlias=upload
storeFile=$storeFile
"@ | Set-Content -Encoding ASCII 'android\key.properties'

Write-Host ''
Write-Host 'Done!'
Write-Host "  Upload key:    $keystore"
Write-Host '  Settings file: android\key.properties (never commit it - it is in .gitignore)'
Write-Host 'Back up the key file AND the password now.'
