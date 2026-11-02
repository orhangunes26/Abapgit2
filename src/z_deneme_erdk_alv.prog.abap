REPORT z_deneme_erdk_alv.

DATA gs_erdk TYPE erdk.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: s_budat FOR gs_erdk-budat,
                  s_opbel FOR gs_erdk-opbel.
  PARAMETERS p_rows TYPE i DEFAULT 1000.
SELECTION-SCREEN END OF BLOCK b1.


CLASS lcl_report DEFINITION FINAL.

  PUBLIC SECTION.
    METHODS run.

  PRIVATE SECTION.
    DATA mt_erdk TYPE STANDARD TABLE OF erdk WITH DEFAULT KEY.

    METHODS select_data.
    METHODS display_alv.

ENDCLASS.


CLASS lcl_report IMPLEMENTATION.

  METHOD run.
    select_data( ).

    IF mt_erdk IS INITIAL.
      MESSAGE 'No data found for the selection.' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    display_alv( ).
  ENDMETHOD.


  METHOD select_data.
    " p_rows = 0 -> tum kayitlar
    SELECT *
      FROM erdk
      WHERE budat IN @s_budat
        AND opbel IN @s_opbel
      ORDER BY opbel
      INTO TABLE @mt_erdk
      UP TO @p_rows ROWS.
  ENDMETHOD.


  METHOD display_alv.
    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = DATA(lo_alv)
          CHANGING
            t_table      = mt_erdk ).

        lo_alv->get_functions( )->set_all( abap_true ).
        lo_alv->get_columns( )->set_optimize( abap_true ).
        lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).
        lo_alv->get_display_settings( )->set_list_header( |ERDK - { lines( mt_erdk ) } records| ).

        lo_alv->display( ).

      CATCH cx_salv_msg INTO DATA(lx_msg).
        MESSAGE lx_msg TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


AT SELECTION-SCREEN.
  IF p_rows < 0.
    MESSAGE 'Max rows must not be negative.' TYPE 'E'.
  ENDIF.

START-OF-SELECTION.
  NEW lcl_report( )->run( ).
