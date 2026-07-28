# App Check (App Attest) Kurulumu

## Hata neydi

```
App not registered: 1:865362136741:ios:d4b197d001e8a57703474c.
```

Projede `firebase_app_check` paketi kurulu olduğu için native Firebase SDK'sı
her istekte bir App Check jetonu almaya çalışıyordu. Apple tarafında varsayılan
sağlayıcı **DeviceCheck**'tir; ama iOS uygulaması Firebase konsolunda App Check
için **hiç kayıtlı olmadığından** sunucu 400 döndürüyordu.

Uygulama çalışmaya devam ediyordu (`using placeholder token instead`), çünkü
zorlama (enforcement) kapalı. Yani bu bir çökme değil, korumanın hiç devrede
olmaması demekti.

Dart tarafı da iOS'u atlıyordu:

```dart
if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
```

Bu satır kaldırıldı; artık iOS/macOS için **App Attest** etkinleştiriliyor.

## Neden App Attest, DeviceCheck değil

DeviceCheck cihaz başına yalnızca birkaç bit veri saklar ve uygulamanın
gerçekten senin uygulaman olduğunu kanıtlamaz. App Attest, Secure Enclave'de
üretilen bir anahtarla uygulamanın bütünlüğünü kanıtlar — Firebase'in de
önerdiği sağlayıcı budur.

App Attest iOS 14+ gerektirir. Bu projenin minimum hedefi iOS 15 olduğundan
DeviceCheck'e geri düşmeye (fallback) gerek yok.

## 1. Firebase Console'da uygulamayı kaydet

1. [Firebase Console](https://console.firebase.google.com/project/_/appcheck/)
   → **Build** > **App Check**
2. **Apps** sekmesi → iOS uygulamasını (`com.winnerSpin`) seç
3. **App Attest**'i seç ve kaydet
4. TTL'i olduğu gibi bırak — varsayılan 1 saat çoğu uygulama için uygundur

Bu adım tek başına `App not registered` hatasını bitirir.

## 2. Xcode'da App Attest capability'sini ekle

Bunu **Xcode üzerinden** yapmak gerekiyor; elle entitlements dosyası oluşturmak
yetmez, çünkü capability aynı zamanda Apple Developer portalındaki App ID'ye de
işlenmeli.

1. Xcode → **Runner** hedefi → **Signing & Capabilities**
2. **+ Capability** → **App Attest** ekle
3. Oluşan `Runner.entitlements` dosyasında ortamı **production** yap:

```xml
<key>com.apple.developer.devicecheck.appattest-environment</key>
<string>production</string>
```

> Firebase, App Attest **sandbox** ortamında üretilen jetonları kabul etmez.
> Xcode debug derlemelerinde bu değer belirtilmezse sandbox'a düşer — bu yüzden
> açıkça `production` yazılmalı.

## 3. Geliştirme sırasında: debug token

App Attest simülatörde çalışmaz (attest edecek donanım yok). Bu yüzden kod,
release olmayan derlemelerde `AppleDebugProvider` kullanıyor:

1. Uygulamayı debug modda çalıştır
2. Xcode konsolunda şuna benzer bir satır çıkar:
   `Firebase App Check Debug Token: 123e4567-...`
3. Bu jetonu Firebase Console → **App Check** → **Apps** → uygulamanın yanındaki
   **⋮** → **Manage debug tokens** altına ekle

Debug jetonu kişiye/cihaza özeldir; **repoya commit etme.**

## 4. Doğrulama

Firebase Console → **App Check** → **APIs** sekmesi. Her Firebase servisi için
istekler üç gruba ayrılır:

| Grup | Anlamı |
| --- | --- |
| Verified | Geçerli App Check jetonu ile geldi |
| Unverified | Jeton yok veya geçersiz |
| Outdated client | App Check desteklemeyen eski sürüm |

Doğru kurulduysa Xcode konsolunda `App not registered` satırı kaybolur ve
birkaç dakika içinde **Verified** sayacı artmaya başlar.

## 5. Zorlamayı (enforcement) açmak

**Metrikler çoğunlukla "Verified" gösterene kadar açma.** Erken açarsan App
Check jetonu üretemeyen tüm istemciler — eski sürümü kullanan gerçek
kullanıcılar dahil — Firestore ve Auth'a erişemez.

Sıra şöyle olmalı:

1. App Attest'li sürümü yayınla
2. Kullanıcıların çoğu güncelleyene kadar bekle (metrikleri izle)
3. Sonra Firestore ve Auth için **Enforce**'u aç

Zorlama açıldığında `firestore.rules` değişmez; App Check kurallardan **önce**
devreye girer, yani jetonsuz istek kurallara hiç ulaşmaz.
