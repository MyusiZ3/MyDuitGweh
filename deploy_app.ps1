# ==========================================
# My Duit Gweh - Auto Deploy & Version Sync
# ==========================================

Write-Host "--- Memulai proses Auto-Deploy ---" -ForegroundColor Cyan

# 1. Ambil Versi dari pubspec.yaml
$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match "version:\s*([0-9.]+)") {
    $versionName = $Matches[1]
    Write-Host "[OK] Versi terdeteksi: $versionName" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Gagal membaca versi dari pubspec.yaml" -ForegroundColor Red
    exit
}

# 2. Build APK (Hanya jika belum ada atau ingin paksa build)
Write-Host "--- Memeriksa Build APK ---" -ForegroundColor Yellow
if (!(Test-Path "build\app\outputs\flutter-apk\app-release.apk")) {
    Write-Host "🛠️ Memulai Build APK (Release) ---" -ForegroundColor Yellow
    flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
} else {
    Write-Host "[INFO] File Build terdeteksi, melewati proses build..." -ForegroundColor Gray
}

# 3. Bersihkan Folder Public & Siapkan Download File
Write-Host "--- Menyiapkan Download File (.bin) ---" -ForegroundColor Yellow
if (!(Test-Path "public")) { New-Item -ItemType Directory -Path "public" }
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "public\app.bin" -Force

# 4. Deploy ke Firebase Hosting
Write-Host "--- Deploy ke Firebase Hosting ---" -ForegroundColor Yellow
firebase deploy --only hosting

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Deploy Hosting Gagal!" -ForegroundColor Red
    exit
}

# 5. Update Config di Firestore via Node.js Mini Script
$hostingUrl = "https://myduitgweh.web.app/app.bin"
Write-Host "--- Sinkronisasi versi ke Firestore ---" -ForegroundColor Yellow

# Kita buat skrip Node.js sementara karena Firebase CLI tidak punya 'set' langsung
$jsCode = @"
const admin = require('firebase-admin');
const serviceAccount = require('./android/app/google-services.json'); // Kita coba intip info project

// Gunakan firebase-tools (internal auth) untuk update dokumen
const { execSync } = require('child_process');
try {
    const data = JSON.stringify({
        latestVersion: "$versionName",
        downloadUrl: "$hostingUrl",
        updatedAt: new Date().toISOString()
    });
    // Gunakan perintah Patch jika tersedia
    console.log("Updating Firestore...");
    // Cara paling aman jika CLI terbatas: Panggil Firestore patch via JSON file
    const fs = require('fs');
    fs.writeFileSync('temp_data.json', data);
    console.log("Pushing updates...");
} catch (e) {
    console.error(e);
}
"@

# Sebenarnya ada cara lebih simpel tanpa buat JS:
# Kita gunakan Firebase CLI Firestore:set tapi dengan format yang benar.
# Jika firestore:set gagal, kita gunakan command alternative:

Write-Host "Updating database config..." -ForegroundColor Yellow

# Coba gunakan Firestore Patch (Command resmi terbaru)
# Jika ini gagal, kita buatkan data manual di Firestore Console.
firebase firestore:databases:set "(default)" --project myduitgweh
firebase firestore:set "app_config/global" "{`"latestVersion`":`"$versionName`",`"downloadUrl`":`"$hostingUrl`"}" --merge

if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Gagal update Firestore via CLI." -ForegroundColor Red
    Write-Host "👉 Silakan buka Firestore Console dan ubah manual:" -ForegroundColor White
    Write-Host "   Collection: app_config" -ForegroundColor Cyan
    Write-Host "   Document: global" -ForegroundColor Cyan
    Write-Host "   latestVersion: $versionName" -ForegroundColor Yellow
    Write-Host "   downloadUrl: $hostingUrl" -ForegroundColor Yellow
} else {
    Write-Host "[OK] Selesai! Aplikasi berhasil di-deploy ke v$versionName" -ForegroundColor DarkGreen
}

Write-Host "`nLink Download Aktif: $hostingUrl" -ForegroundColor Cyan
