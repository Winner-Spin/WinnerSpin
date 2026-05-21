# Mimari

TR Türkçe | [EN English](ARCHITECTURE.md)

Bu döküman, Winner Spin'de kullanılan mimariyi, uygulama akışını ve teknik tasarım kararlarını açıklar.

---

## Genel Bakış

Winner Spin, **Clean Architecture sınırları ile Feature-First Katmanlı MVVM mimarisi** kullanmaktadır.

Proje, her dosyayı yalnızca global teknik klasörlere koymak yerine özellikler (feature) etrafında organize edilmiştir. Bu, kimlik doğrulama akışını, slot oyun mantığını, sunum katmanını ve kalıcılık mantığını anlamayı, bakımını yapmayı, test etmeyi ve genişletmeyi kolaylaştırır.

---

## Proje Yapısı

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
      data/
        repositories/
      domain/
        repositories/
      presentation/
        viewmodels/
        views/

    slot/
      data/
        repositories/
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
    login_screen/
    register_screen/
    slot_main_screen/

  main.dart
```

---

## Katman Sorumlulukları

Mimari şu prensipleri takip eder:

- `domain/` slot matematiğini, oyun kurallarını, modelleri, enum'ları ve repository sözleşmelerini içerir.
- `data/` Firestore destekli ve yerel repository'ler gibi somut kalıcılık uygulamalarını içerir.
- `presentation/` ekranları, widget'ları, ViewModel'leri, UI controller'ları, ses yardımcılarını, navigasyon yardımcılarını ve sunum servislerini içerir.
- Domain katmanı Flutter arayüzüne veya Firebase uygulama detaylarına bağımlı değildir.
- Sunum katmanı, backend uygulama mantığını doğrudan sahiplenmek yerine domain sözleşmelerine bağımlıdır.
- Oyun mantığı ve animasyonlu arayüz davranışı mümkün olduğunca birbirinden ayrılmıştır.

Bu yapı, oyun motorunu test edilebilir tutarken sunum katmanının bağımsız olarak evrimleşmesine olanak tanır.

---

## Uygulama Akışı

Uygulama, Flutter ve Firebase'i başlatarak başlar, ardından kök uygulama widget'ını çalıştırır.

Kök uygulama mevcut kimlik doğrulama durumunu kontrol eder:

```text
Kullanıcı giriş yapmış     -> GameScreen (Oyun Ekranı)
Kullanıcı giriş yapmamış   -> LoginScreen (Giriş Ekranı)
```

Bu, slot ekranını doğrudan açmak yerine gerçek bir uygulama akışı oluşturur.

---

## Kimlik Doğrulama

Winner Spin, Firebase Authentication tabanlı giriş ve kayıt içerir.

Kimlik doğrulama katmanı soyut bir `AuthRepository` sözleşmesi kullanır. Bu, kimlik doğrulama davranışını arayüzden ayırır ve Firebase uygulamasının veri katmanının içinde kalmasını sağlar.

Desteklenen kimlik doğrulama davranışları:

- Kullanıcı kaydı
- Kullanıcı girişi
- Kullanıcı çıkışı
- Mevcut kullanıcı kimliği erişimi
- Kullanıcı verisi getirme
- Kullanıcı verisi izleme
- Oyuncu durumu kaydetme
- Firebase kimlik doğrulama hata eşleştirme

Yeni bir kullanıcı oluşturulduğunda Firestore başlangıç oyuncu verilerini depolar:

```text
uid
username
email
createdAt
balance
userBalance
freeSpinsRemaining
```

Bu, oyunu yalnızca yerel bir demo yapmak yerine gerçek bir backend bağlantılı oyuncu profili akışı sağlar.

---

## GameViewModel

`GameViewModel`, slot ekranı için ana durum orkestrasyon katmanı olarak görev yapar.

Şunlardan sorumlu daha küçük controller'ları koordine eder:

- bakiye durumu,
- bahis değişiklikleri,
- ante bet durumu,
- ücretsiz dönüş durumu,
- otomatik dönüş durumu,
- oyuncu oturumu,
- havuz durumu,
- kalıcılık,
- oyun geri bildirimi,
- dönüş yaşam döngüsü,
- tumble sıralaması,
- sonuç kapatma.

Bu yapı, her oyun ve arayüz detayını tek bir büyük sınıfa yerleştirmek yerine ViewModel'i koordinasyona odaklı tutar.

---

## Sunum Katmanı

Sunum katmanı basit bir slot grid'inden fazlasını içerir.

Yönettiği alanlar:

- ana oyun ekranı,
- animasyonlu makaralar,
- alt kontrol paneli,
- bahis kontrolleri,
- bakiye gösterimi,
- Ücretsiz Dönüşler katmanı (overlay),
- Ücretsiz Dönüş ödül dizisi,
- Büyük Kazanç / Süper Kazanç katmanı,
- uçan kazanç metni,
- scatter nabız efektleri,
- çarpan görselleri,
- Özellik Satın Alma ekranı,
- Otomatik Oyun ayarları,
- Oyun Kuralları ekranı,
- Oyun Geçmişi ekranı,
- Sistem Ayarları ekranı,
- ses ve titreşim kontrolleri.

Arayüz; ekranlar, widget'lar, UI controller'lar, modeller, servisler, ses yardımcıları ve navigasyon yardımcıları olarak ayrılmıştır, böylece ana oyun ekranı her detaya doğrudan sahip olmaz.

---

## Firebase ve Kalıcılık

Proje, backend destekli oyuncu ve havuz kalıcılığı için Cloud Firestore kullanır; yalnızca istemci tarafında ihtiyaç duyulan hafif kayıtlar ise akışı sade tutmak için yerel olarak saklanır.

Firestore kullanım alanları:

- oyuncu profil verileri,
- oyuncu bakiyesi,
- kalan ücretsiz dönüşler,
- havuz durumu.

Oyun geçmişi, yerel dosya destekli bir repository üzerinden saklanır. Böylece son oyun kayıtları, ek bir Firestore koleksiyonu oluşturmadan arayüzde gösterilebilir.

Oyuncu durumu, arayüzü Firebase uygulama detaylarıyla doğrudan iletişim kurmaya zorlamadan kaydedilebilir.

---

## Varlıklar (Assets)

Proje, görsel ve ses kaynakları için hem `assets/` hem de `lib/images/` kullanır.

```text
assets/
  audio/
  audio/Items/
  animations/

lib/images/
  login_screen/
  register_screen/
  slot_main_screen/
```

Bu varlıklar; giriş/kayıt görselleri, slot ekranı sembolleri, kazanç sunumu öğeleri, ses geri bildirimi ve Lottie animasyonları için kullanılır.
