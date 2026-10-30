*=====================================================================
* Tên/Mã     : ZCX_ADS_PDF
* Mô tả chung: Exception của bộ render PDF ADS (ZPK_ADS_PDF); mang theo
*              mã template và trace ADS để chẩn đoán lỗi
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_ADS_PDF
*=====================================================================
* Version   Ngày          Người sửa                Transport      Mô tả
*=====================================================================
* 1.0       30/10/2026    CB9980000013 - CuongUS   AK3K908751     Tạo mới
*=====================================================================
CLASS zcx_ads_pdf DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Error text shown to the caller
    DATA mv_text        TYPE string READ-ONLY.
    "! Template the error belongs to (if any)
    DATA mv_template_id TYPE string READ-ONLY.
    "! ADS trace string returned by the rendering call (if any)
    DATA mv_trace       TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        textid         LIKE textid   OPTIONAL
        previous       LIKE previous OPTIONAL
        iv_text        TYPE string   OPTIONAL
        iv_template_id TYPE csequence OPTIONAL
        iv_trace       TYPE string   OPTIONAL.

    METHODS get_text REDEFINITION.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcx_ads_pdf IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( textid = textid previous = previous ).
    mv_text        = iv_text.
    mv_template_id = iv_template_id.
    mv_trace       = iv_trace.
  ENDMETHOD.

  METHOD get_text.
    IF mv_text IS NOT INITIAL.
      result = mv_text.
    ELSEIF previous IS BOUND.
      result = previous->get_text( ).
    ELSE.
      result = super->get_text( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.