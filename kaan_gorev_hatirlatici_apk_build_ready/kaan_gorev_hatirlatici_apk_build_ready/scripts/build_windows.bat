@echo off
setlocal

echo [1/5] Ana dosyalar yedekleniyor...
if not exist lib mkdir lib
copy /Y pubspec.yaml "%TEMP%\task_app_pubspec.yaml" >nul
copy /Y lib\main.dart "%TEMP%\task_app_main.dart" >nul

echo [2/5] Flutter Android proje dosyalari uretiliyor...
flutter create . --platforms=android --project-name emir_gorev_hatirlatici --org com.kaan
if errorlevel 1 goto error

echo [3/5] Uygulama kodlari geri yukleniyor...
copy /Y "%TEMP%\task_app_pubspec.yaml" pubspec.yaml >nul
copy /Y "%TEMP%\task_app_main.dart" lib\main.dart >nul
copy /Y build_assets\AndroidManifest.xml android\app\src\main\AndroidManifest.xml >nul

echo [4/5] Paketler indiriliyor...
flutter pub get
if errorlevel 1 goto error

echo [5/5] Release APK uretiliyor...
flutter build apk --release
if errorlevel 1 goto error

echo.
echo APK hazir:
echo build\app\outputs\flutter-apk\app-release.apk
echo.
pause
exit /b 0

:error
echo.
echo Build patladi. Terminaldeki hatayi kopyalayip ChatGPT'ye at.
echo Android build sistemi bazen ejderha gibi uyaniyor, beraber keseriz.
pause
exit /b 1
