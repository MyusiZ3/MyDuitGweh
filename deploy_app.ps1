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

# 2. Build APK (Hanya jika belum ada atau versi berubah)
Write-Host "--- Memeriksa Build APK ---" -ForegroundColor Yellow
$lastVersionFile = "build\app\outputs\flutter-apk\last_version.txt"
$lastVersion = ""
if (Test-Path $lastVersionFile) {
    $lastVersion = Get-Content $lastVersionFile
}

$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
$shouldBuild = $true

if (Test-Path $apkPath) {
    if ($lastVersion -eq $versionName) {
        Write-Host "[INFO] File Build v$versionName terdeteksi, melewati proses build..." -ForegroundColor Gray
        $shouldBuild = $false
    } else {
        Write-Host "[INFO] Versi berubah ($lastVersion -> $versionName). Memaksa build ulang..." -ForegroundColor Cyan
    }
}

if ($shouldBuild) {
    if (Test-Path $apkPath) {
        Write-Host "🗑️ Menghapus build lama..." -ForegroundColor Gray
        Remove-Item $apkPath -Force
    }
    
    Write-Host "🛠️ Memulai Build APK (Release v$versionName) ---" -ForegroundColor Yellow
    flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
    
    if ($LASTEXITCODE -eq 0) {
        if (!(Test-Path "build\app\outputs\flutter-apk")) { New-Item -ItemType Directory -Path "build\app\outputs\flutter-apk" -Force }
        $versionName | Out-File $lastVersionFile -NoNewline
        Write-Host "[OK] Build v$versionName selesai!" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Build APK Gagal!" -ForegroundColor Red
        exit
    }
}

# 3. Bersihkan Folder Public (Jangan masukkan file apk/bin agar deploy tidak terblokir)
Write-Host "--- Membersihkan file lama di folder public ---" -ForegroundColor Yellow
if (!(Test-Path "public")) { New-Item -ItemType Directory -Path "public" }

Remove-Item "public\MyDuitGweh_*.bin" -ErrorAction SilentlyContinue
Remove-Item "public\*.apk" -ErrorAction SilentlyContinue
Remove-Item "public\app.bin" -ErrorAction SilentlyContinue

$apkSource = "build\app\outputs\flutter-apk\app-release.apk"

# 4. Deploy ke Firebase Hosting (Otomatis upload index.html)
Write-Host "--- Sinkronisasi Versi di Landing Page ---" -ForegroundColor Yellow
$indexPath = "public\index.html"
if (Test-Path $indexPath) {
    (Get-Content $indexPath) -replace "{{VERSION}}", "$versionName" | Set-Content $indexPath
}

Write-Host "--- Deploy ke Firebase Hosting (Web Only) ---" -ForegroundColor Yellow
firebase deploy --only hosting

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Deploy Hosting Gagal!" -ForegroundColor Red
    exit
}

# 5. Buat GitHub Release dan Upload File
Write-Host "--- Membuat GitHub Release (v$versionName) ---" -ForegroundColor Yellow

# Pengecekan GH CLI
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $ghPath = "gh"
} else {
    $ghPath = "C:\Program Files\GitHub CLI\gh.exe"
}

$binSource = "build\app\outputs\flutter-apk\app.bin"
Copy-Item -Path $apkSource -Destination $binSource -Force

$notes = "Auto Deploy Release v$versionName`n- Build executed on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Write-Host "Menghapus tag lama (jika ada) via GitHub CLI..." -ForegroundColor Gray
& $ghPath release delete "v$versionName" --cleanup-tag --yes 2>$null

Write-Host "Mengunggah APK dan BIN ke repositori GitHub..." -ForegroundColor Cyan
& $ghPath release create "v$versionName" $apkSource $binSource --title "MyDuitGweh v$versionName" --notes $notes

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Membuat GitHub Release Gagal!" -ForegroundColor Red
} else {
    Write-Host "[OK] Berhasil upload ke GitHub Releases!" -ForegroundColor Green
}

Write-Host "[OK] Selesai! Web di-deploy ke Hosting & file diunggah ke GitHub (v$versionName)" -ForegroundColor DarkGreen
Write-Host "`nLink Host Aktif     : https://myduitgweh.web.app" -ForegroundColor Cyan
Write-Host "Link Download Statis: https://github.com/MyusiZ3/MyDuitGweh/releases/download/v$versionName/app-release.apk" -ForegroundColor Cyan
Write-Host "👉 Jangan lupa update manual di Firestore (Collection: app_config -> Document: global -> latestVersion) jika diperlukan." -ForegroundColor Gray

