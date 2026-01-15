# Mentaliq Proje Notu
> Son Güncelleme: 2026-01-08 01:47

## 📍 Proje Konumu
```
c:\Users\Hp\.gemini\antigravity\scratch\mentaliq
```

## ✅ Tamamlanan İşler

### 1. Flutter Projesi Oluşturuldu
- Package: `com.mentaliq.mentaliq`
- Platformlar: Android, iOS, Web

### 2. Firebase Yapılandırıldı
- Proje: `mentaliq-app`
- Servisler: Auth (Anonymous), Firestore, Storage
- FlutterFire CLI ile otomatik yapılandırıldı

### 3. Gemini AI Entegre Edildi
- Model: `gemini-2.0-flash`
- API Key: `.env` dosyasında
- 6 kategori için Türkçe system prompt'lar hazır

### 4. Silent Auth Sistemi
- Device ID ile cihaz tanıma
- Anonim Firebase Auth
- Kullanıcı silse bile aynı cihazda tanınır

### 5. UI/UX Tasarımı
- Mystik koyu tema (mor/pembe gradient)
- Animasyonlu splash screen
- Kategori kartları ile ana sayfa
- AI sohbet ekranı

## 📁 Dosya Yapısı

```
lib/
├── main.dart                 # Firebase + Gemini init
├── firebase_options.dart     # Auto-generated
├── config/
│   ├── app_constants.dart    # Kategoriler
│   └── app_theme.dart        # Tema
├── models/
│   ├── user_model.dart       # User + deviceId
│   └── chat_message.dart     # Mesaj modeli
├── services/
│   ├── auth_service.dart     # Silent auth
│   └── gemini_service.dart   # AI servisi
└── screens/
    ├── splash_screen.dart    # Animasyonlu açılış
    ├── home/home_screen.dart # Kategori grid
    └── chat/chat_screen.dart # AI sohbet
```

## 🎯 AI Kategorileri

1. 🌙 Astroloji
2. 🌱 Kişisel Gelişim
3. 🎯 Yaşam Koçluğu
4. 💕 İlişki Danışmanlığı
5. 🧠 Psikolojik Destek
6. ✨ Stil Danışmanlığı

## ⚠️ Bilinen Sorunlar

1. **Firebase Auth Web'de hata veriyor** - Firebase Console'da Authentication > Anonymous sign-in'i etkinleştirmek gerekiyor

## 📋 Sonraki Adımlar

- [x] "6 Kapı" Ana sayfa tasarımı (Profile integrated)
- [x] Token ve Mood bar arayüzü
- [x] Günün Mesajı alanı
- [ ] Firebase Auth Anonymous etkinleştirilmedi (Web/Android/iOS için kontrol)
- [ ] Sohbet geçmişi Firestore entegrasyonu
- [ ] Token sistemi fonksiyonel hale getirilecek
- [ ] Günün mesajı Gemini'den çekilecek

## 🚀 Çalıştırma Komutları

```bash
# Web
flutter run -d chrome

# Android
flutter run -d android

# iOS (Mac gerekli)
flutter run -d ios
```
