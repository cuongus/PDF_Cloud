*"* Unit tests ZCL_ADS_PDF_RENDERER (test doubles, không gọi ADS thật)
CLASS ltd_source DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ads_pdf_template_source.
    DATA mt_template TYPE zif_ads_pdf_template_source=>tt_template.
    DATA mv_calls    TYPE i.
ENDCLASS.

CLASS ltd_source IMPLEMENTATION.
  METHOD zif_ads_pdf_template_source~get_templates.
    mv_calls += 1.
    LOOP AT it_template_id INTO DATA(lv_id).
      READ TABLE mt_template INTO DATA(ls_template)
           WITH TABLE KEY template_id = CONV zif_ads_pdf_template_source=>ty_template_id( to_upper( lv_id ) ).
      IF sy-subrc = 0.
        INSERT ls_template INTO TABLE rt_template.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_engine DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ads_pdf_engine.
    DATA mt_xml        TYPE zif_ads_pdf_engine=>tt_pdf.
    DATA mv_fail_index TYPE i.
    DATA ms_options    TYPE zif_ads_pdf_engine=>ty_options.
ENDCLASS.

CLASS ltd_engine IMPLEMENTATION.
  METHOD zif_ads_pdf_engine~render_pdf.
    APPEND iv_xml TO mt_xml.
    ms_options = is_options.
    IF lines( mt_xml ) = mv_fail_index.
      RAISE EXCEPTION NEW zcx_ads_pdf( iv_text = `ADS error` iv_trace = `trace` ).
    ENDIF.
    rs_output = VALUE #( data = CONV xstring( '25504446' ) pages = 2 ).
  ENDMETHOD.

  METHOD zif_ads_pdf_engine~render_pdl.
    ms_options = is_options.
    rs_output = VALUE #( data = CONV xstring( '00' ) pages = 1 ).
  ENDMETHOD.

  METHOD zif_ads_pdf_engine~merge.
    rv_pdf = COND #( WHEN lines( it_pdf ) = 1 THEN it_pdf[ 1 ] ELSE CONV xstring( 'FFFF' ) ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_renderer DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_source   TYPE REF TO ltd_source.
    DATA mo_engine   TYPE REF TO ltd_engine.
    DATA mo_renderer TYPE REF TO zcl_ads_pdf_renderer.

    METHODS setup.
    METHODS two_documents_merged   FOR TESTING RAISING zcx_ads_pdf.
    METHODS lower_case_id_found    FOR TESTING RAISING zcx_ads_pdf.
    METHODS template_read_once     FOR TESTING RAISING zcx_ads_pdf.
    METHODS logo_injected          FOR TESTING RAISING zcx_ads_pdf.
    METHODS separate_image_source  FOR TESTING RAISING zcx_ads_pdf.
    METHODS default_locale_used    FOR TESTING RAISING zcx_ads_pdf.
    METHODS skip_base64            FOR TESTING RAISING zcx_ads_pdf.
    METHODS print_output           FOR TESTING RAISING zcx_ads_pdf.
    METHODS template_not_found     FOR TESTING.
    METHODS image_as_layout        FOR TESTING.
    METHODS no_documents           FOR TESTING.
    METHODS logo_not_found         FOR TESTING.
    METHODS logo_twice             FOR TESTING.
    METHODS error_names_document   FOR TESTING.

    CLASS-METHODS xml
      IMPORTING iv_text       TYPE string
      RETURNING VALUE(rv_xml) TYPE xstring.
ENDCLASS.

