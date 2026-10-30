*=====================================================================
* Tên/Mã     : ZCL_ADS_PDF_TEMPLATE_FORM
* Mô tả chung: Đọc layout XDP từ object Form (ADT, ABAP Cloud) qua API
*              đã release CL_FP_FORM_READER - layout đi theo transport,
*              cờ "nhúng font" lấy từ thuộc tính của form
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_ADS_PDF
*=====================================================================
* Version   Ngày          Người sửa                Transport      Mô tả
*=====================================================================
* 1.0       30/10/2026    CB9980000013 - CuongUS   AK3K908751     Tạo mới
*=====================================================================
CLASS zcl_ads_pdf_template_form DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ads_pdf_template_source.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ads_pdf_template_form IMPLEMENTATION.

  METHOD zif_ads_pdf_template_source~get_templates.
    DATA lt_id TYPE SORTED TABLE OF zif_ads_pdf_template_source=>ty_template_id WITH UNIQUE KEY table_line.

    LOOP AT it_template_id INTO DATA(lv_id) WHERE table_line IS NOT INITIAL.
      INSERT CONV zif_ads_pdf_template_source=>ty_template_id( to_upper( lv_id ) ) INTO TABLE lt_id.
    ENDLOOP.

    LOOP AT lt_id INTO DATA(lv_form).
      "Tên form tối đa 30 ký tự - không cắt ngầm
      IF strlen( lv_form ) > 30.
        RAISE EXCEPTION NEW zcx_ads_pdf( iv_text        = |Tên form { lv_form } dài quá 30 ký tự|
                                         iv_template_id = lv_form ).
      ENDIF.
      TRY.
          DATA(lo_reader) = cl_fp_form_reader=>create_form_reader( CONV #( lv_form ) ).
          INSERT VALUE #( template_id = lv_form
                          content     = lo_reader->get_layout( )
                          mime_type   = `application/vnd.adobe.xdp+xml`
                          embed_fonts = xsdbool( lo_reader->get_font_embed( ) IS NOT INITIAL ) )
                 INTO TABLE rt_template.
        CATCH cx_fp_form_reader INTO DATA(lx_reader).
          IF lx_reader->if_t100_message~t100key = cx_fp_form_reader=>form_does_not_exists.
            "Không có form -> bỏ qua, bên gọi báo 'không tìm thấy template'
            CONTINUE.
          ENDIF.
          RAISE EXCEPTION NEW zcx_ads_pdf( previous       = lx_reader
                                           iv_text        = lx_reader->get_text( )
                                           iv_template_id = lv_form ).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.