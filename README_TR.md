# Winner Spin: Flutter Slot Oyunu

TR Türkçe | [EN English](README.md)

Winner Spin, Firebase destekli kullanıcı hesapları, özel RTP-duyarlı slot motoru, kademeli (cascade) makaralar, ücretsiz dönüşler, çarpan toplama, animasyonlu kazanç sunumu, ses geri bildirimi ve simülasyon odaklı test altyapısı içeren Flutter tabanlı bir mobil slot oyunu projesidir.

Proje, tek ekranlık bir demo yerine gerçek bir mobil uygulama olarak yapılandırılmıştır. Oyun mantığı domain katmanındaki bir motorda yaşar, Firebase kalıcılığı repository sözleşmeleri arkasında soyutlanmıştır, sunum davranışı controller'lar ve ViewModel'ler arasında bölünmüştür ve slot matematiği tanısal simülasyon testleri ile kapsanmaktadır.

---

## Ekran Görüntüleri

<p align="center">
  <img src="docs/screenshots/winner-spin-base-game.jpeg" width="240" alt="Winner Spin ana oyun ekranı" />
  <img src="docs/screenshots/winner-spin-free-spins.jpeg" width="240" alt="Winner Spin ücretsiz dönüşler ekranı" />
  <img src="docs/screenshots/winner-spin-big-win.jpeg" width="240" alt="Winner Spin büyük kazanç ekranı" />
</p>

### Uygulama Ekranları

<p align="center">
  <img src="docs/screenshots/winner-spin-login.jpeg" width="180" alt="Winner Spin giriş ekranı" />
  <img src="docs/screenshots/winner-spin-register.jpeg" width="180" alt="Winner Spin kayıt ekranı" />
  <img src="docs/screenshots/winner-spin-buy-feature.jpeg" width="180" alt="Winner Spin özellik satın alma ekranı" />
</p>

<p align="center">
  <img src="docs/screenshots/winner-spin-auto-play.jpeg" width="180" alt="Winner Spin otomatik oyun ekranı" />
  <img src="docs/screenshots/winner-spin-settings.jpeg" width="180" alt="Winner Spin ayarlar ekranı" />
  <img src="docs/screenshots/winner-spin-game-rules.jpeg" width="180" alt="Winner Spin oyun kuralları ekranı" />
  <img src="docs/screenshots/winner-spin-game-history.jpeg" width="180" alt="Winner Spin oyun geçmişi ekranı" />
  <img src="docs/screenshots/winner-spin-free-spin-summary.jpeg" width="180" alt="Winner Spin ücretsiz dönüş özeti ekranı" />
</p>

---

## Öne Çıkanlar

- Flutter tabanlı mobil slot oyunu projesi
- Giriş ve kayıt için Firebase Authentication
- Oyuncu durumu ve havuz durumu için Cloud Firestore kalıcılığı
- Feature-first katmanlı MVVM mimarisi
- Clean Architecture'dan ilham alan bağımlılık sınırları
- Dart ile yazılmış özel slot motoru
- Küme kazanç tespiti ile 6x5 kademeli slot grid'i
- Tumble / cascade dizisi simülasyonu
- Yeniden tetikleme mantığı ile scatter sembolleri ve Ücretsiz Dönüş tetikleme sistemi
- Çarpan toplama sistemi
- Özellik Satın Alma (Buy Feature) akışı ve Ante Bet modu
- Hızlı Durdurma etkileşimi ile Otomatik Dönüş kontrolleri
- Animasyonlu makara geçişleri ve Büyük Kazanç / Süper Kazanç sunumu
- Ses geri bildirimi ve ortam sesi yönetimi
- Oyun kuralları, oyun geçmişi ve sistem ayarları ekranları
- Mod tabanlı davranış ile RTP-duyarlı havuz dengeleme
- Slot matematik davranışı için Monte Carlo ve stres testleri
- WSPIN görev tanımlayıcıları ile Jira tarzı geliştirme iş akışı

---

## Teknoloji Yığını

| Kategori | Teknolojiler |
| --- | --- |
| Mobil Geliştirme | Flutter, Dart |
| Backend / Bulut | Firebase Core, Firebase Auth, Cloud Firestore |
| Arayüz & Sunum | Flutter Widget'ları, Lottie, Google Fonts |
| Ses | audioplayers |
| Mimari | Feature-First Katmanlı MVVM, Clean Architecture sınırları |
| Test | Flutter Test, RTP simülasyonları, stres testleri |
| İş Akışı | GitHub, Jira tarzı WSPIN görev takibi |

