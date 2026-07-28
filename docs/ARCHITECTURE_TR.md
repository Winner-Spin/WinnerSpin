# Mimari

TR Türkçe | [EN English](ARCHITECTURE.md)

Bu belge Winner Spin'in güncel uygulama yapısını, çalışma zamanı akışını, kalıcılık sınırlarını ve performans odaklı servislerini açıklar.

---

## 1. Mimari Yaklaşım

Winner Spin, **Clean Architecture'dan esinlenen sınırlarla feature-first katmanlı MVVM mimarisi** kullanır.

Temel amaçlar:

- slot matematiğini Flutter widget'larından ve Firebase'den bağımsız tutmak;
- harici depolamayı repository sözleşmeleri üzerinden sunmak;
- ekranları yerleşim ve etkileşime odaklamak;
- durum orkestrasyonunu ViewModel'e ve odaklı controller'lara taşımak;
- animasyon sıralamasını deterministik oyun sonucundan ayırmak;
- kimlik doğrulama, kurtarma, ses ve motor davranışını test edilebilir kılmak.

Bu yapı katı bir dependency-injection çatısı değil, pragmatik bir mimaridir. Domain katmanı bağımsız kalırken sunum katmanındaki bazı bağımlılık oluşturma noktaları varsayılan somut adaptörleri seçer. GameViewModel ve SlotPersistenceController testler için dependency kabul eder; sağlanmadığında yerel/Firebase uygulamalarını oluşturur.

---

## 2. Repository Yapısı

~~~text
lib/
  app/
    app.dart
  core/
    audio/
    firebase/
    format/
    network/
    widgets/
  features/
    auth/
      data/repositories/
      domain/
        models/
        repositories/
        services/
      presentation/
        models/
        viewmodels/
        views/
    slot/
      data/repositories/
      domain/
        engine/
        enums/
        models/
        repositories/
        services/
      presentation/
        audio/
        models/
        navigation/
        services/
        ui_controllers/
        viewmodels/
          controllers/
        views/
  firebase_options.dart
  main.dart

functions/
  index.js

package.json

test/
  app/
  core/
  firebase/
  features/
  *_test.dart
~~~

### Katman Sorumlulukları

| Katman | Sorumluluk |
| --- | --- |
| app | Uygulama kökü, kimlik doğrulama kapısı ve genel yaşam döngüsü gözlemi |
| core | Özellikler arası ses, bağlantı, biçimlendirme ve tekrar kullanılabilir widget'lar |
| auth/domain | Kimlik doğrulama sözleşmesi, auth modelleri ve parola sıfırlama politikası |
| auth/data | Firebase Authentication, Firestore profili ve callable function adaptörü |
| slot/domain | Slot kuralları, motor, havuz modeli, sonuç modelleri ve kalıcılık sözleşmeleri |
| slot/data | Firestore havuzu ve yerel dosya repository uygulamaları |
| presentation | Ekranlar, ViewModel'ler, durum controller'ları, animasyon controller'ları ve varlık/ses servisleri |
| functions | Callable hesap silme backend'i |

Bağımlılık yönü en güçlü biçimde domain katmanının çevresinde korunur:

~~~text
Presentation ──> Domain sözleşmeleri/modelleri <── Data uygulamaları
                            │
                            └── Slot motoru
~~~

Data ve presentation Flutter/Firebase paketlerine bağımlı olabilir. Slot domain kodu arayüz widget'larına veya Firebase uygulamalarına bağımlı değildir.

---

## 3. Uygulama Başlangıcı ve Genel Yaşam Döngüsü

main.dart, ilk ekran çizilmeden önce şu işlemleri yapar:

1. Flutter binding'lerini başlatır;
2. kalıcı ortam müziği tercihini yükler;
3. ortak uygulama ses bağlamını yapılandırır;
4. Firebase'i başlatır;
5. Android App Check'i geliştirme derlemelerinde debug provider, release derlemelerde Play Integrity ile etkinleştirir;
6. immersive sistem arayüzünü etkinleştirir;
7. runApp'i engellemeden çarpan bombası Lottie varlığını parse etmeye başlar;
8. WinnerSpinApp'i çalıştırır.

WinnerSpinApp uygulama geneli yaşam döngüsü gözlemcisini içerir. resumed dışındaki her durum ortam müziğini duraklatır; resumed durumuna dönüşte yalnızca müzik daha önce istenmiş ve kalıcı tercih açık ise oynatma talep edilir. Bu sorumluluk uygulama kökünde bulunduğundan Login, Register, E-posta Doğrulama ve Oyun ekranları tutarlı davranır.

