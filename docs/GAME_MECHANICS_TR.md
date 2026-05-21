# Oyun Mekanikleri

TR Türkçe | [EN English](GAME_MECHANICS.md)

Bu döküman, Winner Spin'de kullanılan slot oyun motorunu, alt sistemlerini ve oyun mekaniklerini açıklar.

---

## Slot Oyun Motoru

Temel oyun mantığı özel bir slot motorundan başlar.

Slot motoru şunlardan sorumludur:

- slot grid'ini oluşturma,
- bir dönüşün kazanıp kazanmayacağına karar verme,
- güvenli grid'ler üretme,
- kazançlı grid'ler üretme,
- küme kazançlarını tespit etme,
- tumble/cascade dizilerini çalıştırma,
- toplam kazancı hesaplama,
- çarpan değerlerini uygulama,
- scatter ödemelerini kontrol etme,
- Ücretsiz Dönüşleri tetikleme,
- Ücretsiz Dönüş yeniden tetiklemelerini yönetme,
- havuz güvenlik limitlerini uygulama,
- mevcut oyun moduna göre davranışı uyarlama.

Oyun **6 sütun x 5 satır** slot grid'i kullanır:

```text
Sütunlar: 6
Satırlar: 5
Toplam:   30 sembol
```

---

## Motor Modülleri

Slot motoru, her sorumluluğu tek bir dosyada tutmak yerine daha küçük motor modüllerine ayrılmıştır.

Önemli motor dosyaları:

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

Bu ayrım, slot motorunun hata ayıklamasını, test edilmesini ve genişletilmesini kolaylaştırır.

---

## Cascade / Tumble Mekanikleri

Winner Spin, cascade tarzı bir slot mekaniği kullanır.

Tumble akışı şu şekilde çalışır:

```text
1. Başlangıç grid'ini oluştur
2. Normal sembolleri say
3. Kazanan kümeleri tespit et
4. Kazanan sembolleri kaldır
5. Yerçekimini uygula
6. Boş hücreleri doldur
7. Kazanan küme kalmayana kadar tekrarla
8. Çarpanları topla
9. Scatter'ları değerlendir
10. Nihai dönüş sonucunu döndür
```

Bir normal sembol, grid üzerinde en az **8 kez** göründüğünde küme kazancı oluşturur.

Her tumble adımı şunları depolar:

- kazanan sembol yolları,
- tumble sonrası grid durumu,
- kazanç miktarı,
- küme kazanç verisi,
- kazanan pozisyonlar.

Bu, oyunu basit bir tek dönüşlük sembol değiştirme sisteminden daha dinamik hale getirir.

---

## Ücretsiz Dönüşler

Ücretsiz Dönüşler scatter sembolleri tarafından tetiklenir.

Ana oyun tetikleme kuralı:

```text
4+ scatter -> Ücretsiz Dönüşler
```

Ücretsiz Dönüş yeniden tetikleme kuralı:

```text
Ücretsiz Dönüşler sırasında 3+ scatter -> Yeniden Tetikleme
```

Ücretsiz Dönüşler aynı slot motoru akışına entegre edilmiştir, ancak motor, dönüşün ana oyun dönüşü mü yoksa ücretsiz dönüş mü olduğuna bağlı olarak isabet oranını, zincir olasılığını, çarpan davranışını ve scatter tetikleme davranışını ayarlayabilir.

---

## Çarpan Toplama

Proje, nihai ödeme potansiyelini artıran çarpan sembolleri içerir.

Örnek çarpan değerleri:

```text
2x
3x
5x
10x
25x
50x
100x
```

Çarpan toplama, tumble simülasyonundan ayrı olarak yönetilir. Bu, çarpan davranışını izole tutar ve motorun bakımını kolaylaştırır.

Nihai kazanç hesaplaması şu genel fikri takip eder:

```text
finalWin = baseWin * finalMultiplier + scatterPayout
(nihaiKazanç = temelKazanç * nihaiÇarpan + scatterÖdemesi)
```

---

## RTP ve Havuz Sistemi

Winner Spin, RTP-duyarlı bir havuz sistemi içerir.

Havuz durumu, motorun kullandığı temel sayaçları saklar:

```text
totalBetsPlaced    (toplam yapılan bahisler)
totalPaidOut       (toplam ödenen miktar)
totalSpins         (toplam dönüş sayısı)
```

Motor, bu sayaçlardan çalışma zamanı değerlerini türetir:

```text
poolBalance        (havuz bakiyesi)
expectedPool       (beklenen havuz)
currentMode        (mevcut mod)
```

Hedef RTP şu değer etrafında tasarlanmıştır:

```text
%96.5
```

Motor, mevcut oyun modunu belirlemek ve davranışı ayarlamak için saklanan sayaçları ve türetilmiş havuz değerlerini kullanır.

Mevcut oyun modları:

| Mod | Amaç |
| --- | --- |
| `normal` | Varsayılan dengeli oyun modu |
| `generous` | Oyun düşük ödeme yaparken ödeme potansiyelini artırır |
| `tight` | Gerektiğinde ödeme baskısını azaltır |
| `jackpot` | Belirli havuz koşullarında daha agresif ödeme potansiyeline izin verir |
| `recovery` | Fazla ödeme sonrası havuzu korur |

Bu, oyun mantığını tamamen rastgele bir sembol üreticisinden daha gelişmiş hale getirir.

---

## Havuz Koruyucusu (Pool Guard)

Havuz Koruyucusu, belirli sonuçların karşılanabilir olup olmadığını kontrol ederek oyun ekonomisini korur.

Kullanım alanları:

- maksimum kazanç hesaplaması,
- Ücretsiz Dönüş karşılanabilirliği,
- ödeme güvenliği,
- kurtarma davranışı,
- havuz taban koruması.

Ayrıca tanısal testler ve stres senaryoları için bir Özellik Satın Alma karşılanabilirlik yardımcısı da sunar. Mevcut oyun içi akışta ise Özellik Satın Alma işlemi oyuncunun görünen bakiyesiyle sınırlandırılır ve ödeme tamamlandıktan sonra doğrudan bonus erişimini garanti etmek için ilk Ücretsiz Dönüş tetiklemesi motora zorlanmış olarak gönderilir.

Bu, normal dönüş sonuçlarının mevcut havuz durumunu kontrol etmeden sınırsız veya güvensiz ödemeler üretmesini engeller.

---

## Özellik Satın Alma (Buy Feature)

Winner Spin, bir Özellik Satın Alma akışı içerir.

Özellik Satın Alma, oyuncunun seçili bahis miktarının sabit bir çarpanını ödeyerek doğrudan bir Ücretsiz Dönüş turuna erişim satın almasına olanak tanır.

Mevcut oyun akışı, oyuncunun ekranda gösterilen Özellik Satın Alma fiyatını karşılayıp karşılayamadığını kontrol eder. Ödeme yapıldıktan sonra dönüş, motora zorlanmış Ücretsiz Dönüş tetiklemesi olarak gönderilir; ayrı havuz karşılanabilirlik yardımcısı ise tanısal testler ve stres senaryoları için kullanılabilir durumda kalır.

Bu özellik, oyuncu deneyimini normal dönüşler ile doğrudan bonus erişimi arasında seçim yapabileceği modern slot oyun mekaniklerine yaklaştırır.

---

## Ante Bet

Proje bir Ante Bet modu içerir.

Ante Bet, dönüşün maliyet/risk profilini etkileyerek Ücretsiz Dönüş tetikleme potansiyelini artıran şekilde dönüş davranışını değiştirir.

Bu özellik, oyuncunun normal dönüşler ile daha yüksek riskli, özellik güçlendirilmiş bir dönüş modu arasında seçim yapmasına olanak tanır.

---

## Otomatik Dönüş (Auto Spin)

Winner Spin, Otomatik Dönüş kontrolleri içerir.

Otomatik Dönüş, sunum ve ViewModel durumu aracılığıyla yönetilir, böylece tekrarlayan dönüşler aşağıdaki oyun koşullarına saygı gösterirken devam edebilir:

- bakiye,
- ücretsiz dönüş durumu,
- dönüş tamamlanması,
- kazanç sunumu,
- hızlı durdurma,
- otomatik dönüş devam korumaları.

Bu, otomatik dönüşlerin mevcut oyun durumunu dikkate almadan çalışmasını engeller.

---

## Hızlı Durdurma (Quick Stop)

Oyun, Hızlı Durdurma etkileşimini destekler.

Oyuncu makara animasyonu sırasında dokunduğunda, animasyon akışı kısaltılabilir ve sonuç daha hızlı sunulabilir.

Bu, oyun hissini iyileştirir ve oyuncuya dönüş hızı üzerinde daha fazla kontrol verir.
