# Oyun Mekanikleri

TR Türkçe | [EN English](GAME_MECHANICS.md)

Bu belge Winner Spin'in güncel slot kurallarını, ödeme hesabını, Ücretsiz Dönüş akışını, havuz modlarını ve oyuncu kontrollerini açıklar.

---

## 1. Motor Özeti

Winner Spin özel bir Dart slot motoru kullanır. Bir dönüş, makara ve kazanç animasyonları sunulmadan önce eksiksiz bir SpinResult olarak hesaplanır.

Motor şunlardan sorumludur:

- mevcut havuz modunu seçmek;
- moda duyarlı sembol ağırlıklarını oluşturmak;
- güvenli veya kazançlı grid üretmek;
- pay-anywhere kazançlarını ve tumble'ları çözmek;
- son grid'deki çarpanları toplamak;
- scatter ödemesini ve Ücretsiz Dönüşleri değerlendirmek;
- havuz karşılanabilirlik ve azami kazanç korumalarını uygulamak;
- ekranda görünen kesin ödemeyi döndürmek.

SpinExecutionController motoru Flutter compute üzerinden çağırır. Motor matematiği geçici arka plan isolate'ında çalışır; animasyonlar ve oyuncu etkileşimi arayüz isolate'ında kalır.

---

## 2. Grid ve Pay-Anywhere Kazançları

Grid 6 sütun ve 5 satır içerir:

~~~text
6 × 5 = 30 sembol konumu
~~~

Normal sembol kazançları **pay-anywhere sayım mekaniğini** kullanır. Konumların bitişik olması gerekmez. Grid'in tamamındaki aynı normal sembolün bütün örnekleri sayılır:

- 8'den az: normal sembol ödemesi yok;
- 8–9: 8 sembol ödeme kademesi;
- 10–11: 10 sembol ödeme kademesi;
- 12 veya daha fazla: 12+ ödeme kademesi.

Bazı iç model adlarında ClusterWin terimi korunmuştur ancak güncel motor bağlantılı/konumsal küme tespiti yapmaz.

### Normal Sembol Ödemeleri

Bütün değerler seçili temel bahsin çarpanıdır.

| Sembol kimliği | 8–9 | 10–11 | 12+ |
| --- | ---: | ---: | ---: |
| banana | 0,25× | 0,75× | 2× |
| grapes | 0,40× | 0,90× | 4× |
| watermelon | 0,50× | 1× | 5× |
| peach | 0,80× | 1,20× | 8× |
| apple | 1× | 1,50× | 10× |
| strawberry | 1,50× | 2× | 12× |
| pink_bear | 2× | 5× | 15× |
| green_bear | 5× | 10× | 25× |
| heart | 10× | 25× | 50× |

---

## 3. Tumble / Cascade Çözümlemesi

Motor kazançlı bir grid'i şu şekilde çözümler:

~~~text
1. Grid genelindeki bütün normal sembolleri say
2. 8+ örneğe sahip bütün sembol türlerini bul
3. Her eşleşen sembol ödemesini hesapla
4. Kazanan bütün normal sembolleri kaldır
5. Yerçekimini uygula
6. Boş konumları doldur
7. Normal sembol kazancı kalmayana kadar tekrarla
8. Son çözümlenen grid'den çarpanları ve scatter'ları oku
9. Eksiksiz SpinResult'ı döndür
~~~

Her TumbleStep şunları saklar:

- kazanan varlık yolları;
- yeniden doldurma sonrası grid;
- tumble kazanç tutarı;
- kazanan konumlarıyla sembol başına kazanç kayıtları.

Motor, sembol ağırlıklarına ve yeni bir kazanç sayımı oluşturma kararına mevcut mod ile Ücretsiz Dönüş profillerini uygulayabilir. Gösterilen ödeme yine gerçekten döndürülen sembollerden gelir.

---

## 4. Scatter Ödemeleri ve Ücretsiz Dönüşler

