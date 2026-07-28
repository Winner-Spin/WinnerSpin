# Firestore kurallarını Rules Playground ile doğrulama

`npm test` (emulator) çalıştıramadığın durumda, `gameHistory` kuralını Firebase
Console üzerinden elle doğrulamak için adımlar. Playground **editördeki**
kuralları çalıştırır, yayınlanmış olanları değil — yani publish etmeden test
edebilirsin.

## Hazırlık

1. Firebase Console → **Firestore Database** → **Rules** sekmesi.
2. Projedeki `firestore.rules` dosyasının tamamını editöre yapıştır. **Publish
   etme**, sadece editörde dursun.
3. Sağ üstteki **Rules Playground**'u aç.
4. Kendi UID'ni al: **Authentication** → **Users** → kullanıcının `User UID`
   sütunu. Aşağıda `<UID>` yazan yere onu koyacaksın.

> `update` simülasyonlarının çalışması için o kullanıcının `users/<UID>`
> dokümanının gerçekten var olması gerekir. Yoksa önce uygulamaya bir kez giriş
> yap.

## Senaryolar

Her senaryoda ortak ayarlar:

- **Simulation type:** `update`
- **Authenticated:** açık
- **Provider:** Email/Password
- **Firebase UID:** `<UID>`

### 1. 10 kayıt yazılabilmeli → **Allow** beklenir

**Location:** `/users/<UID>`

```json
{
  "gameHistory": [
    {"id":"s1","playedAt":"2026-07-23T00:01:00.000Z","newBalance":1000,"bet":10,"winAmount":0},
    {"id":"s2","playedAt":"2026-07-23T00:02:00.000Z","newBalance":1000,"bet":10,"winAmount":0},
    {"id":"s3","playedAt":"2026-07-23T00:03:00.000Z","newBalance":1000,"bet":10,"winAmount":0},
    {"id":"s4","playedAt":"2026-07-23T00:04:00.000Z","newBalance":1000,"bet":10,"winAmount":0},
    {"id":"s5","playedAt":"2026-07-23T00:05:00.000Z","newBalance":1000,"bet":10,"winAmount":0},
    {"id":"s6","playedAt":"2026-07-23T00:06:00.000Z","newBalance":1000,"bet":10,"winAmount":0},
    {"id":"s7","playedAt":"2026-07-23T00:07:00.000Z","newBalance":1000,"bet":10,"winAmount":0},
    {"id":"s8","playedAt":"2026-07-23T00:08:00.000Z","newBalance":1000,"bet":10,"winAmount":0},
    {"id":"s9","playedAt":"2026-07-23T00:09:00.000Z","newBalance":1000,"bet":10,"winAmount":0},
    {"id":"s10","playedAt":"2026-07-23T00:10:00.000Z","newBalance":1000,"bet":10,"winAmount":0}
  ]
}
```

### 2. 11 kayıt reddedilmeli → **Deny** beklenir

Aynı location, yukarıdaki listeye bir tane daha ekle:

```json
{"id":"s11","playedAt":"2026-07-23T00:11:00.000Z","newBalance":1000,"bet":10,"winAmount":0}
```

Bu, `gameHistory.size() <= 10` kuralını sınar. **Allow** çıkarsa sınır
çalışmıyordur.

### 3. Liste olmayan değer reddedilmeli → **Deny** beklenir

**Location:** `/users/<UID>`

```json
{"gameHistory": {"id": "s1"}}
```

`gameHistory is list` kontrolünü sınar.

### 4. Başkasının dokümanına yazılamamalı → **Deny** beklenir

**Location:** `/users/baskasinin-uid-si`
(Authentication listesinden ikinci bir kullanıcının UID'si; yoksa uydurma bir
metin de olur, sonuç yine Deny olmalı.)

```json
{"gameHistory": [{"id":"s1","playedAt":"2026-07-23T00:01:00.000Z","newBalance":1000,"bet":10,"winAmount":0}]}
```

`isOwner(userId)` kontrolünü sınar.

### 5. İzinsiz alan hâlâ reddedilmeli → **Deny** beklenir

Bu, `gameHistory`'yi izin listesine eklerken yanlışlıkla kapıyı açmadığımı
doğrular.

**Location:** `/users/<UID>`

```json
{"gameHistory": [], "username": "yeni-isim"}
```

## Sonuç

Beklenen tablo:

| # | Senaryo | Beklenen |
|---|---|---|
| 1 | 10 kayıt | Allow |
| 2 | 11 kayıt | Deny |
| 3 | liste değil | Deny |
| 4 | başka kullanıcı | Deny |
| 5 | username değişikliği | Deny |

Beşi de tutuyorsa kurallar doğru. Sonra editördeki kuralları **Publish** et
(veya `firebase deploy --only firestore:rules`).

Bir tanesi bile beklenenden farklı çıkarsa, hangi senaryo ve ne sonuç verdiğini
not al — kuralda düzeltilecek yer var demektir.