CLASS ltcl_renderer IMPLEMENTATION.

  METHOD setup.
    mo_source = NEW #( ).
    mo_source->mt_template = VALUE #(
      ( template_id = 'ZFORM' content = CONV xstring( '3C78647020' ) mime_type = `application/vnd.adobe.xdp+xml`
        version = 3 embed_fonts = abap_true )
      ( template_id = 'ZLOGO' content = CONV xstring( '89504E47' ) mime_type = `image/png` ) ).
    mo_engine   = NEW #( ).
    mo_renderer = zcl_ads_pdf_renderer=>create( io_template_source = mo_source io_engine = mo_engine ).
  ENDMETHOD.

  METHOD xml.
    rv_xml = zcl_ads_pdf_xml=>string_to_xstring( iv_text ).
  ENDMETHOD.

  METHOD two_documents_merged.
    DATA(ls_result) = mo_renderer->render( VALUE #( template_id = 'ZFORM'
                                                    trace_level = 2
                                                    documents   = VALUE #( ( xml( `<a/>` ) ) ( xml( `<b/>` ) ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-documents exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-pages exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-pdf exp = CONV xstring( 'FFFF' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-pdf_base64 exp = `//8=` ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-template_version exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = mo_engine->ms_options-embed_fonts exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = mo_engine->ms_options-trace_level exp = 2 ).
  ENDMETHOD.

  METHOD lower_case_id_found.
    DATA(ls_result) = mo_renderer->render_single( iv_template_id = `zform` iv_xml = xml( `<a/>` ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-documents exp = 1 ).
  ENDMETHOD.

  METHOD template_read_once.
    mo_renderer->render_single( iv_template_id = `ZFORM` iv_xml = xml( `<a/>` ) ).
    mo_renderer->render_single( iv_template_id = `ZFORM` iv_xml = xml( `<a/>` ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_source->mv_calls exp = 1 ).
  ENDMETHOD.

  METHOD logo_injected.
    mo_renderer->render( VALUE #( template_id = 'ZFORM'
                                  documents   = VALUE #( ( xml( `<F><LOGO/></F>` ) )
                                                         ( xml( `<F><LOGO /><X/><LOGO> </LOGO></F>` ) ) )
                                  logos       = VALUE #( ( document_index = 2 template_id = 'zlogo' ) ) ) ).

    DATA(lo_conv) = cl_abap_conv_codepage=>create_in( codepage = `UTF-8` ).
    cl_abap_unit_assert=>assert_equals( act = lo_conv->convert( mo_engine->mt_xml[ 1 ] )
                                        exp = `<F><LOGO/></F>` ).
    cl_abap_unit_assert=>assert_equals( act = lo_conv->convert( mo_engine->mt_xml[ 2 ] )
                                        exp = `<F><LOGO>iVBORw==</LOGO><X/><LOGO>iVBORw==</LOGO></F>` ).
  ENDMETHOD.

  METHOD separate_image_source.
    DATA(lo_images) = NEW ltd_source( ).
    lo_images->mt_template = VALUE #( ( template_id = 'ZPIC' content = CONV xstring( '89504E47' ) mime_type = `image/png` ) ).
    DATA(lo_renderer) = zcl_ads_pdf_renderer=>create( io_template_source = mo_source
                                                      io_image_source    = lo_images
                                                      io_engine          = mo_engine ).
    lo_renderer->render( VALUE #( template_id = 'ZFORM'
                                  documents   = VALUE #( ( xml( `<F><LOGO/></F>` ) ) )
                                  logos       = VALUE #( ( document_index = 1 template_id = 'ZPIC' ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lo_images->mv_calls exp = 1 ).
  ENDMETHOD.

  METHOD default_locale_used.
    mo_renderer->render_single( iv_template_id = `ZFORM` iv_xml = xml( `<a/>` ) iv_locale = `` ).
    cl_abap_unit_assert=>assert_equals( act = mo_engine->ms_options-locale
                                        exp = zcl_ads_pdf_renderer=>c_default_locale ).
  ENDMETHOD.

  METHOD skip_base64.
    DATA(ls_result) = mo_renderer->render( VALUE #( template_id = 'ZFORM'
                                                    skip_base64 = abap_true
                                                    documents   = VALUE #( ( xml( `<a/>` ) ) ) ) ).
    cl_abap_unit_assert=>assert_initial( ls_result-pdf_base64 ).
    cl_abap_unit_assert=>assert_not_initial( ls_result-pdf ).
  ENDMETHOD.

  METHOD print_output.
    DATA(ls_output) = mo_renderer->render_for_print_queue( iv_template_id = `ZFORM`
                                                           iv_xml         = xml( `<a/>` )
                                                           iv_queue_name  = 'PQ1'
                                                           iv_locale      = `` ).
    cl_abap_unit_assert=>assert_equals( act = ls_output-pages exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_engine->ms_options-locale
                                        exp = zcl_ads_pdf_renderer=>c_default_locale ).
  ENDMETHOD.

  METHOD template_not_found.
    TRY.
        mo_renderer->render_single( iv_template_id = `ZMISSING` iv_xml = xml( `<a/>` ) ).
        cl_abap_unit_assert=>fail( `Phải báo lỗi không tìm thấy template` ).
      CATCH zcx_ads_pdf INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->mv_template_id exp = `ZMISSING` ).
    ENDTRY.
  ENDMETHOD.

  METHOD image_as_layout.
    TRY.
        mo_renderer->render_single( iv_template_id = `ZLOGO` iv_xml = xml( `<a/>` ) ).
        cl_abap_unit_assert=>fail( `Phải báo lỗi ảnh không phải layout` ).
      CATCH zcx_ads_pdf ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD no_documents.
    TRY.
        mo_renderer->render( VALUE #( template_id = 'ZFORM' ) ).
        cl_abap_unit_assert=>fail( `Phải báo lỗi không có dữ liệu` ).
      CATCH zcx_ads_pdf ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD logo_not_found.
    TRY.
        mo_renderer->render( VALUE #( template_id = 'ZFORM'
                                      documents   = VALUE #( ( xml( `<a/>` ) ) )
                                      logos       = VALUE #( ( document_index = 1 template_id = 'ZNOIMAGE' ) ) ) ).
        cl_abap_unit_assert=>fail( `Phải báo lỗi không tìm thấy logo` ).
      CATCH zcx_ads_pdf ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD logo_twice.
    TRY.
        mo_renderer->render( VALUE #( template_id = 'ZFORM'
                                      documents   = VALUE #( ( xml( `<a/>` ) ) )
                                      logos       = VALUE #( ( document_index = 1 template_id = 'ZLOGO' )
                                                             ( document_index = 1 template_id = 'ZLOGO' ) ) ) ).
        cl_abap_unit_assert=>fail( `Phải báo lỗi gán 2 logo cho 1 tài liệu` ).
      CATCH zcx_ads_pdf ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD error_names_document.
    mo_engine->mv_fail_index = 2.
    TRY.
        mo_renderer->render( VALUE #( template_id = 'ZFORM'
                                      documents   = VALUE #( ( xml( `<a/>` ) ) ( xml( `<b/>` ) ) ) ) ).
        cl_abap_unit_assert=>fail( `Phải báo lỗi tài liệu 2` ).
      CATCH zcx_ads_pdf INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_char_cp( act = lx_error->get_text( ) exp = `Tài liệu 2:*` ).
        cl_abap_unit_assert=>assert_equals( act = lx_error->mv_trace exp = `trace` ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.