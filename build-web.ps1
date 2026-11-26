param([string]$Config = '.firebase-config.json')
$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot
try {
  $path = (Resolve-Path -LiteralPath $Config).Path
  $settings = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
  $firebaseWeb = [ordered]@{
    apiKey = $settings.FIREBASE_API_KEY
    appId = $settings.FIREBASE_APP_ID
    projectId = $settings.FIREBASE_PROJECT_ID
    messagingSenderId = $settings.FIREBASE_MESSAGING_SENDER_ID
    authDomain = $settings.FIREBASE_AUTH_DOMAIN
    storageBucket = $settings.FIREBASE_STORAGE_BUCKET
  }
  foreach ($entry in $firebaseWeb.GetEnumerator()) {
    if ([string]::IsNullOrWhiteSpace($entry.Value)) { throw "Missing Firebase Web value: $($entry.Key)" }
  }
  flutter build web --release --pwa-strategy=none --no-web-resources-cdn "--dart-define-from-file=$path"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $javascript = 'self.shopFirebaseWebConfig = ' + ($firebaseWeb | ConvertTo-Json -Compress) + ';'
  [IO.File]::WriteAllText((Join-Path $PWD 'build/web/firebase-messaging-config.js'), $javascript, [Text.UTF8Encoding]::new($false))
  node scripts/build-pwa.mjs
  if ( -ne 0) { exit  }
} finally { Pop-Location }