---

## 4. Kimlik Doğrulama ve Navigasyon

Kök kimlik doğrulama kapısı üç hedeften birini seçer:

~~~text
Kimliği doğrulanmış kullanıcı yok
  └── LoginScreen

Oturum var, e-posta doğrulanmamış
  └── EmailVerificationScreen

Oturum var, e-posta doğrulanmış
  └── GameScreen
~~~

### Kayıt

1. Presentation ViewModel kullanıcı girdisini doğrular.
2. Firebase Authentication e-posta/parola hesabını oluşturur.
3. Başlangıç oyuncu durumuyla users/{uid} Firestore profili oluşturulur.
4. Firebase yerleşik e-posta doğrulama bağlantısını gönderir.
5. Doğrulanmış claim gözlemlenene kadar kullanıcı EmailVerificationScreen'de kalır.

Doğrulama ekranı uygulama resumed durumuna döndüğünde Firebase kullanıcısını yeniden yükler ve 60 saniyelik yeniden gönderme bekleme süresi uygular.

### Giriş ve Profil İşlemleri

- Doğrulanmamış kullanıcılar oyuna girmek yerine doğrulama ekranına yönlendirilir.
- Profil verisi users/{uid} üzerinden izlenir.
- Avatar değişiklikleri kaydedilmeden önce sembol registry'sine göre doğrulanır.
- Parola sıfırlama istekleri Firestore'da rezerve edilir ve 24 saatte bir ile sınırlandırılır.
- Tam hesap silme, deleteAccount callable Cloud Function'ını çağırır.

---

## 5. Oyun Bileşenleri ve Durum Yönetimi

GameScreen, oyun ekranının arayüz bileşenlerini barındırır ve bunları GameViewModel'e bağlar. GameViewModel oyun durumunu ve işlem akışlarını koordine eder; bütün davranışları tek sınıfta toplamak yerine her sorumluluğu odaklı controller'lara devreder.

### Sorumluluk Grupları

| Sorumluluk alanı | Ana bileşenler |
| --- | --- |
| Oyuncu durumu | BalanceController, PlayerSessionController, AnteController, FreeSpinsController |
| Dönüş yaşam döngüsü | SpinRoundController, SlotSpinStartController, SpinLifecycleController |
| Motorun çalıştırılması | SpinExecutionController, SlotSpinFlowController |
| Sonucun işlenmesi | TumbleSequenceController, SpinResultSettlementController, SlotSpinCompletionController |
| Kalıcılık | SlotPersistenceController, SlotSessionHydrationController, SlotSessionLifecycleController |
| Otomatik oynatım | AutoSpinController, SlotAutoSpinFlowController, FreeSpinAutoPlayController |
| Görsel sunum | GridController ile kazanç, overlay, Ücretsiz Dönüş ve çarpan UI controller'ları |
| Ses ve titreşim | GameFeedbackController ve odaklı geri bildirim yardımcıları |

Sunum controller'ları animasyonları ve overlay'leri sıralar ancak motor sonucunu yeniden hesaplamaz. Hesaplanan SpinResult tek doğruluk kaynağıdır.

---

## 6. Dönüş Yürütme Akışı

Standart normal/Ücretsiz Dönüş akışı:

~~~text
Oyuncu veya otomatik oynatım dönüş ister
  → kullanılabilirlik ve bakiye korumaları
  → bahis/Ücretsiz Dönüş başlangıç durumu rezerve edilir
  → SpinExecutionController compute çağırır
  → SlotEngine geçici arka plan isolate'ında çalışır
  → PoolState ve SpinResult arayüz isolate'ına döner
  → kesin kurtarma anlık görüntüsü yazılır
  → makaralar, tumble'lar, çarpanlar ve kazanç sunumu çalışır
  → sonuç bakiye/geçmiş/havuza işlenir
  → uzak durum kalıcılaştırılır
  → güvenli olduğunda kurtarma kaydı temizlenir
~~~

Compute sınırı grid üretimini ve tumble simülasyonunu arayüz isolate'ından uzaklaştırır. Flutter animasyonu, ses ve widget durumu ana isolate'ta kalır.

Hızlı Durdurma yalnızca sunum zamanlamasını değiştirir. Önceden hesaplanmış sonucu yeniden çekmez veya değiştirmez.

---

## 7. Kalıcılık Modeli

