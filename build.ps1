# Encrypts the family page into index.html for GitHub Pages.
# Run:  powershell -ExecutionPolicy Bypass -File build.ps1
# You'll be prompted for the password (it is never saved in plain text).

$ErrorActionPreference = 'Stop'
$site   = $PSScriptRoot
$source = (Resolve-Path (Join-Path $site '..\YichusProject\genealogy\final\berkowitz-modern\The-Berkowitz-Family.html')).ProviderPath

if (-not $env:STATICRYPT_PASSWORD) {
    $secure = Read-Host 'Family password' -AsSecureString
    $env:STATICRYPT_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}

# staticrypt can't handle network/mapped paths, so work in a local temp folder.
$work = Join-Path $env:TEMP 'berkowitz-staticrypt'
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory $work | Out-Null
Copy-Item $source (Join-Path $work 'index.html')
# .staticrypt.json holds the salt; keeping it means "Remember me" and share links survive rebuilds.
if (Test-Path (Join-Path $site '.staticrypt.json')) { Copy-Item (Join-Path $site '.staticrypt.json') $work }

Push-Location $work
try {
    npx --yes staticrypt index.html -d out --short --remember 365 `
        --template-title 'The Berkowitz Family' `
        --template-instructions 'Please enter the family password to open the album.' `
        --template-button 'Open' `
        --template-placeholder 'Family password' `
        --template-remember 'Remember me on this device' `
        --template-error 'That password is not right. Please try again.' `
        --template-color-primary '#7a4e2d' `
        --template-color-secondary '#efe6d8'
    if ($LASTEXITCODE -ne 0) { throw 'staticrypt failed' }

    $share = npx --yes staticrypt index.html -d share --short --share 'https://mmezei.github.io/berkowitz-family/' --share-remember 2>&1 |
        Select-String 'https://\S+#staticrypt_pwd=\S+' | ForEach-Object { $_.Matches[0].Value } | Select-Object -First 1

    Copy-Item -Force 'out\index.html' (Join-Path $site 'index.html')
    Copy-Item -Force '.staticrypt.json' $site
}
finally {
    Pop-Location
    Remove-Item -Recurse -Force $work
    Remove-Item Env:STATICRYPT_PASSWORD -ErrorAction SilentlyContinue
}

Write-Host "`nDone. index.html is ready to commit and push."
if ($share) { Write-Host "`nShare link (opens without typing the password):`n$share" }
