# Görev Hatırlatıcı - APK Build Ready Paket

Bu paket gerçek APK dosyası değildir. APK üretmeye hazır kaynak paketidir.

Buradaki çalışma ortamında Flutter, Dart, Gradle ve Android SDK bulunmadığı için APK'yı doğrudan derleyemedim. Bu yüzden sana APK üretimini otomatikleştiren daha kullanışlı bir paket hazırladım.

## İçindekiler

- `lib/main.dart`  
  Uygulamanın ana kodu.

- `pubspec.yaml`  
  Flutter paketleri.

- `build_assets/AndroidManifest.xml`  
  Android bildirim ve alarm izinleri.

- `.github/workflows/build-apk.yml`  
  GitHub Actions ile otomatik APK üretme dosyası.

- `scripts/build_windows.bat`  
  Windows'ta otomatik build scripti.

- `scripts/build_mac_linux.sh`  
  Mac/Linux'ta otomatik build scripti.

---

# En kolay yol: GitHub Actions ile APK üretmek

Bu yol bilgisayarında Android Studio kurcalamadan APK üretmek için en temiz yoldur.

## 1. GitHub'da yeni repo aç

GitHub hesabında boş bir repo oluştur.

## 2. Bu zipin içeriğini repoya yükle

Zipin içindeki dosyaları repo içine yükle. Klasör yapısı bozulmasın.

Şöyle görünmeli:

```text
.github/workflows/build-apk.yml
build_assets/AndroidManifest.xml
lib/main.dart
scripts/build_windows.bat
scripts/build_mac_linux.sh
pubspec.yaml
README.md
```

## 3. Actions sekmesine gir

Repo sayfasında `Actions` sekmesine gir.

`Build APK` workflow'unu seç.

`Run workflow` butonuna bas.

## 4. APK artifact'ini indir

Build bitince workflow sayfasının altında `gorev-hatirlatici-apk` isimli artifact çıkar.

Onu indir. İçinde:

```text
app-release.apk
```

olacak.

---

# Windows'ta local APK üretmek

Bilgisayarında Flutter kuruluysa:

1. Zipi çıkar.
2. Klasöre gir.
3. `scripts/build_windows.bat` dosyasına çift tıkla.

APK şu konuma çıkar:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

# Mac/Linux'ta local APK üretmek

Terminalde proje klasöründe:

```bash
chmod +x scripts/build_mac_linux.sh
./scripts/build_mac_linux.sh
```

APK şu konuma çıkar:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

# Uygulama özellikleri

- Görev ekleme
- Görev silme
- Tarih/saat seçme
- Yerel telefon bildirimi
- Görevi tamamlandı işaretleme
- Tamamlanan görevleri toplu silme
- Görevleri telefonda yerel saklama

---

# Hata çıkarsa

En olası hatalar:

- Flutter kurulu değil
- Android SDK eksik
- Android lisansları kabul edilmemiş
- Bildirim/alarm izni Android tarafından kısıtlanmış

Şu komut faydalı olur:

```bash
flutter doctor
```

Terminaldeki hatayı aynen kopyalayıp ChatGPT'ye atarsan direkt üzerinden düzeltilebilir.
---

# Kaan için daha kolay yöntem

Bu sürümde workflow hem elle hem de otomatik çalışır.

Repo'ya dosyaları yükleyip `Commit changes` dediğin anda build otomatik başlamalıdır.

Kontrol yolu:

1. Repo ana ekranına gir.
2. `Actions` sekmesine bas.
3. Sol tarafta `Build APK` görünebilir.
4. Görünmese bile orta kısımda son workflow run listesi görünmelidir.
5. Build bitince `gorev-hatirlatici-apk` artifact'ini indir.

Eğer hiçbir şey görünmüyorsa:
- `.github/workflows/build-apk.yml` dosyası repoda yoktur,
- yanlış branch'e yüklenmiştir,
- Actions repo ayarlarında kapalıdır,
- ya da GitHub mobil görünümünde workflow menüsü saklanıyordur.
