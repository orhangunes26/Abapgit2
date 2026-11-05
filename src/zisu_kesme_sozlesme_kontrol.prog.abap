*&---------------------------------------------------------------------*
*& Report  ZISU_KESME_SOZLESME_KONTROL
*&---------------------------------------------------------------------*
*& Amaç : Kesme başlatıldı / kesik durumdaki tesisatlarda, kesme
*&        tarihindeki ISU sözleşmesinin güncel olup olmadığını raporlar.
*&        Kesme sonrası fesih + yeni abonelik yapılanları listeler.
*&
*& Mantık:
*&   1) EDISCDOC'tan seçilen statüdeki kesme belgeleri okunur
*&   2) Kesme tarihi = EDISCACT-ACTDATE (son aktivite), yoksa belge ERDAT
*&   3) Tesisatın EVER sözleşmeleri içinde kesme tarihinde geçerli olan
*&      sözleşme bulunur (EINZDAT <= kesme tarihi <= AUSZDAT)
*&   4) AUSZDAT = 31.12.9999 ise sözleşme hâlâ güncel (G)
*&      Değilse fesih edilmiş; kesme tarihinden sonra başlayan başka
*&      sözleşme varsa Fesih + Yeni abonelik (Y), yoksa Fesih (F)
*&
*& NOT: Alan/statü değerleri sistemden sisteme değişebilir; SE11'de
*&      EDISCDOC, EDISCACT, EVER alanlarını ve DISCSTATUS domain
*&      değerlerini doğrulayın (bkz. "DOGRULA" yorumları).
*&---------------------------------------------------------------------*
REPORT zisu_kesme_sozlesme_kontrol.

TABLES: ediscdoc, ever.

TYPES: BEGIN OF ty_out,
         discno     TYPE ediscdoc-discno,
         status     TYPE ediscdoc-status,
         anlage     TYPE ever-anlage,
         discdate   TYPE sy-datum,
         vertrag    TYPE ever-vertrag,      " kesme tarihindeki sözleşme
         vkonto     TYPE ever-vkonto,
         gpart      TYPE fkkvkp-gpart,
         einzdat    TYPE ever-einzdat,
         auszdat    TYPE ever-auszdat,
         durum      TYPE c LENGTH 1,        " G / F / Y / B
         durum_txt  TYPE c LENGTH 30,
         vertrag_n  TYPE ever-vertrag,      " yeni sözleşme
         vkonto_n   TYPE ever-vkonto,
         gpart_n    TYPE fkkvkp-gpart,
         einzdat_n  TYPE ever-einzdat,
         musteri_dg TYPE c LENGTH 1,        " iş ortağı değişti mi
       END OF ty_out.

TYPES: BEGIN OF ty_doc,
         discno    TYPE ediscdoc-discno,
         status    TYPE ediscdoc-status,
         refobjkey TYPE ediscdoc-refobjkey,
         erdat     TYPE ediscdoc-erdat,
         anlage    TYPE ever-anlage,        " ALPHA dönüşümü yapılmış tesisat
       END OF ty_doc,
       BEGIN OF ty_act,
         discno  TYPE ediscact-discno,
         actdate TYPE ediscact-actdate,
       END OF ty_act,
       BEGIN OF ty_ever,
         vertrag TYPE ever-vertrag,
         anlage  TYPE ever-anlage,
         vkonto  TYPE ever-vkonto,
         einzdat TYPE ever-einzdat,
         auszdat TYPE ever-auszdat,
       END OF ty_ever,
       BEGIN OF ty_vkp,
         vkont TYPE fkkvkp-vkont,
         gpart TYPE fkkvkp-gpart,
       END OF ty_vkp.

DATA: gt_doc  TYPE STANDARD TABLE OF ty_doc,
      gt_act  TYPE HASHED TABLE OF ty_act WITH UNIQUE KEY discno,
      gt_ever TYPE SORTED TABLE OF ty_ever WITH NON-UNIQUE KEY anlage einzdat vertrag,
      gt_vkp  TYPE SORTED TABLE OF ty_vkp WITH NON-UNIQUE KEY vkont,
      gt_out  TYPE STANDARD TABLE OF ty_out,
      gs_out  TYPE ty_out.

CONSTANTS: gc_sonsuz TYPE sy-datum VALUE '99991231'.

*----------------------------------------------------------------------*
* Seçim ekranı
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
SELECT-OPTIONS: s_discno FOR ediscdoc-discno,
                s_stat   FOR ediscdoc-status OBLIGATORY, " DOGRULA: 'kesme başlatıldı' ve 'kesik' statü kodları (DISCSTATUS)
                s_date   FOR sy-datum,                   " kesme tarihi aralığı
                s_anl    FOR ever-anlage.