Cupcake scatter sembolüdür. Scatter ödemesi son çözümlenen grid'e göre ve seçili temel bahsin çarpanı olarak hesaplanır:

| Scatter sayısı | Ödeme |
| --- | ---: |
| 0–3 | 0× |
| 4 | 3× |
| 5 | 5× |
| 6+ | 10× |

İlk 10 Ücretsiz Dönüş girişi doğal olarak tetiklendiğinde veya satın
alındığında giriş grid'i 4–6 cupcake içerir. Kalan hücreler, hiçbir normal
sembolün sekiz sembollük ödeme eşiğine zorunlu olarak ulaşmamasını sağlayacak
şekilde doldurulur. Cupcake giriş ödemesi yine oyuncuya verilir ve gösterilen
birikmiş Ücretsiz Dönüş kazancına dahil edilir.

Ücretsiz Dönüş ödülleri:

~~~text
Ana oyun:          4+ scatter → 10 Ücretsiz Dönüş
Ücretsiz Dönüşler: 3+ scatter → 5 ek Ücretsiz Dönüş
~~~

Motor, iki ödül türünü de SpinResult içinde bildirir. Ana oyundaki tetikleme 10 Ücretsiz Dönüş veren ilk ödül, aktif Ücretsiz Dönüş turundaki tetikleme ise 5 ek dönüş veren yeniden tetikleme olarak işaretlenir. Sunum katmanı bu ayrımı kullanarak doğru 10 dönüş veya +5 popup'ını gösterir, kalan dönüş sayısını belirlenen anda günceller ve oyuncu ödülü onaylayana kadar otomatik oynatımı bekletir.

### Ücretsiz Dönüş Sunumu ve Otomatik Oynatım

1. Geçiş ve ödül popup'ı gösterilir.
2. Oyuncu popup'ı onaylayana kadar Ücretsiz Dönüş otomatik oynatımı bekler.
3. Sonraki Ücretsiz Dönüşler makara, tumble, çarpan ve kazanç sunumu korumaları bittikten sonra otomatik başlar.
4. Yeniden tetiklenen +5, +5 ödül popup'ı gösterildiği anda sayaca yansır.
5. Son sunumdan sonra birikmiş tur özeti gösterilir.

Ortadaki eksi/artı kontrolleri Ücretsiz Dönüşler sırasında gizlenir. Spin kontrolü giriş olarak devre dışıdır ancak görünür kalır ve kalan Ücretsiz Dönüş sayısını gösterir.

---

## 5. Çarpan Toplama ve Nihai Ödeme

Desteklenen çarpan sembolleri:

~~~text
2×, 3×, 5×, 10×, 25×, 50×, 100×
~~~

Son çözümlenen grid'deki çarpan sembolleri toplanır. Birbirleriyle çarpılmazlar. Çarpan yoksa temel kazanç 1 katsayısını kullanır.

Kesin hesap:

~~~text
baseWin = bütün tumble normal sembol kazançlarının toplamı
finalMultiplier = son grid'de görünen çarpan değerlerinin toplamı
totalWin = baseWin × max(1, finalMultiplier) + scatterPayout
~~~

Scatter ödemesi, normal sembol çarpımından sonra eklenir ve toplanan çarpanla çarpılmaz.

Motorun totalWin değeri bakiyeye eklenecek ve kesinti kurtarmasında saklanacak tutardır. Ekranda görünen sembol sonucunun yerine ikinci bir rastgele ödeme kullanılmaz.

---

## 6. Sonuç Üretimi ve Havuz Koruması

Motor her dönüşte:

1. PoolState'ten güncel GameMode'u türetir;
2. mod ve Ücretsiz Dönüş durumuna göre sembol ağırlıklarını ayarlar;
3. yapılandırılmış kazanç/Ücretsiz Dönüş tetikleme yolunu değerlendirir;
4. aday grid'leri üretir ve çözümler;
5. yalnızca ilgili ödeme tavanına uyan sonucu kabul eder;
6. geçerli aday üretilemezse güvenli grid'e döner.

