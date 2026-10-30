*=====================================================================
* Tên/Mã     : ZCL_ADS_PDF_ENGINE
* Mô tả chung: Gọi API đã release CL_FP_ADS_UTIL (render PDF / PDL) và
*              CL_RSPO_PDF_MERGER (gộp PDF); đổi lỗi sang ZCX_ADS_PDF kèm
*              trích đoạn trace ADS
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_ADS_PDF
*=====================================================================
* Version   Ngày          Người sửa                Transport      Mô tả
*=====================================================================
* 1.0       30/10/2026    CB9980000013 - CuongUS   AK3K908751     Tạo mới
*=====================================================================
CLASS zcl_ads_pdf_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ads_pdf_engine.

  PROTECTED SECTION.
  PRIVATE SECTION.
    "! Max. length of the ADS trace excerpt put into the error text
    CONSTANTS c_trace_excerpt TYPE i VALUE 500.

    CLASS-METHODS trace_excerpt
      IMPORTING iv_trace       TYPE string
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.



CLASS zcl_ads_pdf_engine IMPLEMENTATION.

  METHOD zif_ads_pdf_engine~render_pdf.
    DATA lv_trace TYPE string.

    TRY.
        cl_fp_ads_util=>render_pdf(
          EXPORTING iv_xml_data     = iv_xml
                    iv_xdp_layout   = iv_layout
                    iv_locale       = is_options-locale
                    is_options      = VALUE #( embed_fonts = is_options-embed_fonts
                                               trace_level = is_options-trace_level )
          IMPORTING ev_pdf          = rs_output-data
                    ev_pages        = rs_output-pages
                    ev_trace_string = lv_trace ).
      CATCH cx_fp_ads_util INTO DATA(lx_ads).
        RAISE EXCEPTION NEW zcx_ads_pdf(
          previous = lx_ads
          iv_text  = |{ lx_ads->get_text( ) }{ trace_excerpt( lv_trace ) }|
          iv_trace = lv_trace ).
    ENDTRY.
  ENDMETHOD.

  METHOD zif_ads_pdf_engine~render_pdl.
    DATA lv_trace TYPE string.

    TRY.
        cl_fp_ads_util=>render_4_pq(
          EXPORTING iv_xml_data     = iv_xml
                    iv_xdp_layout   = iv_layout
                    iv_locale       = is_options-locale
                    iv_pq_name      = CONV #( iv_queue_name )
                    is_options      = VALUE #( trace_level = is_options-trace_level )
          IMPORTING ev_pdl          = rs_output-data
                    ev_pages        = rs_output-pages
                    ev_trace_string = lv_trace ).
      CATCH cx_fp_ads_util INTO DATA(lx_ads).
        RAISE EXCEPTION NEW zcx_ads_pdf(
          previous = lx_ads
          iv_text  = |{ lx_ads->get_text( ) }{ trace_excerpt( lv_trace ) }|
          iv_trace = lv_trace ).
    ENDTRY.
  ENDMETHOD.

  METHOD zif_ads_pdf_engine~merge.
    CASE lines( it_pdf ).
      WHEN 0.
        RETURN.
      WHEN 1.
        "Một tài liệu: không cần gọi merger
        rv_pdf = it_pdf[ 1 ].
        RETURN.
    ENDCASE.

    DATA(lo_merger) = cl_rspo_pdf_merger=>create_instance( ).
    LOOP AT it_pdf INTO DATA(lv_pdf).
      lo_merger->add_document( lv_pdf ).
    ENDLOOP.

    TRY.
        rv_pdf = lo_merger->merge_documents( ).
      CATCH cx_rspo_pdf_merger INTO DATA(lx_merge).
        RAISE EXCEPTION NEW zcx_ads_pdf( previous = lx_merge
                                         iv_text  = |Gộp PDF lỗi: { lx_merge->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD trace_excerpt.
    IF iv_trace IS INITIAL.
      RETURN.
    ENDIF.
    rv_text = | - { substring( val = iv_trace len = nmin( val1 = strlen( iv_trace ) val2 = c_trace_excerpt ) ) }|.
  ENDMETHOD.

ENDCLASS.