PARAMETERS: p_only AS CHECKBOX DEFAULT 'X'.             " sadece fesih + yeni abonelik olanlar
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM get_data.
  PERFORM process_data.
  PERFORM show_alv.

*&---------------------------------------------------------------------*
FORM get_data.
  " DOGRULA: Tesisat bilgisi EDISCDOC-REFOBJKEY'de (REFOBJTYPE = 'INSTLN')
  "         tutuluyorsa aşağıdaki gibi; farklıysa EDISCOBJ üzerinden alın.
  SELECT discno status refobjkey erdat
    FROM ediscdoc
    INTO CORRESPONDING FIELDS OF TABLE gt_doc
    WHERE discno IN s_discno
      AND status IN s_stat
      AND refobjtype = 'INSTLN'.

  " Tesisat numarasını bir kez hesapla; tesisat filtresine uymayanları
  " sonraki SELECT'lerden önce ele (gereksiz veri okunmasın)
  LOOP AT gt_doc ASSIGNING FIELD-SYMBOL(<ls_doc>).
    <ls_doc>-anlage = |{ <ls_doc>-refobjkey ALPHA = IN }|.
  ENDLOOP.
  DELETE gt_doc WHERE anlage NOT IN s_anl.

  IF gt_doc IS INITIAL.
    MESSAGE 'Seçime uygun kesme belgesi bulunamadı' TYPE 'S' DISPLAY LIKE 'W'.
    LEAVE LIST-PROCESSING.
  ENDIF.

  " Kesme tarihi için aktivite kayıtları; belge başına en son tarih
  " DOGRULA: EDISCACT-ACTDATE alan adı
  DATA lt_act TYPE STANDARD TABLE OF ty_act WITH EMPTY KEY.
  SELECT discno actdate
    FROM ediscact
    INTO TABLE lt_act
    FOR ALL ENTRIES IN gt_doc
    WHERE discno = gt_doc-discno.
  SORT lt_act BY discno actdate DESCENDING.
  DELETE ADJACENT DUPLICATES FROM lt_act COMPARING discno.
  gt_act = lt_act.

  " Tesisatlara ait tüm sözleşmeler (silinme işaretlileri hariç)
  DATA lt_anl TYPE STANDARD TABLE OF ever-anlage WITH EMPTY KEY.
  lt_anl = VALUE #( FOR ls_d IN gt_doc ( ls_d-anlage ) ).
  SORT lt_anl.
  DELETE ADJACENT DUPLICATES FROM lt_anl.

  SELECT vertrag anlage vkonto einzdat auszdat
    FROM ever
    INTO TABLE gt_ever
    FOR ALL ENTRIES IN lt_anl
    WHERE anlage = lt_anl-table_line
      AND loevm  = space.

  " Sözleşme hesabı -> iş ortağı (tekil hesap listesiyle)
  IF gt_ever IS NOT INITIAL.
    DATA lt_vkont TYPE STANDARD TABLE OF fkkvkp-vkont WITH EMPTY KEY.
    lt_vkont = VALUE #( FOR ls_e IN gt_ever ( ls_e-vkonto ) ).
    SORT lt_vkont.
    DELETE ADJACENT DUPLICATES FROM lt_vkont.

    SELECT vkont gpart
      FROM fkkvkp
      INTO TABLE gt_vkp
      FOR ALL ENTRIES IN lt_vkont
      WHERE vkont = lt_vkont-table_line.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
