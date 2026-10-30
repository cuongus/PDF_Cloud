*=====================================================================
* Tên/Mã     : ZCL_ADS_PDF_RENDERER
* Mô tả chung: API chính render PDF bằng ADS từ template XDP (LiveCycle):
*              - nhiều tài liệu XML -> 1 PDF gộp (bỏ qua merger nếu 1 tài liệu)
*              - chèn logo base64 vào thẻ <LOGO/> theo số thứ tự tài liệu
*              - lỗi bất kỳ tài liệu nào -> ZCX_ADS_PDF (không trả PDF thiếu trang)
*              - print queue: render PDL (ngoài save) + tạo queue item (late save)
*              Thay cho ZCL_GEN_ADOBE / ZCL_API_ADOBE (package ZPK_ADOBE_PDF).
* Tham Số    : create( ) - layout + ảnh từ bảng ZADS_A_TEMPLATE
*              create_for_forms( ) - layout từ object Form (ADT, transport),
*              ảnh logo vẫn từ bảng ZADS_A_TEMPLATE
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_ADS_PDF
*=====================================================================
* Version   Ngày          Người sửa                Transport      Mô tả
*=====================================================================
* 1.0       30/10/2026    CB9980000013 - CuongUS   AK3K908751     Tạo mới
*=====================================================================
CLASS zcl_ads_pdf_renderer DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! de_DE: '.' hàng nghìn, ',' thập phân như thói quen Việt Nam;
    "! tên tháng / mẫu ngày theo locale - truyền LOCALE nếu template cần khác
    CONSTANTS c_default_locale   TYPE string VALUE `de_DE`.
    CONSTANTS c_default_logo_tag TYPE string VALUE `LOGO`.

    TYPES ty_template_id TYPE zif_ads_pdf_template_source=>ty_template_id.

    TYPES:
      BEGIN OF ty_logo,
        "! Số thứ tự tài liệu (dòng trong DOCUMENTS) nhận logo
        document_index TYPE i,
        "! Mã ảnh trong nguồn ảnh (bảng ZADS_A_TEMPLATE)
        template_id    TYPE ty_template_id,
      END OF ty_logo,
      tt_logo TYPE STANDARD TABLE OF ty_logo WITH EMPTY KEY,
      tt_xml  TYPE STANDARD TABLE OF xstring WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_request,
        template_id TYPE ty_template_id,
        "! Một phần tử = một tài liệu XML (UTF-8); xem ZCL_ADS_PDF_XML
        documents   TYPE tt_xml,
        "! Mặc định C_DEFAULT_LOCALE
        locale      TYPE string,
        logos       TYPE tt_logo,
        "! Mặc định C_DEFAULT_LOGO_TAG
        logo_tag    TYPE string,
        "! 0-4; > 0 để lấy trace ADS khi chẩn đoán lỗi (không dùng thường xuyên)
        trace_level TYPE i,
        "! abap_true: không tạo PDF_BASE64 (tiết kiệm bộ nhớ với PDF lớn)
        skip_base64 TYPE abap_bool,
      END OF ty_request.

    TYPES:
      BEGIN OF ty_result,
        pdf              TYPE xstring,
        pdf_base64       TYPE string,
        pages            TYPE i,
        documents        TYPE i,
        template_version TYPE i,
      END OF ty_result.

    TYPES:
      BEGIN OF ty_print_output,
        data  TYPE xstring,
        pages TYPE i,
      END OF ty_print_output.

    "! Renderer with layouts and images from table ZADS_A_TEMPLATE
    "! @parameter io_template_source | Other layout source / test double (optional)
    "! @parameter io_image_source    | Other logo source / test double (optional)
    "! @parameter io_engine          | Test double for ADS (optional)
    CLASS-METHODS create
      IMPORTING io_template_source TYPE REF TO zif_ads_pdf_template_source OPTIONAL
                io_image_source    TYPE REF TO zif_ads_pdf_template_source OPTIONAL
                io_engine          TYPE REF TO zif_ads_pdf_engine OPTIONAL
      RETURNING VALUE(ro_renderer) TYPE REF TO zcl_ads_pdf_renderer.

    "! Renderer with layouts from ADT form objects (transportable)
    CLASS-METHODS create_for_forms
      RETURNING VALUE(ro_renderer) TYPE REF TO zcl_ads_pdf_renderer.

    "! Render all documents of the request into one PDF
    METHODS render
      IMPORTING is_request       TYPE ty_request
      RETURNING VALUE(rs_result) TYPE ty_result
      RAISING   zcx_ads_pdf.

    "! Short form for one document
    METHODS render_single
      IMPORTING iv_template_id   TYPE csequence
                iv_xml           TYPE xstring
                iv_locale        TYPE string DEFAULT c_default_locale
      RETURNING VALUE(rs_result) TYPE ty_result
      RAISING   zcx_ads_pdf.

    "! Step 1 of printing: render in the print format (PDL) of the queue.
    "! Calls ADS - inside RAP do it in the interaction phase (action/determination).
    METHODS render_for_print_queue
      IMPORTING iv_template_id   TYPE csequence
                iv_xml           TYPE xstring
                iv_queue_name    TYPE cl_print_queue_utils=>ty_pqname
                iv_locale        TYPE string DEFAULT c_default_locale
      RETURNING VALUE(rs_output) TYPE ty_print_output
      RAISING   zcx_ads_pdf.

    "! Step 2 of printing: create the print queue item. Inside RAP call it in
    "! the late save phase with an item ID from CL_PRINT_QUEUE_UTILS=>CREATE_QUEUE_ITEMID.
    "! Outside RAP the caller commits (COMMIT WORK) afterwards.
    CLASS-METHODS add_to_print_queue
      IMPORTING is_output         TYPE ty_print_output
                iv_queue_name     TYPE cl_print_queue_utils=>ty_pqname
                iv_document_name  TYPE cl_print_queue_utils=>ty_doc_name
                iv_copies         TYPE cl_print_queue_utils=>ty_nr_copies DEFAULT 1
                iv_item_id        TYPE cl_print_queue_utils=>ty_itemid OPTIONAL
      RETURNING VALUE(rv_item_id) TYPE cl_print_queue_utils=>ty_itemid
      RAISING   zcx_ads_pdf.

    "! Step 1 + 2 in one call - only outside RAP (reports, jobs, HTTP services)
    METHODS render_to_print_queue
      IMPORTING iv_template_id    TYPE csequence
                iv_xml            TYPE xstring
                iv_queue_name     TYPE cl_print_queue_utils=>ty_pqname
                iv_document_name  TYPE cl_print_queue_utils=>ty_doc_name
                iv_copies         TYPE cl_print_queue_utils=>ty_nr_copies DEFAULT 1
                iv_locale         TYPE string DEFAULT c_default_locale
      RETURNING VALUE(rv_item_id) TYPE cl_print_queue_utils=>ty_itemid
      RAISING   zcx_ads_pdf.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_logo_data,
        document_index TYPE i,
        base64         TYPE string,
      END OF ty_logo_data,
      tt_logo_data TYPE HASHED TABLE OF ty_logo_data WITH UNIQUE KEY document_index.

    DATA mo_source       TYPE REF TO zif_ads_pdf_template_source.
    DATA mo_image_source TYPE REF TO zif_ads_pdf_template_source.
    DATA mo_engine       TYPE REF TO zif_ads_pdf_engine.
    "! Layouts already read by this instance
    DATA mt_cache        TYPE zif_ads_pdf_template_source=>tt_template.

    METHODS get_template
      IMPORTING iv_template_id     TYPE csequence
      RETURNING VALUE(rs_template) TYPE zif_ads_pdf_template_source=>ty_template
      RAISING   zcx_ads_pdf.

    METHODS load_logos
      IMPORTING it_logo        TYPE tt_logo
      RETURNING VALUE(rt_logo) TYPE tt_logo_data
      RAISING   zcx_ads_pdf.

    CLASS-METHODS inject_logo
      IMPORTING iv_xml        TYPE xstring
                iv_tag        TYPE string
                iv_base64     TYPE string
      RETURNING VALUE(rv_xml) TYPE xstring
      RAISING   zcx_ads_pdf.

    CLASS-METHODS is_image
      IMPORTING iv_mime_type     TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.
