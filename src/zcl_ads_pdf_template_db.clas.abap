*=====================================================================
* Tên/Mã     : ZCL_ADS_PDF_TEMPLATE_DB
* Mô tả chung: Đọc template XDP / ảnh logo từ bảng ZADS_A_TEMPLATE
*              (upload qua app ZUI_ADS_TEMPLATE_O4), một lần SELECT cho
*              nhiều mã
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_ADS_PDF
*=====================================================================
* Version   Ngày          Người sửa                Transport      Mô tả
*=====================================================================
* 1.0       30/10/2026    CB9980000013 - CuongUS   AK3K908751     Tạo mới
*=====================================================================
CLASS zcl_ads_pdf_template_db DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ads_pdf_template_source.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ads_pdf_template_db IMPLEMENTATION.

  METHOD zif_ads_pdf_template_source~get_templates.
    DATA lt_id TYPE SORTED TABLE OF zif_ads_pdf_template_source=>ty_template_id WITH UNIQUE KEY table_line.
    DATA lt_id_range TYPE RANGE OF zif_ads_pdf_template_source=>ty_template_id.

    LOOP AT it_template_id INTO DATA(lv_id) WHERE table_line IS NOT INITIAL.
      INSERT CONV zif_ads_pdf_template_source=>ty_template_id( to_upper( lv_id ) ) INTO TABLE lt_id.
    ENDLOOP.
    IF lt_id IS INITIAL.
      RETURN.
    ENDIF.

    "Range thay FOR ALL ENTRIES: FAE + cột RAWSTRING chặn tối ưu hoá phía DB
    lt_id_range = VALUE #( FOR lv_key IN lt_id ( sign = 'I' option = 'EQ' low = lv_key ) ).

    SELECT template_id, file_content, mime_type, template_version
      FROM zads_a_template
      WHERE template_id IN @lt_id_range
      INTO TABLE @DATA(lt_db).

    rt_template = VALUE #( FOR ls_db IN lt_db
                           ( template_id = ls_db-template_id
                             content     = ls_db-file_content
                             mime_type   = ls_db-mime_type
                             version     = ls_db-template_version
                             embed_fonts = abap_true ) ).
  ENDMETHOD.

ENDCLASS.