### Firebase

| Konum | Saklanan veri |
| --- | --- |
| Firebase Authentication | Kullanıcı kimliği ve doğrulanmış e-posta claim'i |
| users/{uid} | Kullanıcı adı, e-posta, avatar, bakiye, son kazanç ve Ücretsiz Dönüş durumu |
| users/{uid}.pool | totalBetsPlaced, totalPaidOut ve totalSpins |

Havuz bakiyesi, beklenen havuz ve mevcut mod gibi çalışma zamanı değerleri saklanan sayaçlardan türetilir. Havuz sayaçları normalde kaydedilmiş her 10 ücretli dönüşten sonra ve ilgili oturum/yaşam döngüsü işlemlerinde zorunlu olarak kaydedilir.

### Yerel Uygulama Dosyaları

| Repository/store | Amaç |
| --- | --- |
| LocalGameHistoryRepository | Kullanıcı başına geçmişin tamamı (her spinde yazılır) |
| FirestoreGameHistoryRepository | Yalnızca en son 10 kayıt, kullanıcı dokümanında `gameHistory` dizisi olarak; yalnızca uygulama kapanınca yazılır |
| LocalSpinRecoveryRepository | Kullanıcı başına bekleyen hesaplanmış dönüş anlık görüntüsü |
| LocalFirstLaunchDisclaimerRepository | İlk açılış bilgilendirme onayı |
| AmbientMusicPreferenceStore | Ortam müziği açık/kapalı tercihi |

Geçmiş, dönüş kurtarma ve müzik tercihi geçici dosya yazımının ardından değiştirme/yeniden adlandırma kullanır. Repository işlem kuyrukları, sıralamanın önemli olduğu yazımları seri hale getirir. Bunlar yerel atomik yazım korumalarıdır; ayrı Firestore işlemlerini dağıtık bir transaction haline getirmez.

---

## 8. Kesintiye Uğrayan Dönüşlerin Kurtarılması

Standart normal ve Ücretsiz Dönüş akışlarında kurtarma anlık görüntüsü, compute sonucu döndükten sonra ve sonuç sunumu tamamlanmadan önce hazırlanır.

Anlık görüntü şunları içerir:

- benzersiz spinId ve zaman damgası;
- kesin hesaplanan kazanç;
- sonuç oyuncu bakiyesi;
- kalan ve birikmiş Ücretsiz Dönüş durumu;
- varsa bekleyen ilk +10 ödül veya +5 yeniden tetikleme;
- Ante/Buy tur işaretleri;
- sonuç havuz sayaçları;
- geçmiş bahsi ve geçmiş kimliği.

İşletim sistemi sunum sırasında süreci sonlandırırsa başlangıç, normal oyun devam etmeden önce bu anlık görüntüyü yükler. Uygulama mutlak sonuç değerlerini geri yükler, kalıcılaştırır ve spinId ile geçmişi yalnızca bir kez kaydeder. Sembolleri veya kazancı yeniden hesaplamaz.

Normal tamamlanma akışında anlık görüntü sonuçlandırmadan sonra kapatılır. Bekleyen bir Ücretsiz Dönüş ödül popup'ı varsa sonraki açılışın doğru popup'ı ve durumu geri yükleyebilmesi için kayıt kullanıcı onayına kadar korunur.

Güncel kapsam: kurtarma günlüğü standart normal dönüşleri ve aktif Ücretsiz Dönüşleri korur. Ücretli Özellik Satın Alma tetikleme dönüşü kendi zorunlu tetikleme akışını izler ve şu anda kurtarma günlüğü üzerinden hazırlanmaz.

---

## 9. Ücretsiz Dönüş Sunum Akışı

Ücretsiz Dönüşler motor durumunu ve ayrı bir sunum sırasını kullanır:

1. ana oyun sonucu 10 dönüş verir veya aktif tur 5 dönüş yeniden tetikler;
2. ödül geçişi ve popup sunulur;
3. kullanıcı popup'ı onaylayana kadar otomatik oynatım bekler;
4. sonraki dönüşler mevcut tüm sunum korumaları temizlendikten sonra otomatik başlar;
5. yeniden tetikleme, +5 popup'ı gösterildiğinde görünür hale gelir;
6. son dönüş sunumu tamamlandıktan sonra özet gösterilir.

Devre dışı spin kontrolü bu modda kalan sayıyı gösteren bir yüzey olarak kalır; Ücretsiz Dönüşler manuel spin butonu girişine bağlı değildir.

