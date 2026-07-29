# Zorunlu güncelleme

Uygulama, Firestore'daki tek bir alana bakarak kendini kilitler. Alan, cihazdaki
sürümden büyükse oyun kullanılamaz; kullanıcı güncellemeden giriş yapamaz,
oynayamaz.

## Firestore kurulumu

Console → Firestore Database → koleksiyon `config`, doküman `appVersion`:

| Alan | Tip | Zorunlu | Örnek |
| --- | --- | --- | --- |
| `androidMinimumVersion` | string | Android için | `1.1.0` |
| `iosMinimumVersion` | string | iOS için | `1.2.0` |
| `androidStoreUrl` | string | hayır | `https://play.google.com/store/apps/details?id=com.winnerspin.game` |
| `iosStoreUrl` | string | hayır | `https://apps.apple.com/app/id6795310235` |
| `minimumVersion` | string | hayır | Platform alanı yoksa kullanılan ortak yedek |

Mağaza adresi boş bırakılırsa uygulama Android'de Play Store, iOS'ta App Store
adresini kullanır. Platform sürümleri ayrı tutulduğu için mağaza yayınları farklı
zamanlarda tamamlanabilir.

Kuralları yayınlamayı unutma:

```bash
firebase deploy --only firestore:rules
```

## Nasıl çalışıyor

Kontrol **uygulamaya her girişte bir kez** yapılır: soğuk açılışta bir kez, her
arka plandan dönüşte bir kez. Aynı anda gelen istekler tek okumaya indirgenir.

Karşılaştırma parça parça sayısaldır, yani `1.10.0` sürümü `1.9.0` eşiğini
karşılar. Metin karşılaştırması olsaydı tersini söylerdi.

Uyarı ekranı `MaterialApp.builder` içinde durur, yani Navigator'ın üstünde.
Bütün sayfaları ve dialogları kapsar; arkadaki oyun `AbsorbPointer` ile
dokunulamaz hale gelir.

## Kilitlememe kuralı

Okuma başarısız olursa uygulama **engellenmez**. Şu durumların hepsi "sorun yok"
sayılır:

- doküman yok
- cihaz çevrimdışı
- Firestore yavaş veya erişilemiyor
- ilgili platform sürümü ve ortak `minimumVersion` alanı yok veya geçersiz

Tersi çok daha kötü olurdu: bir okuma hatası yüzünden bütün oyuncuların
kilitlenmesi. Bu yüzden her hata yolu geçirgen.

## Sürümü yükseltirken

`pubspec.yaml` içindeki `version:` ile `lib/core/update/app_build_info.dart`
içindeki `kAppVersion` aynı olmalı. İkisi ayrışırsa `flutter test` kırmızı verir
— `test/core/update/app_build_info_test.dart` pubspec'i okuyup karşılaştırıyor.

Yayın sırası:

1. `pubspec.yaml` → `version: 1.1.0+2`
2. `app_build_info.dart` → `kAppVersion = '1.1.0'`
3. `flutter test`
4. Yeni sürümü ilgili mağazada yayınla ve **yayında olduğunu doğrula**
5. Android için `androidMinimumVersion`, iOS için `iosMinimumVersion` değerini yükselt

Dördüncü adım önemli: platform sürümünü mağazadaki sürüm gerçekten
indirilebilir olmadan yükseltirsen, kullanıcılar güncelleyemedikleri hâlde
oyuna giremezler.

## Test

Kilidi görmek için cihaz platformuna ait sürüm değerini cihazdakinden büyük bir
şeye çek, örneğin `99.0.0`. Uygulamayı aç — ekran çıkmalı. Değeri geri düşür,
uygulamayı arka plana atıp geri getir — kilit kalkmalı.

Kilitlememe kuralını denemek için dokümanı sil veya platform sürümüyle ortak
`minimumVersion` alanını boş bırak; oyun normal açılmalı.