Proje şu anda Dart SDK `^3.10.8` kullanmaktadır.

---

## Mimari

Winner Spin, **Clean Architecture sınırları ile Feature-First Katmanlı MVVM mimarisi** kullanmaktadır.

```text
lib/
  app/
    app.dart
  core/
    audio/
    format/
    widgets/
  features/
    auth/
      data/repositories/
      domain/repositories/
      presentation/
        viewmodels/
        views/
    slot/
      data/repositories/
      domain/
        engine/
        enums/
        models/
        repositories/
      presentation/
        audio/
        models/
        navigation/
        services/
        ui_controllers/
        viewmodels/
        views/
  images/
  main.dart
```

- `domain/` slot matematiğini, oyun kurallarını, modelleri ve repository sözleşmelerini içerir.
- `data/` Firestore destekli ve yerel repository'ler gibi somut kalıcılık uygulamalarını içerir.
- `presentation/` ekranları, widget'ları, ViewModel'leri, UI controller'ları ve servisleri içerir.
- Domain katmanı Flutter arayüzüne veya Firebase uygulama detaylarına bağımlı değildir.

Detaylı mimari dokümantasyonu için bkz. [docs/ARCHITECTURE_TR.md](docs/ARCHITECTURE_TR.md).

---

## Slot Motoru

Slot motoru, grid oluşturma, küme kazanç tespiti, tumble/cascade simülasyonu, çarpan toplama, scatter değerlendirmesi, Ücretsiz Dönüş tetikleme ve RTP-duyarlı havuz yönetiminden sorumlu özel bir Dart tabanlı oyun motorudur.

Motor, odaklanmış modüllere ayrılmıştır:

| Dosya | Sorumluluk |
| --- | --- |
| `slot_engine.dart` | Ana dönüş orkestrasyonu ve oyun sonucu üretimi |
| `grid_generator.dart` | Güvenli grid ve kazançlı grid üretimi |
| `tumble_simulator.dart` | Cascade/tumble simülasyonu ve küme kazanç değerlendirmesi |
| `multiplier_collector.dart` | Çarpan sembolü toplama |
| `pool_guard.dart` | Havuz güvenlik kontrolleri ve ödeme koruması |
| `chain_forcer.dart` | Kontrollü zincir/cascade zorlama davranışı |
| `weighted_random.dart` | Ağırlıklı rastgele seçim yardımcıları |
| `spin_task.dart` | Dönüş görevi modelleme |
| `rtp_config.dart` | RTP ile ilgili yapılandırma |
| `ante_config.dart` | Ante Bet yapılandırması |
| `buy_config.dart` | Özellik Satın Alma yapılandırması |
| `engine_runtime.dart` | Çalışma zamanı motor durumu ve yürütme desteği |

Detaylı oyun mekanikleri dokümantasyonu için bkz. [docs/GAME_MECHANICS_TR.md](docs/GAME_MECHANICS_TR.md).

---

## Test ve Simülasyon

Winner Spin, hem standart Flutter testlerini hem de RTP davranışı, tumble dağılımı, çarpan toplama ve stres senaryolarını kapsayan slot'a özel tanısal simülasyonları içerir.

Tüm test paketini çalıştır:

```bash
flutter test
```

Hedefli testleri çalıştır:

```bash
flutter test test/rtp_simulation_test.dart
flutter test test/per_mode_rtp_test.dart
flutter test test/ante_bet_rtp_test.dart
flutter test test/buy_bonus_rtp_test.dart
flutter test test/buy_force_trigger_test.dart
flutter test test/buy_scatter_payout_test.dart
flutter test test/mixed_farm_ante_rtp_test.dart
flutter test test/realistic_player_rtp_test.dart
flutter test test/tumble_distribution_test.dart
flutter test test/multiplier_collector_test.dart
flutter test test/whale_clustering_stress_test.dart
```

Bazı tanısal testler, uzun vadeli RTP davranışını, isabet oranını, Ücretsiz Dönüş tetikleme sıklığını, mod dağılımını ve havuz yörüngesini incelemek için milyonlarca simüle edilmiş dönüş çalıştırır.

---

