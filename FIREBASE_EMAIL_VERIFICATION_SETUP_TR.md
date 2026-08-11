# Firebase E-posta Doğrulama ve Hesap Servisleri

TR Türkçe | [EN English](FIREBASE_EMAIL_VERIFICATION_SETUP.md)

Bu belge Winner Spin'in güncel Firebase e-posta doğrulama akışını, doğrulanmış durumun Firestore ile eşitlenmesini ve istemci tarafındaki hesap silme akışını açıklar.

Aşağıdaki bütün komutlarda kendi Firebase proje kimliğinizi kullanın.

---

## 1. E-posta Doğrulama

Winner Spin, Firebase Authentication'ın yerleşik e-posta doğrulama bağlantısını kullanır:

1. Kayıt işlemi Firebase kullanıcısını oluşturur ve oturumu açar.
2. Uygulama bir doğrulama e-postası gönderilmesini ister.
3. Kullanıcı e-postadaki Firebase **E-postayı Doğrula** bağlantısını açar.
4. Uygulama yeniden ön plana geldiğinde Firebase kullanıcısını tekrar yükler.
5. Kimlik doğrulama kapısı yalnızca Firebase token'ında e-postası doğrulanmış görünen kullanıcıları oyuna alır.
6. Doğrulama ekranı yeniden gönderme işlemini 60 saniyede bir ile sınırlar; Firebase ayrıca kendi kötüye kullanım sınırlarını uygular.

Bu akış Cloud Functions, Trigger Email uzantısı veya özel bir SMTP sunucusu gerektirmez.

### Firebase Console Yapılandırması

1. Firebase Console'da projenizi açın.
2. **Authentication > Sign-in method** bölümüne gidin.
3. **Email/Password** seçeneğini etkinleştirin.
4. **Authentication > Templates > Email address verification** bölümüne gidin.
5. Şablonu etkin durumda bırakın; gerekiyorsa gönderen adını, konuyu ve içeriği özelleştirin.

---

## 2. Doğrulanmış Durumun Firestore ile Eşitlenmesi

Firebase Authentication kullanıcıyı doğrulanmış olarak bildirdikten sonra uygulama, users/{uid}.emailVerified alanını mümkün olan en iyi şekilde güncellemeye çalışır.

Repository'deki Firestore kurallarını dağıtın:

~~~sh
firebase deploy --only firestore:rules --project=YOUR_PROJECT_ID
~~~

Kural, oturum açmış kullanıcının emailVerified alanını yalnızca Firebase Authentication token'ında doğrulanmış e-posta claim'i bulunduğunda true olarak ayarlamasına izin verir.

Bu Firestore kuralları dağıtılmasa bile Firebase Authentication doğrulama bağlantısı çalışır. Yalnızca doğrulanmış durumun Firestore profil belgesine eşitlenmesi başarısız olabilir.

---

## 3. Tam Hesap Silme

Tam hesap silme işlemi hem profil hem de doğrulanmamış e-posta ekranından kullanılabilir ve tamamen istemci tarafında çalışır. Kullanıcının kimliği yeniden doğrulandıktan sonra varsa bilgilendirme onayı arşivlenir, `users/{uid}` ile eski `emailVerifications/{uid}` dokümanı tek batch içinde silinir, kullanıcının yerel dosyaları UID bazında bloke edilip temizlenir ve en son Firebase Authentication kullanıcısı kaldırılır. Yerel temizliğin Authentication silme işleminden önce yapılması, yarıda kalan bir temizliğin güvenli tekrar deneme için auth hesabını korumasını sağlar. Son adım başarısız olursa giriş sonrası profil kapısı eksik hesabın oyuna girmesini engeller ve güvenli tekrar deneme veya çıkış yolu sunar.

Bu sıra değiştirilemez. Firestore kuralları profili yalnızca sahibine sildirdiği için, doküman silinene kadar Authentication kullanıcısının yaşaması gerekir.

İşlem Cloud Functions veya faturalandırma hesabı gerektirmez. Firestore kurallarının dağıtılmış olması gerekir. Yıkıcı yazmalar için sahip token'ındaki `auth_time` en fazla beş dakika önce olmalı ve gelecekte olmamalıdır; silmeden hemen önce yapılan yeniden kimlik doğrulaması bu güncel token'ı sağlar:

~~~sh
firebase deploy --only firestore:rules --project=YOUR_PROJECT_ID
~~~

Arşivlenen onay kaydı yalnızca bir kez oluşturulabilir ve hiçbir istemciden okunamaz. Hesabı geride bıraktığı için 18+ onayı sonradan da belgelenebilir.

---

## 4. Güvenlik Notları

- Servis hesabı dosyalarını, özel anahtarları, erişim token'larını, parolaları ve OAuth client secret bilgilerini gizli tutun.
- Kimlik bilgilerini repository'ye göndermeyin veya dokümantasyona eklemeyin.
- Firebase proje kimlikleri ve istemci yapılandırma değerleri birer tanımlayıcıdır; yetkilendirme kontrolü değildir.
- Verileri ve callable işlemleri Firebase Authentication, yetkilendirme kontrolleri ve Firestore Security Rules ile koruyun.
- Yalnızca güncel uygulama akışının ihtiyaç duyduğu Firebase servislerini dağıtın.