PoolGuard şunları sağlar:

- moda özel ana oyun ve Ücretsiz Dönüş ödeme tavanları;
- Ücretsiz Dönüş karşılanabilirlik tahmini;
- Ante ve Özellik Satın Alma tanıları için ek güvenlik katsayıları;
- ısınma sonrasında kullanılabilir havuz payına dayalı ödeme tavanı.

Kaydedilen ilk 50 ücretli dönüş, mod seçimi ve Ücretsiz Dönüş karşılanabilirliği için ısınma olarak değerlendirilir. Mod ödeme tavanları ısınma sırasında da vardır.

Özellik Satın Alma'nın ücretli zorunlu tetiklemesi, ödeme yapıldıktan sonra satın alınan bonus erişiminin gerçekleşmesi için özel bir fallback'e sahiptir.

---

## 7. RTP ve Havuz Modları

PoolState yalnızca üç sayacı kalıcı olarak saklar:

~~~text
totalBetsPlaced
totalPaidOut
totalSpins
~~~

Şu değerleri türetir:

~~~text
poolBalance = totalBetsPlaced - totalPaidOut
expectedPool = totalBetsPlaced × (1 - 0,965)
actualRTP = totalPaidOut / totalBetsPlaced
~~~

Korumalı uzun dönem hedefi %96,5'tir. Yapılandırılmış mod profilleri:

| Mod | Kalibrasyon hedefi | Amaç |
| --- | ---: | --- |
| recovery | %89,0 | Önemli fazla ödeme sonrasında havuzu korumak |
| tight | %92,0 | Ödeme baskısını azaltmak |
| normal | %96,5 | Varsayılan dengeli davranış |
| generous | %98,0 | Düşük ödeme döneminde ödeme potansiyelini yükseltmek |
| jackpot | %108,0 | Belirli koşullarda kısa yüksek ödeme dönemlerine izin vermek |

Bu mod hedefleri kalibrasyon referanslarıdır; her kısa oturum için garantili ödeme yüzdesi olarak okunmaz.

### Mod Seçimi

- 0–49. dönüşler normal modu kullanır.
- Gerçek RTP hedeften 10 yüzde puanından fazla aşağıdaysa jackpot modu seçilir.
- Gerçek RTP hedeften 10 yüzde puanından fazla yukarıdaysa recovery modu seçilir.
- Diğer durumlarda 50–250 dönüş sürecek oturum modu seçilir:

| Mod | Oturum seçim ağırlığı |
| --- | ---: |
| normal | %65 |
| generous | %17 |
| tight | %13 |
| jackpot | %3 |
| recovery | %2 |

Firestore geçici oturum modu seçimini değil sayaçları saklar. Süreç yeniden başladığında sonraki mod, geri yüklenen sayaçlardan tekrar türetilir.

Kısa çalışmalar ve tekil modlar %96,5'ten önemli ölçüde farklı olabilir. Bu oran uzun dönem korumalı kalibrasyon hedefidir ve bağımsız olarak sertifikalandırılmamıştır.

---

## 8. Özellik Satın Alma

Özellik Satın Alma maliyeti:

~~~text
fiyat = seçili temel bahis × 100
~~~

Canlı arayüz oyuncunun görünen bakiyesini kontrol eder. Ödemeden sonra:

- ücret bakiyeden düşülür;
- ana oyun hesabı zorunlu Ücretsiz Dönüş tetiklemesi açık olarak gönderilir;
- zorunlu normal sembol kümesi kazancı içermeyen 4–6 scatter giriş sonucu
  üretilir;
- ödül sunumu onaylandıktan sonra 10 Ücretsiz Dönüş başlar.

PoolGuard.canAffordBuyFs tanı ve stres testleri için kullanılabilir durumda kalır ancak canlı Özellik Satın Alma arayüz koruması değildir.

---

## 9. Ante Bet

Ante Bet maliyeti ve tetikleme olasılığını değiştirir:

~~~text
dönüş maliyeti = seçili temel bahis × 1,25
ana Ücretsiz Dönüş tetikleme olasılığı = yapılandırılmış oran × 2
~~~

Ante üzerinden girilmiş turdaki Ücretsiz Dönüş isabet sıklığına ek bir kalibrasyon katsayısı uygulanır. Bu katsayı görünen sembol ödeme tablosunu değiştirmez veya totalWin yerine başka bir tutar koymaz.

Ante yalnızca ana oyun girişine uygulanır. Bu dönüş bir Ücretsiz Dönüş turu başlatırsa tur, bitene kadar Ante kaynak işaretini korur.

---

## 10. Otomatik Dönüş ve Hızlı Durdurma

### Normal Otomatik Dönüş

Normal Otomatik Dönüş şunları izler:

- istenen ve kalan dönüş sayısı;
- 1×–3× sunum hızı;
- bakiye yeterliliği;
- aktif dönüş/tumble durumu;
- manuel durdurma;
- tamamlanma ve devam korumaları.

Normal otomatik dönüş sayacı, ilgili ücretli dönüş başladığında bir azalır.

### Ücretsiz Dönüş Otomatik Oynatımı

Ücretsiz Dönüşler ayrı bir sunum controller'ı kullanır. Normal Otomatik Dönüş sayacını tüketmez ve bir ödül onayı veya başka sunum aşaması beklerken başlayamaz.

### Hızlı Durdurma

Makara hareketi sırasında dokunmak mevcut görsel sıralamayı kısaltır ve önceden hesaplanan sonucu daha erken sunar. Sembolleri, ödemeyi, çarpanı, havuz durumunu veya kurtarma anlık görüntüsünü değiştirmez.

### Sanal CREDIT

Ayarlar akışında sanal bir CREDIT yükleme ekranı bulunur. Bu ekran yalnızca Firestore destekli oyun içi bakiyeyi artırır; gerçek para satın alımı işlemez veya gerçek dünyada değeri olan bir varlık oluşturmaz.

---

## 11. Sonuçlandırma ve Kesinti Kurtarması

Normal sunumda kazanç, dönüş tamamlama sırası sonucu kesinleştirdiğinde görünen/uzak bakiyeye ulaşır. Bu zamanlama bilinçli olarak tumble ve çarpan sunumundan sonra korunur.

Standart normal ve aktif Ücretsiz Dönüş yollarında hesaplamadan sonra, sunum tamamlanmadan önce kesin kurtarma anlık görüntüsü yazılır. Süreç sonlandırılırsa:

- saklanan totalWin kullanılır;
- sonuç bakiyesi, Ücretsiz Dönüşler ve havuz sayaçları geri yüklenir;
- geçmiş spinId ile yalnızca bir kez kaydedilir;
- tamamlanmış dönüş için yeni motor sonucu üretilmez.

Ücretli Özellik Satın Alma tetikleme dönüşü şu anda kendi zorunlu tetikleme yolunu izler ve kurtarma günlüğü hazırlama yolunun dışındadır.

---

## 12. Testler ve Kalibrasyon

Hızlı regresyon kapsamı:

- çarpan toplama ve ödeme davranışı;
- zorunlu Özellik Satın Alma scatter sonuçları;
- Ücretsiz Dönüş ödül/otomatik oynatım durumu;
- sonuçlandırma ve kesin kesintili dönüş kurtarması;
- controller ve widget davranışı.

Uzun süren tanılar:

- genel ve mod başına RTP simülasyonları;
- mod ağırlığı kalibrasyonu;
- Ante ve satın alınmış bonus RTP'si;
- gerçekçi oyuncu karışımları;
- tumble dağılımı;
- whale/clustering stres senaryoları.

Uzun simülasyonlar motor ağırlıkları, ödeme tabloları, havuz mantığı, Ante veya Özellik Satın Alma değiştiğinde açıkça çalıştırılmalıdır. Yalnızca sunum değişiklikleri için hızlı smoke paketi olarak tasarlanmamıştır.