## Geliştirme İş Akışı

Winner Spin, Jira tabanlı bir görev takip iş akışı ile geliştirilmiştir. Commit mesajları **WSPIN** görev tanımlayıcıları kullanır:

```text
WSPIN-299 Oyun ekranı alt kontrol aralığını ayarladı
WSPIN-297 Slot sunum klasörlerini UI sorumluluğuna göre düzenledi
WSPIN-296 Slot sunum dosyalarını özellik klasörlerine yeniden yapılandırdı
WSPIN-295 Buy Free Spins onay ekranı sunum widget'larını çıkardı
WSPIN-285 Big Win ve kalıcı küme sunum controller'larını çıkardı
WSPIN-284 Ücretsiz dönüş ödül dizisi controller'ını çıkardı
WSPIN-283 Slot dönüş akış controller'larını ve sahne kontrol katmanını çıkardı
WSPIN-282 GameViewModel controller'larını ve slot durum orkestrasyonunu çıkardı
```

---

## Katkılar

Bu proje, ekip tabanlı bir mobil oyun projesi olarak geliştirilmiştir.

Ana katkı alanları: slot oyun ekranı geliştirme, oyun sunumu yeniden yapılandırmaları, Ücretsiz Dönüşler akışı, çarpan davranışı, Özellik Satın Alma arayüzü, Otomatik Oyun ayarları, Oyun Kuralları / Oyun Geçmişi / Sistem Ayarları ekranları, GameViewModel controller çıkarımı, durum orkestrasyonu, havuz ve oyuncu durumu kalıcılık düzeltmeleri ve WSPIN commit isimlendirmesi ile Jira tabanlı görev takibi.

Bu proje; Flutter mobil geliştirme, Firebase entegrasyonu, durum yönetimi, oyun arayüzü geliştirme, özel oyun mantığı, simülasyon tabanlı test ve ekip tabanlı yazılım geliştirme iş akışı deneyimini göstermektedir.

---

## Başlarken

### Ön Koşullar

```bash
flutter doctor
git clone https://github.com/Winner-Spin/WinnerSpin.git
cd WinnerSpin
flutter pub get
```

### Firebase Kurulumu

Bu proje Firebase Authentication ve Cloud Firestore kullanmaktadır.

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Ardından Firebase Authentication (E-posta/Şifre) ve Cloud Firestore'u etkinleştirin. Uygulama, kullanıcı belgelerini `users` koleksiyonu altında bekler.

### Uygulamayı Çalıştırma

```bash
flutter run
flutter run -d android
flutter run -d ios
```

### Derleme

```bash
flutter build apk
flutter build web
```

### Yararlı Komutlar

```bash
flutter pub get
dart format .
dart analyze
flutter test
```

---

## Dokümantasyon

| Döküman | Açıklama |
| --- | --- |
| [Mimari](docs/ARCHITECTURE_TR.md) | Detaylı mimari, uygulama akışı, kimlik doğrulama ve katman sorumlulukları |
| [Oyun Mekanikleri](docs/GAME_MECHANICS_TR.md) | Slot motoru, cascade mekanikleri, ücretsiz dönüşler, çarpanlar, RTP, havuz sistemi |

---

## Proje Durumu

Winner Spin; Flutter mobil geliştirme, Firebase entegrasyonu, feature-first MVVM mimarisi, özel slot oyun mantığı, RTP-duyarlı havuz davranışı, animasyonlu oyun sunumu, simülasyon tabanlı test ve Jira tabanlı ekip iş akışını göstermek için tasarlanmış bir portfolyo projesidir.

---

## Önemli Not

Winner Spin bir yazılım ve oyun projesidir. Slot matematiği, RTP davranışı, bakiyeler ve kalıcılık modeli; resmi matematiksel inceleme, uyumluluk çalışması, güvenlik güçlendirmesi ve bağımsız sertifikasyon yapılmadan denetlenmiş, düzenlenmiş veya üretime hazır kumar altyapısı olarak değerlendirilmemelidir. Firebase yapılandırması ve platform dosyaları da halka açık bir sürüm yayınlamadan önce gözden geçirilmelidir.

---

## Lisans

Bu proje Apache License 2.0 altında lisanslanmıştır.

Telif Hakkı © 2026, Hakan Güneş ve Enes Eken.

Detaylar için `LICENSE` dosyasına bakınız.
