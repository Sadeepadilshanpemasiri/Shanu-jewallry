param([switch]$SeedReminders, [switch]$DemoData)
$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot
try {
  $seed = 'node scripts/seed-local.mjs'
  if ($SeedReminders -or $DemoData) {
    Push-Location -LiteralPath functions
    try {
      if (!(Test-Path -LiteralPath 'node_modules/typescript/package.json')) {
        npm.cmd ci
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
      }
      npm.cmd run build
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } finally { Pop-Location }
    $seed += ' && node functions/lib/local.js'
    if ($SeedReminders) { $seed += ' --demo' }
    if ($DemoData) { $seed += ' --sample' }
  }
  $launch = $seed + ' && flutter run -d chrome --web-port=5050 --dart-define=LOCAL_FIREBASE=true'
  firebase.cmd emulators:exec --project demo-jewellery-manager --only auth,firestore,storage $launch
  exit $LASTEXITCODE
} finally { Pop-Location }