---

## 10. Ses Mimarisi

### Ortam Müziği

AmbientMusicService, seri senkronizasyona sahip uygulama kapsamlı bir singleton'dır:

- oynatma istekleri, yaşam döngüsü, tercih ve kurtarma değişiklikleri birleştirilir;
- yalnızca bir ortam müziği oynatıcısı tutulur;
- arka plan durumları oynatmayı duraklatır;
- resumed durumundaki oynatma kalıcı tercihe uyar;
- hatalar sınırlı sıklıkta loglanır ve tek gecikmeli kurtarma yolu kullanır;
- yalnızca kurtarma gerektiğinde yeni oynatıcı oluşturulur.

### Ses Efektleri

Kısa efektler BoundedAudioPool kullanır:

- uygun yerlerde düşük gecikmeli oynatma modu;
- açık eşzamanlı oynatma sınırı;
- zamanlı durdurma/serbest bırakma;
- sınırlı boşta oynatıcı;
- ön yükleme desteği;
- güvenli dispose ve sınırlı debug loglama.

Arayüz tıklama ve çarpan bombası efektleri başlangıç/oyun hazırlığında önceden yüklenir. Böylece uzun oturumlarda sınırsız medya oynatıcısı tekrar tekrar oluşturulmaz.

---

## 11. Görsel ve Animasyon Yaşam Döngüsü

Varlık hattı, bütün kaynak görsellerin hemen tam boyutta decode edilmesini önler:

- normal ve Ücretsiz Dönüş arka planları kaynak genişliğini aşmadan cihazın fiziksel genişliğine göre decode edilir;
- açılış grid'indeki semboller önce önbelleğe alınır;
- kalan semboller gecikme sonrasında üçlü gruplar halinde yüklenir;
- sembol görselleri 256 piksel decode genişliği kullanır;
- çarpan etiketleri 384 piksel decode genişliği kullanır;
- kritik popup ve çarpan varlıkları erkenden yüklenir;
- Ücretsiz Dönüş özeti ilgili akış için yüklenir ve sonrasında açıkça önbellekten çıkarılır;
- Ücretsiz Dönüş arka planı oyun başlangıcında hazırlanır;
- pahalı oyun alanları uygun yerlerde repaint boundary ile izole edilir.

Bomba Lottie animasyon verisi önceden ayrıştırılır; görsel sıralaması ve havuzlanmış ses oynatımı sunum katmanının sorumluluğunda kalır.

---

## 12. Test Stratejisi

Repository şu anda aşağıdaki alanları kapsayan 45 Dart test dosyası ve bir Firestore Güvenlik Kuralları emülatör test paketi içerir:

- kimlik doğrulama ViewModel'leri ve doğrulama arayüzü;
- parola sıfırlama sınırı;
- uygulama ses yaşam döngüsü ve kalıcı tercih;
- sınırlı ses havuzları;
- image-provider decode kararları;
- slot controller'ları ve Ücretsiz Dönüş sunumu;
- kesin kesintili dönüş kurtarması ve sonuçlandırma;
- Firestore hesap izolasyonu, başlangıç profili bütünlüğü ve sunucuya ait koleksiyonlar;
- sembol registry'si ve çarpan varlıkları;
- RTP, mod kalibrasyonu, Ante, Özellik Satın Alma, tumble dağılımı ve stres simülasyonları.

Normal geliştirmede hedefli unit/widget testleri çalıştırılmalıdır. Firestore kuralları, kimlik doğrulama kalıcılığı veya Firebase veri yolları değiştiğinde `npm run test:firestore` çalıştırılmalıdır. Kök seviyedeki matematik simülasyonları milyonlarca dönüş çalıştırabilir ve motor ağırlıkları, ödeme kuralları, havuz mantığı, Ante veya Özellik Satın Alma davranışı değiştiğinde açıkça seçilmelidir.

---

## 13. Bilinen Mimari Sınırlar

- Yerel kalıcılık doğrudan dart:io kullandığından uygulama mobil odaklıdır.
- Bazı somut repository'ler sunum katmanındaki bağımlılık oluşturma noktalarında seçilir; proje katı ve saf bir Clean Architecture uygulaması değildir.
- Firestore oyuncu, havuz ve yerel kurtarma yazımları koordine edilir ancak tek bir dağıtık atomik transaction değildir.
- Mod kalibrasyon hedefleri simülasyon referanslarıdır; kısa oturum çalışma zamanı garantileri değildir.
