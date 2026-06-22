#!/usr/bin/env bash
set -e

echo "[1/5] Ana dosyalar yedekleniyor..."
mkdir -p lib
cp pubspec.yaml /tmp/task_app_pubspec.yaml
cp lib/main.dart /tmp/task_app_main.dart

echo "[2/5] Flutter Android proje dosyaları üretiliyor..."
flutter create . --platforms=android --project-name emir_gorev_hatirlatici --org com.kaan

echo "[3/5] Uygulama kodları geri yükleniyor..."
cp /tmp/task_app_pubspec.yaml pubspec.yaml
cp /tmp/task_app_main.dart lib/main.dart
cp build_assets/AndroidManifest.xml android/app/src/main/AndroidManifest.xml

echo "[4/5] Paketler indiriliyor..."
flutter pub get

echo "[5/5] Release APK üretiliyor..."
flutter build apk --release

echo
echo "APK hazır:"
echo "build/app/outputs/flutter-apk/app-release.apk"
