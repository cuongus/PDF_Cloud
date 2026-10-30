*"* Nguồn template "kế thừa": đọc bảng cũ ZCORE_TB_TEMPPDF (package ZPK_ADOBE_PDF)
*"* Minh hoạ: muốn lấy template từ nơi khác chỉ cần implement ZIF_ADS_PDF_TEMPLATE_SOURCE
CLASS lcl_legacy_source DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_ads_pdf_template_source.
ENDCLASS.

CLASS lcl_legacy_source IMPLEMENTATION.
  METHOD zif_ads_pdf_template_source~get_templates.
    DATA lt_range TYPE RANGE OF zif_ads_pdf_template_source=>ty_template_id.

    lt_range = VALUE #( FOR lv_id IN it_template_id
                        ( sign = 'I' option = 'EQ' low = to_upper( lv_id ) ) ).
    IF lt_range IS INITIAL.
      RETURN.
    ENDIF.

    "Bảng cũ lưu mã hoa/thường lẫn lộn -> so sánh chữ hoa
    SELECT id, file_type, file_content
      FROM zcore_tb_temppdf
      WHERE upper( id ) IN @lt_range
      INTO TABLE @DATA(lt_db).

    LOOP AT lt_db INTO DATA(ls_db).
      "FILE_CONTENT kiểu STRING chứa nội dung dạng hex -> CONV xstring
      INSERT VALUE #( template_id = to_upper( ls_db-id )
                      content     = CONV xstring( ls_db-file_content )
                      mime_type   = ls_db-file_type
                      embed_fonts = abap_true ) INTO TABLE rt_template.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.