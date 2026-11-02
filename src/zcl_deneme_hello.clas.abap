CLASS zcl_deneme_hello DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS get_message
      RETURNING
        VALUE(rv_message) TYPE string.

ENDCLASS.



CLASS zcl_deneme_hello IMPLEMENTATION.

  METHOD get_message.
    rv_message = 'Merhaba SAP, abapGit akisi calisiyor.'.
  ENDMETHOD.

ENDCLASS.
