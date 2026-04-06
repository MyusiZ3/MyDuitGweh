1. Perintah Build yang Benar
   Tadi ada kesalahan ketik (typo) pada perintah Anda. Gunakan ini untuk hasil APK yang optimal (aman & ringan):

```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols

```

2. Alur Deployment ke Firebase
   Setelah build berhasil, ikuti urutan ini:

```bash
copy build\app\outputs\flutter-apk\app-release.apk public\myduitgweh.apk
```

Deploy ke Firebase Hosting:

```bash
firebase deploy --only hosting
```

Dapatkan Link Download: Link Anda biasanya adalah https://id-projek-anda.web.app/myduitgweh.apk.

atauuuuu

```bash
./deploy_app.ps1
```

duterminal

C:\Users\muham\Documents\Github\MyDuitGweh\deploy_app.ps1