FORM process_data.
  DATA: lv_anl  TYPE ever-anlage,
        lv_date TYPE sy-datum.

  LOOP AT gt_doc INTO DATA(ls_doc).
    CLEAR gs_out.
    gs_out-discno = ls_doc-discno.
    gs_out-status = ls_doc-status.
    lv_anl        = ls_doc-anlage.
    gs_out-anlage = lv_anl.

    " Kesme tarihi: en son aktivite tarihi, yoksa belge oluşturma tarihi
    READ TABLE gt_act INTO DATA(ls_act) WITH KEY discno = ls_doc-discno.
    IF sy-subrc = 0 AND ls_act-actdate IS NOT INITIAL.
      lv_date = ls_act-actdate.
    ELSE.
      lv_date = ls_doc-erdat.
    ENDIF.
    gs_out-discdate = lv_date.

    IF lv_date NOT IN s_date.
      CONTINUE.
    ENDIF.

    " Kesme tarihinde geçerli sözleşme
    DATA(lv_found) = abap_false.
    LOOP AT gt_ever INTO DATA(ls_ever) WHERE anlage = lv_anl.
      IF ls_ever-einzdat <= lv_date AND ls_ever-auszdat >= lv_date.
        lv_found       = abap_true.
        gs_out-vertrag = ls_ever-vertrag.
        gs_out-vkonto  = ls_ever-vkonto.
        gs_out-einzdat = ls_ever-einzdat.
        gs_out-auszdat = ls_ever-auszdat.
        READ TABLE gt_vkp INTO DATA(ls_vkp) WITH KEY vkont = ls_ever-vkonto.
        IF sy-subrc = 0.
          gs_out-gpart = ls_vkp-gpart.
        ENDIF.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_found = abap_false.
      gs_out-durum     = 'B'.
      gs_out-durum_txt = 'Kesme tarihinde sözleşme bulunamadı'.
    ELSEIF gs_out-auszdat = gc_sonsuz.
      gs_out-durum     = 'G'.
      gs_out-durum_txt = 'Sözleşme güncel'.
    ELSE.
      " Fesih edilmiş; kesme tarihinden sonra başlayan yeni sözleşme ara
      gs_out-durum     = 'F'.
      gs_out-durum_txt = 'Fesih edilmiş, yeni abonelik yok'.
      LOOP AT gt_ever INTO ls_ever
           WHERE anlage  = lv_anl
             AND vertrag <> gs_out-vertrag
             AND einzdat >  lv_date
             AND einzdat >= gs_out-auszdat.
        gs_out-durum      = 'Y'.
        gs_out-durum_txt  = 'Fesih + yeni abonelik'.
        gs_out-vertrag_n  = ls_ever-vertrag.
        gs_out-vkonto_n   = ls_ever-vkonto.
        gs_out-einzdat_n  = ls_ever-einzdat.
        READ TABLE gt_vkp INTO ls_vkp WITH KEY vkont = ls_ever-vkonto.
        IF sy-subrc = 0.
          gs_out-gpart_n = ls_vkp-gpart.
        ENDIF.
        IF gs_out-gpart_n <> gs_out-gpart.
          gs_out-musteri_dg = 'X'.
        ENDIF.
        EXIT.   " ilk (en erken) yeni sözleşme
      ENDLOOP.
    ENDIF.

    IF p_only = abap_true AND gs_out-durum <> 'Y'.
      CONTINUE.
    ENDIF.

    APPEND gs_out TO gt_out.
  ENDLOOP.

  SORT gt_out BY discdate anlage.
ENDFORM.

*&---------------------------------------------------------------------*
FORM show_alv.
  IF gt_out IS INITIAL.
    MESSAGE 'Kriterlere uyan kayıt yok' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  DATA: lo_alv TYPE REF TO cl_salv_table.

  TRY.
      cl_salv_table=>factory( IMPORTING r_salv_table = lo_alv
                              CHANGING  t_table      = gt_out ).

      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).
      lo_alv->get_columns( )->set_optimize( abap_true ).

      DATA(lo_cols) = lo_alv->get_columns( ).
      lo_cols->get_column( 'DISCNO'     )->set_long_text( 'Kesme belgesi' ).
      lo_cols->get_column( 'STATUS'     )->set_long_text( 'Kesme statüsü' ).
      lo_cols->get_column( 'ANLAGE'     )->set_long_text( 'Tesisat' ).
      lo_cols->get_column( 'DISCDATE'   )->set_long_text( 'Kesme tarihi' ).
      lo_cols->get_column( 'VERTRAG'    )->set_long_text( 'Eski sözleşme' ).
      lo_cols->get_column( 'VKONTO'     )->set_long_text( 'Eski söz. hesabı' ).
      lo_cols->get_column( 'GPART'      )->set_long_text( 'Eski iş ortağı' ).
      lo_cols->get_column( 'EINZDAT'    )->set_long_text( 'Eski giriş tarihi' ).
      lo_cols->get_column( 'AUSZDAT'    )->set_long_text( 'Eski çıkış tarihi' ).
      lo_cols->get_column( 'DURUM'      )->set_technical( abap_true ).
      lo_cols->get_column( 'DURUM_TXT'  )->set_long_text( 'Durum' ).
      lo_cols->get_column( 'VERTRAG_N'  )->set_long_text( 'Yeni sözleşme' ).
      lo_cols->get_column( 'VKONTO_N'   )->set_long_text( 'Yeni söz. hesabı' ).
      lo_cols->get_column( 'GPART_N'    )->set_long_text( 'Yeni iş ortağı' ).
      lo_cols->get_column( 'EINZDAT_N'  )->set_long_text( 'Yeni giriş tarihi' ).
      lo_cols->get_column( 'MUSTERI_DG' )->set_long_text( 'İş ortağı değişti' ).

      lo_alv->display( ).
    CATCH cx_salv_msg cx_salv_not_found INTO DATA(lx).
      MESSAGE lx->get_text( ) TYPE 'E'.
  ENDTRY.
ENDFORM.
