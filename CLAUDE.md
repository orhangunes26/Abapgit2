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

## Kodlama kuralları
- İsimler `Z` ile başlar (sınıf `ZCL_`, interface `ZIF_`, rapor `Z_`).
- Sözdizimi ABAP 7.02 uyumlu tutulur (inline declaration, `NEW`, string template yok) ta ki sistem sürümü
  netleşene kadar. Sürüm netleşince buradan güncelle.
- Veritabanı erişiminde yetki kontrolü ve hata yönetimi unutulmaz.
