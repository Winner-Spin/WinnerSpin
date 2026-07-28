# Zorunlu güncelleme

Uygulama, Firestore'daki tek bir alana bakarak kendini kilitler. Alan, cihazdaki
sürümden büyükse oyun kullanılamaz; kullanıcı güncellemeden giriş yapamaz,
oynayamaz.

## Firestore kurulumu

Console → Firestore Database → koleksiyon `config`, doküman `appVersion`:

| Alan | Tip | Zorunlu | Örnek |
| --- | --- | --- | --- |
| `minimumVersion` | string | evet | `1.1.0` |
| `storeUrl` | string | hayır | `https://apps.apple.com/app/id6795310235` |

`storeUrl` boş bırakılırsa uygulama kendi içine gömülü App Store adresini
kullanır. Bu alan, ileride Android'e de çıkarsan mağazaya göre farklı adres
vermek istersen işine yarar.

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
- `minimumVersion` boş, sayı, dizi ya da ayrıştırılamaz bir metin

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
4. Yeni sürümü App Store'a yayınla ve **yayında olduğunu doğrula**
5. Ancak ondan sonra Firestore'da `minimumVersion` → `1.1.0`

Dördüncü adım önemli: `minimumVersion`'ı mağazadaki sürüm gerçekten
indirilebilir olmadan yükseltirsen, kullanıcılar güncelleyemedikleri hâlde
oyuna giremezler.

## Test

Kilidi görmek için Console'dan `minimumVersion` değerini cihazdakinden büyük bir
şeye çek, örneğin `99.0.0`. Uygulamayı aç — ekran çıkmalı. Değeri geri düşür,
uygulamayı arka plana atıp geri getir — kilit kalkmalı.

Kilitlememe kuralını denemek için dokümanı sil ya da `minimumVersion`'ı boş
bırak; oyun normal açılmalı.