ENDCLASS.



CLASS zcl_ads_pdf_renderer IMPLEMENTATION.

  METHOD create.
    ro_renderer = NEW #( ).
    ro_renderer->mo_source = COND #( WHEN io_template_source IS BOUND THEN io_template_source
                                     ELSE NEW zcl_ads_pdf_template_db( ) ).
    ro_renderer->mo_image_source = COND #( WHEN io_image_source IS BOUND THEN io_image_source
                                           WHEN io_template_source IS BOUND THEN io_template_source
                                           ELSE NEW zcl_ads_pdf_template_db( ) ).
    ro_renderer->mo_engine = COND #( WHEN io_engine IS BOUND THEN io_engine
                                     ELSE NEW zcl_ads_pdf_engine( ) ).
  ENDMETHOD.

  METHOD create_for_forms.
    "Object Form chỉ chứa layout; ảnh logo vẫn lấy từ bảng
    ro_renderer = create( io_template_source = NEW zcl_ads_pdf_template_form( )
                          io_image_source    = NEW zcl_ads_pdf_template_db( ) ).
  ENDMETHOD.

  METHOD render.
    DATA lt_pdf TYPE zif_ads_pdf_engine=>tt_pdf.

    IF is_request-template_id IS INITIAL.
      RAISE EXCEPTION NEW zcx_ads_pdf( iv_text = `Thiếu mã template` ).
    ENDIF.
    IF is_request-documents IS INITIAL.
      RAISE EXCEPTION NEW zcx_ads_pdf( iv_text        = `Không có dữ liệu để in`
                                       iv_template_id = is_request-template_id ).
    ENDIF.

    DATA(ls_template) = get_template( is_request-template_id ).
    DATA(lt_logo)     = load_logos( is_request-logos ).
    DATA(ls_options)  = VALUE zif_ads_pdf_engine=>ty_options(
                          locale      = COND #( WHEN is_request-locale IS NOT INITIAL
                                                THEN is_request-locale ELSE c_default_locale )
                          embed_fonts = ls_template-embed_fonts
                          trace_level = is_request-trace_level ).
    DATA(lv_logo_tag) = COND string( WHEN is_request-logo_tag IS NOT INITIAL
                                     THEN is_request-logo_tag ELSE c_default_logo_tag ).

    LOOP AT is_request-documents INTO DATA(lv_xml).
      DATA(lv_index) = sy-tabix.

      ASSIGN lt_logo[ document_index = lv_index ] TO FIELD-SYMBOL(<ls_logo>).
      IF sy-subrc = 0.
        lv_xml = inject_logo( iv_xml = lv_xml iv_tag = lv_logo_tag iv_base64 = <ls_logo>-base64 ).
      ENDIF.

      TRY.
          DATA(ls_output) = mo_engine->render_pdf( iv_xml     = lv_xml
                                                   iv_layout  = ls_template-content
                                                   is_options = ls_options ).
        CATCH zcx_ads_pdf INTO DATA(lx_render).
          RAISE EXCEPTION NEW zcx_ads_pdf( previous       = lx_render
                                           iv_text        = |Tài liệu { lv_index }: { lx_render->get_text( ) }|
                                           iv_template_id = ls_template-template_id
                                           iv_trace       = lx_render->mv_trace ).
      ENDTRY.

      APPEND ls_output-data TO lt_pdf.
      rs_result-pages += ls_output-pages.
    ENDLOOP.

    rs_result-documents        = lines( lt_pdf ).
    rs_result-pdf              = mo_engine->merge( lt_pdf ).
    FREE lt_pdf.
    rs_result-template_version = ls_template-version.
    IF is_request-skip_base64 = abap_false.
      rs_result-pdf_base64 = cl_web_http_utility=>encode_x_base64( rs_result-pdf ).
    ENDIF.
  ENDMETHOD.

  METHOD render_single.
    rs_result = render( VALUE #( template_id = iv_template_id
                                 documents   = VALUE #( ( iv_xml ) )
                                 locale      = iv_locale ) ).
  ENDMETHOD.

  METHOD render_for_print_queue.
    IF iv_xml IS INITIAL.
      RAISE EXCEPTION NEW zcx_ads_pdf( iv_text        = `Không có dữ liệu để in`
                                       iv_template_id = iv_template_id ).
    ENDIF.

    DATA(ls_template) = get_template( iv_template_id ).
    DATA(ls_pdl) = mo_engine->render_pdl(
                     iv_xml        = iv_xml
                     iv_layout     = ls_template-content
                     iv_queue_name = iv_queue_name
                     is_options    = VALUE #( locale = COND #( WHEN iv_locale IS NOT INITIAL
                                                               THEN iv_locale ELSE c_default_locale ) ) ).
    rs_output = VALUE #( data = ls_pdl-data pages = ls_pdl-pages ).
  ENDMETHOD.

  METHOD add_to_print_queue.
    cl_print_queue_utils=>create_queue_item_by_data(
      EXPORTING iv_qname            = iv_queue_name
                iv_print_data       = is_output-data
                iv_name_of_main_doc = iv_document_name
                iv_itemid           = iv_item_id
                iv_pages            = is_output-pages
                iv_number_of_copies = iv_copies
      IMPORTING ev_err_msg          = DATA(lv_error)
      RECEIVING rv_itemid           = rv_item_id ).

    IF lv_error IS NOT INITIAL.
      RAISE EXCEPTION NEW zcx_ads_pdf( iv_text = |Print queue { iv_queue_name }: { lv_error }| ).
    ENDIF.
  ENDMETHOD.

  METHOD render_to_print_queue.
    rv_item_id = add_to_print_queue(
                   is_output        = render_for_print_queue( iv_template_id = iv_template_id
                                                              iv_xml         = iv_xml
                                                              iv_queue_name  = iv_queue_name
                                                              iv_locale      = iv_locale )
                   iv_queue_name    = iv_queue_name
                   iv_document_name = iv_document_name
                   iv_copies        = iv_copies ).
  ENDMETHOD.

  METHOD get_template.
    DATA(lv_id) = CONV ty_template_id( to_upper( iv_template_id ) ).

    READ TABLE mt_cache INTO rs_template WITH TABLE KEY template_id = lv_id.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    DATA(lt_template) = mo_source->get_templates( VALUE #( ( lv_id ) ) ).
    READ TABLE lt_template INTO rs_template WITH TABLE KEY template_id = lv_id.
    IF sy-subrc <> 0 OR rs_template-content IS INITIAL.
      RAISE EXCEPTION NEW zcx_ads_pdf( iv_text        = |Không tìm thấy template { lv_id }|
                                       iv_template_id = lv_id ).
    ENDIF.
    IF is_image( rs_template-mime_type ) = abap_true.
      RAISE EXCEPTION NEW zcx_ads_pdf( iv_text        = |{ lv_id } là ảnh ({ rs_template-mime_type }), không phải layout XDP|
                                       iv_template_id = lv_id ).
    ENDIF.

    INSERT rs_template INTO TABLE mt_cache.
  ENDMETHOD.

  METHOD load_logos.
    TYPES:
      BEGIN OF ty_image,
        template_id TYPE ty_template_id,
        base64      TYPE string,
      END OF ty_image.
    DATA lt_image TYPE HASHED TABLE OF ty_image WITH UNIQUE KEY template_id.

    IF it_logo IS INITIAL.
      RETURN.
    ENDIF.

    "Một lần đọc cho mọi ảnh, mã hoá base64 một lần cho mỗi ảnh
    DATA(lt_found) = mo_image_source->get_templates( VALUE #( FOR ls_req IN it_logo ( ls_req-template_id ) ) ).
    LOOP AT lt_found INTO DATA(ls_found) WHERE content IS NOT INITIAL.
      IF is_image( ls_found-mime_type ) = abap_false.
        RAISE EXCEPTION NEW zcx_ads_pdf( iv_text        = |{ ls_found-template_id } không phải ảnh ({ ls_found-mime_type })|
                                         iv_template_id = ls_found-template_id ).
      ENDIF.
      INSERT VALUE #( template_id = ls_found-template_id
                      base64      = cl_web_http_utility=>encode_x_base64( ls_found-content ) )
             INTO TABLE lt_image.
    ENDLOOP.

    LOOP AT it_logo INTO DATA(ls_logo).
      DATA(lv_id) = CONV ty_template_id( to_upper( ls_logo-template_id ) ).
      ASSIGN lt_image[ template_id = lv_id ] TO FIELD-SYMBOL(<ls_image>).
      IF sy-subrc <> 0.
        RAISE EXCEPTION NEW zcx_ads_pdf( iv_text        = |Không tìm thấy ảnh logo { lv_id }|
                                         iv_template_id = lv_id ).
      ENDIF.
      INSERT VALUE #( document_index = ls_logo-document_index
                      base64         = <ls_image>-base64 ) INTO TABLE rt_logo.
      IF sy-subrc <> 0.
        RAISE EXCEPTION NEW zcx_ads_pdf( iv_text = |Tài liệu { ls_logo-document_index } được gán nhiều logo| ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD inject_logo.
    TRY.
        DATA(lv_text) = cl_abap_conv_codepage=>create_in( codepage = `UTF-8` )->convert( iv_xml ).
      CATCH cx_sy_conversion_codepage INTO DATA(lx_codepage).
        RAISE EXCEPTION NEW zcx_ads_pdf( previous = lx_codepage
                                         iv_text  = `Dữ liệu XML phải là UTF-8 để chèn logo` ).
    ENDTRY.

    "<LOGO/>, <LOGO />, <LOGO></LOGO>, <LOGO> </LOGO>
    rv_xml = cl_abap_conv_codepage=>create_out( codepage = `UTF-8` )->convert(
               replace( val  = lv_text
                        pcre = |<{ iv_tag }\\s*/>\|<{ iv_tag }\\s*>\\s*</{ iv_tag }\\s*>|
                        with = |<{ iv_tag }>{ iv_base64 }</{ iv_tag }>|
                        occ  = 0 ) ).
  ENDMETHOD.

  METHOD is_image.
    rv_result = xsdbool( to_lower( iv_mime_type ) CP `image/*` ).
  ENDMETHOD.

ENDCLASS.