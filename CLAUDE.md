# ABAP / abapGit projesi

- Ana paket: `Z_DENEME` (abapGit klasör mantığı: PREFIX, başlangıç klasörü: `/src/`).
- Ana dil: İngilizce (`E`). Açıklamalar XML'de İngilizce, kod yorumları Türkçe olabilir.
- Akış: kod burada yazılır -> GitHub'a push -> SAP'de abapGit ile Pull.

## Dosya kuralları
- Her nesnenin kod dosyasının yanında XML metadata dosyası olmalı:
  - Sınıf: `zcl_x.clas.abap` + `zcl_x.clas.xml`
  - Rapor: `z_x.prog.abap` + `z_x.prog.xml`
  - Interface: `zif_x.intf.abap` + `zif_x.intf.xml`
- Dosya adları küçük harf, `/` içeren namespace'ler `#` ile yazılır.
- Basit nesneler (sınıf, interface, rapor) için XML yazılabilir. Tablo, CDS, ekran, function group gibi
  karmaşık nesneler SAP'de oluşturulup abapGit ile repoya alınmalı.
- Mevcut XML dosyalarını gereksiz yere değiştirme.
- Yeni nesne XML'i yazarken `src/zcl_deneme_hello.clas.xml` (SAP'den abapGit ile gelen gerçek dosya) örnek alınır.
  Sınıf XML'inde kök etiket `<VSEOCLASS>` olmalıdır (`<VSEO_CLASS>` değil). Bu yanlışlık
  "Invalid parameter OBJECT/OBJECTCLASS" hatasına neden olmuştu. Elle `VERSION`/`EXPOSURE` ekleme.

## Kodlama kuralları
- İsimler `Z` ile başlar (sınıf `ZCL_`, interface `ZIF_`, rapor `Z_`).
- Sistem: SAP_BASIS 7.55 (SP 0002). Modern ABAP sözdizimi kullanılabilir (inline declaration, `NEW`,
  `VALUE`, `COND`, `SWITCH`, string template, `REDUCE`, `FILTER`, CDS). 7.56/7.57 ve sonrası özellikleri
  (ör. bazı yeni built-in fonksiyonlar, `RAISE ... EXCEPTION ... MESSAGE` varyantları) kullanılmaz.
- Veritabanı erişiminde yetki kontrolü ve hata yönetimi unutulmaz.
