*=====================================================================
* Tên/Mã     : ZCL_DEMO_ADS_PNK_PRINT
* Mô tả chung: In phiếu nhập kho demo bằng FDP:
*              1. ZCL_ADS_PDF_FDP đọc XML từ service ZUI_DEMO_ADS_PNK_FDP
*                 (dữ liệu do ZCL_DEMO_ADS_PNK_QUERY trả về)
*              2. ZCL_ADS_PDF_RENDERER render bằng template ZDEMO_PNK
*              3. nhiều phiếu: trả 1 file gộp + từng file lẻ (base64)
*              Template: bản upload ở app quản lý template (bảng
*              ZADS_A_TEMPLATE) nếu có, không thì XDP mẫu trong class này.
*              Chạy F9 (classrun) để thử in phiếu 5000000101/2026.
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_DEMO_2
*=====================================================================
CLASS zcl_demo_ads_pnk_print DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
    INTERFACES zif_ads_pdf_template_source.

    CONSTANTS c_template_id TYPE zif_ads_pdf_template_source=>ty_template_id VALUE 'ZDEMO_PNK'.
    CONSTANTS c_fdp_service TYPE string VALUE `ZUI_DEMO_ADS_PNK_FDP`.

    TYPES:
      BEGIN OF ty_doc_key,
        doc_no      TYPE c LENGTH 10,
        fiscal_year TYPE n LENGTH 4,
      END OF ty_doc_key,
      tt_doc_key TYPE STANDARD TABLE OF ty_doc_key WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_file,
        file_name TYPE c LENGTH 120,
        mime_type TYPE c LENGTH 60,
        "! Nội dung base64
        content   TYPE string,
      END OF ty_file,
      tt_file TYPE STANDARD TABLE OF ty_file WITH EMPTY KEY.

    "! Đổi chuỗi "5000000101/2026,5000000102/2026" thành danh sách khoá (bỏ trùng)
    CLASS-METHODS parse_keys
      IMPORTING iv_keys       TYPE string
      RETURNING VALUE(rt_key) TYPE tt_doc_key.

    "! In các phiếu: 1 phiếu -> 1 file; nhiều phiếu -> file gộp đứng đầu + từng file lẻ
    METHODS print_preview
      IMPORTING it_key         TYPE tt_doc_key
                is_signer      TYPE zcl_demo_ads_pnk_query=>ty_signer OPTIONAL
      RETURNING VALUE(rt_file) TYPE tt_file
      RAISING   zcx_ads_pdf.

    "! XML dữ liệu FDP của 1 phiếu (để xem / chẩn đoán)
    METHODS read_xml
      IMPORTING is_key        TYPE ty_doc_key
                is_signer     TYPE zcl_demo_ads_pnk_query=>ty_signer OPTIONAL
      RETURNING VALUE(rv_xml) TYPE xstring
      RAISING   zcx_ads_pdf.

    "! File cho người thiết kế form: XSD (data connection) + XDP mẫu
    METHODS get_design_files
      RETURNING VALUE(rt_file) TYPE tt_file
      RAISING   zcx_ads_pdf.

    "! XDP mẫu nhúng trong class (mở được bằng Adobe LiveCycle Designer)
    CLASS-METHODS demo_xdp
      RETURNING VALUE(rv_xdp) TYPE xstring.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_fdp TYPE REF TO zcl_ads_pdf_fdp.

    METHODS fdp
      RETURNING VALUE(ro_fdp) TYPE REF TO zcl_ads_pdf_fdp
      RAISING   zcx_ads_pdf.

    CLASS-METHODS to_base64
      IMPORTING iv_data          TYPE xstring
      RETURNING VALUE(rv_base64) TYPE string.
ENDCLASS.



CLASS zcl_demo_ads_pnk_print IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA(ls_key) = VALUE ty_doc_key( doc_no = '5000000101' fiscal_year = '2026' ).
    TRY.
        DATA(lv_xml) = read_xml( ls_key ).
        out->write( |XML FDP ({ xstrlen( lv_xml ) } byte):| ).
        out->write( cl_abap_conv_codepage=>create_in( )->convert( lv_xml ) ).

        DATA(lt_file) = print_preview( it_key    = VALUE #( ( ls_key )
                                                            ( doc_no = '5000000102' fiscal_year = '2026' ) )
                                       is_signer = VALUE #( store_keeper = 'Thủ kho chạy thử' ) ).
        LOOP AT lt_file INTO DATA(ls_file).
          out->write( |{ ls_file-file_name }: { strlen( ls_file-content ) } ký tự base64| ).
        ENDLOOP.
        "Bỏ comment để lấy PDF: dán base64 vào công cụ giải mã
        "out->write( lt_file[ 1 ]-content ).

        "Gọi action printPreview của BO bằng EML - app Fiori gọi đúng action này qua OData
        MODIFY ENTITIES OF zr_demo_ads_pnk
          ENTITY GoodsReceipt
          EXECUTE printPreview
          FROM VALUE #( ( %cid  = 'PRINT1'
                          %param = VALUE #( documentkeys = `5000000103/2026,5000000104/2026,5000000105`
                                            accountant   = 'Kế toán EML' ) ) )
          RESULT DATA(lt_action)
          FAILED DATA(ls_failed)
          REPORTED DATA(ls_reported).
        LOOP AT lt_action INTO DATA(ls_action).
          out->write( |EML: { ls_action-%param-filename } - { strlen( ls_action-%param-filecontent ) } ký tự base64| ).
        ENDLOOP.
        LOOP AT ls_reported-goodsreceipt INTO DATA(ls_msg).
          out->write( |EML lỗi: { ls_msg-%msg->if_message~get_text( ) }| ).
        ENDLOOP.
      CATCH zcx_ads_pdf INTO DATA(lx_pdf).
        out->write( |Lỗi: { lx_pdf->get_text( ) }| ).
        out->write( lx_pdf->mv_trace ).
    ENDTRY.
  ENDMETHOD.

  METHOD parse_keys.
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    SPLIT iv_keys AT ',' INTO TABLE DATA(lt_part).
    LOOP AT lt_part INTO DATA(lv_part).
      SPLIT condense( lv_part ) AT '/' INTO DATA(lv_doc_no) DATA(lv_year).
      IF lv_doc_no IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(ls_key) = VALUE ty_doc_key( doc_no      = condense( lv_doc_no )
                                       fiscal_year = COND #( WHEN lv_year IS INITIAL
                                                             THEN lv_today(4)
                                                             ELSE condense( lv_year ) ) ).
      IF NOT line_exists( rt_key[ doc_no = ls_key-doc_no fiscal_year = ls_key-fiscal_year ] ).
        APPEND ls_key TO rt_key.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD print_preview.
    DATA lt_pdf TYPE zif_ads_pdf_engine=>tt_pdf.

    IF it_key IS INITIAL.
      RAISE EXCEPTION NEW zcx_ads_pdf( iv_text = `Chọn ít nhất một phiếu nhập kho để in` ).
    ENDIF.

    DATA(lo_renderer) = zcl_ads_pdf_renderer=>create( io_template_source = me ).

    LOOP AT it_key INTO DATA(ls_key).
      DATA(ls_result) = lo_renderer->render_single( iv_template_id = c_template_id
                                                    iv_xml         = read_xml( is_key    = ls_key
                                                                               is_signer = is_signer ) ).
      APPEND ls_result-pdf TO lt_pdf.
      APPEND VALUE #( file_name = |PhieuNhapKho_{ ls_key-doc_no }_{ ls_key-fiscal_year }.pdf|
                      mime_type = 'application/pdf'
                      content   = ls_result-pdf_base64 ) TO rt_file.
    ENDLOOP.

    IF lines( lt_pdf ) > 1.
      DATA(lv_merged) = NEW zcl_ads_pdf_engine( )->zif_ads_pdf_engine~merge( lt_pdf ).
      INSERT VALUE #( file_name = |PhieuNhapKho_TatCa_{ lines( lt_pdf ) }_phieu.pdf|
                      mime_type = 'application/pdf'
                      content   = to_base64( lv_merged ) ) INTO rt_file INDEX 1.
    ENDIF.
  ENDMETHOD.

  METHOD read_xml.
    "FDP gọi lại ZCL_DEMO_ADS_PNK_QUERY trong cùng phiên -> đặt người ký trước khi đọc
    zcl_demo_ads_pnk_query=>set_signer( is_signer ).
    TRY.
        rv_xml = fdp( )->read_xml( VALUE #( ( name = `DocNo`      value = is_key-doc_no )
                                            ( name = `FiscalYear` value = is_key-fiscal_year ) ) ).
      CLEANUP.
        zcl_demo_ads_pnk_query=>set_signer( VALUE #( ) ).
    ENDTRY.
    zcl_demo_ads_pnk_query=>set_signer( VALUE #( ) ).
  ENDMETHOD.

  METHOD get_design_files.
    rt_file = VALUE #( ( file_name = |{ c_fdp_service }.xsd|
                         mime_type = 'application/xml'
                         content   = to_base64( fdp( )->get_xsd( ) ) )
                       ( file_name = |{ c_template_id }.xdp|
                         mime_type = 'application/vnd.adobe.xdp+xml'
                         content   = to_base64( demo_xdp( ) ) ) ).
  ENDMETHOD.

  METHOD fdp.
    IF mo_fdp IS NOT BOUND.
      mo_fdp = zcl_ads_pdf_fdp=>create( c_fdp_service ).
    ENDIF.
    ro_fdp = mo_fdp.
  ENDMETHOD.

  METHOD to_base64.
    rv_base64 = cl_web_http_utility=>encode_x_base64( iv_data ).
  ENDMETHOD.

  METHOD zif_ads_pdf_template_source~get_templates.
    "Ưu tiên bản người dùng upload (bảng ZADS_A_TEMPLATE), thiếu thì dùng XDP mẫu
    rt_template = NEW zcl_ads_pdf_template_db( )->zif_ads_pdf_template_source~get_templates( it_template_id ).

    IF line_exists( it_template_id[ table_line = c_template_id ] )
       AND NOT line_exists( rt_template[ template_id = c_template_id ] ).
      INSERT VALUE #( template_id = c_template_id
                      content     = demo_xdp( )
                      mime_type   = `application/vnd.adobe.xdp+xml`
                      version     = 0
                      embed_fonts = abap_true ) INTO TABLE rt_template.
    ENDIF.
  ENDMETHOD.

  METHOD demo_xdp.
    rv_xdp = cl_abap_conv_codepage=>create_out( codepage = `UTF-8` )->convert(
      `<?xml version="1.0" encoding="UTF-8"?>` &&
      `<xdp:xdp xmlns:xdp="http://ns.adobe.com/xdp/">` &&
      `<template xmlns="http://www.xfa.org/schema/xfa-template/3.3/">` &&
      `<subform name="Form" layout="tb" locale="de_DE">` &&
      `<pageSet>` &&
      `<pageArea name="Page1" id="Page1">` &&
      `<contentArea x="10mm" y="10mm" w="190mm" h="277mm"/>` &&
      `<medium stock="a4" short="210mm" long="297mm"/>` &&
      `</pageArea>` &&
      `</pageSet>` &&
      `<subform name="GoodsReceipt" layout="tb" w="190mm">` &&
      `<subform layout="position" w="190mm" h="52mm">` &&
      `<draw x="0mm" y="0mm" w="120mm" h="5mm"><value><text>Đơn vị: CÔNG TY MẪU (DEMO)</text></value><font typeface="Arial" size="9pt" weight="bold"/></draw>` &&
      `<draw x="0mm" y="5mm" w="120mm" h="5mm"><value><text>Bộ phận: Kho</text></value><font typeface="Arial" size="9pt"/></draw>` &&
      `<draw x="130mm" y="0mm" w="60mm" h="5mm"><value><text>Mẫu số 01 - VT</text></value><font typeface="Arial" size="9pt" weight="bold"/><para hAlign="center"/></draw>` &&
      `<draw x="0mm" y="12mm" w="155mm" h="9mm"><value><text>PHIẾU NHẬP KHO</text></value><font typeface="Arial" size="16pt" weight="bold"/><para hAlign="center"/></draw>` &&
      `<field name="PostingDate" x="0mm" y="21mm" w="155mm" h="5mm"><ui><dateTimeEdit/></ui><font typeface="Arial" size="9pt" posture="italic"/><para hAlign="center"/><value><date/>` &&
      `</value><format><picture>date{'Ngày 'DD' tháng 'MM' năm 'YYYY}</picture></format><bind match="once"><picture>date{YYYYMMDD}</picture></bind></field>` &&
      `<field name="DocNo" x="0mm" y="26mm" w="155mm" h="5mm"><ui><textEdit/></ui><font typeface="Arial" size="9pt"/><para hAlign="center"/><caption reserve="77mm"><para hAlign="right"/>` &&
      `<value><text>Số: </text></value></caption></field>` &&
      `<field name="QrContent" x="160mm" y="10mm" w="28mm" h="28mm" access="readOnly"><ui>` &&
      `<barcode type="QRCode" dataLength="10000" moduleWidth="0.6mm" moduleHeight="0.6mm" errorCorrectionLevel="1"/></ui><border><edge presence="hidden"/></border></field>` &&
      `<field name="Supplier" x="0mm" y="33mm" w="190mm" h="5mm"><ui><textEdit/></ui><font typeface="Arial" size="9pt"/><caption reserve="45mm"><value><text>Nhà cung cấp:</text></value>` &&
      `</caption></field>` &&
      `<field name="PurchaseOrder" x="0mm" y="38mm" w="95mm" h="5mm"><ui><textEdit/></ui><font typeface="Arial" size="9pt"/><caption reserve="45mm"><value>` &&
      `<text>Theo đơn mua hàng số:</text></value></caption></field>` &&
      `<field name="StorageLocation" x="95mm" y="38mm" w="95mm" h="5mm"><ui><textEdit/></ui><font typeface="Arial" size="9pt"/><caption reserve="30mm"><value><text>Nhập tại kho:</text>` &&
      `</value></caption></field>` &&
      `<field name="HeaderText" x="0mm" y="43mm" w="190mm" h="5mm"><ui><textEdit/></ui><font typeface="Arial" size="9pt"/><caption reserve="45mm"><value><text>Diễn giải:</text></value>` &&
      `</caption></field>` &&
      `</subform>` &&
      `<subform layout="position" w="190mm" h="10mm">` &&
      `<draw x="0mm" y="0mm" w="10mm" h="10mm"><value><text>STT</text></value><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="center" vAlign="middle"/><border>` &&
      `<edge thickness="0.2mm"/></border></draw>` &&
      `<draw x="10mm" y="0mm" w="22mm" h="10mm"><value><text>Mã hàng</text></value><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="center" vAlign="middle"/><border>` &&
      `<edge thickness="0.2mm"/></border></draw>` &&
      `<draw x="32mm" y="0mm" w="40mm" h="10mm"><value><text>Tên hàng</text></value><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="center" vAlign="middle"/><border>` &&
      `<edge thickness="0.2mm"/></border></draw>` &&
      `<draw x="72mm" y="0mm" w="12mm" h="10mm"><value><text>ĐVT</text></value><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="center" vAlign="middle"/><border>` &&
      `<edge thickness="0.2mm"/></border></draw>` &&
      `<draw x="84mm" y="0mm" w="10mm" h="10mm"><value><text>CL</text></value><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="center" vAlign="middle"/><border>` &&
      `<edge thickness="0.2mm"/></border></draw>` &&
      `<draw x="94mm" y="0mm" w="20mm" h="10mm"><value><text>Quy đổi</text></value><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="center" vAlign="middle"/><border>` &&
      `<edge thickness="0.2mm"/></border></draw>` &&
      `<draw x="114mm" y="0mm" w="32mm" h="5mm"><value><text>Số lượng</text></value><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="center" vAlign="middle"/><border>` &&
      `<edge thickness="0.2mm"/></border></draw>` &&
      `<draw x="114mm" y="5mm" w="16mm" h="5mm"><value><text>Yêu cầu</text></value><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="center" vAlign="middle"/><border>` &&
      `<edge thickness="0.2mm"/></border></draw>` &&
      `<draw x="130mm" y="5mm" w="16mm" h="5mm"><value><text>Thực nhập</text></value><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="center" vAlign="middle"/><border>` &&
      `<edge thickness="0.2mm"/></border></draw>` &&
      `<draw x="146mm" y="0mm" w="20mm" h="10mm"><value><text>Đơn giá</text></value><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="center" vAlign="middle"/><border>` &&
      `<edge thickness="0.2mm"/></border></draw>` &&
      `<draw x="166mm" y="0mm" w="24mm" h="10mm"><value><text>Thành tiền</text></value><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="center" vAlign="middle"/><border>` &&
      `<edge thickness="0.2mm"/></border></draw>` &&
      `</subform>` &&
      `<subform name="_Item" layout="tb" w="190mm">` &&
      `<subform name="GoodsReceiptItem" layout="lr-tb" w="190mm">` &&
      `<occur min="0" max="-1"/>` &&
      `<field name="ItemNo" w="10mm" h="6mm"><ui><numericEdit/></ui><font typeface="Arial" size="8pt"/><para hAlign="center" vAlign="middle"/><value><integer/></value><border>` &&
      `<edge thickness="0.2mm"/></border></field>` &&
      `<field name="Material" w="22mm" h="6mm"><ui><textEdit/></ui><font typeface="Arial" size="8pt"/><para vAlign="middle"/><margin leftInset="1mm"/><border><edge thickness="0.2mm"/>` &&
      `</border></field>` &&
      `<field name="MaterialName" w="40mm" h="6mm"><ui><textEdit/></ui><font typeface="Arial" size="8pt"/><para vAlign="middle"/><margin leftInset="1mm"/><border>` &&
      `<edge thickness="0.2mm"/></border></field>` &&
      `<field name="Unit" w="12mm" h="6mm"><ui><textEdit/></ui><font typeface="Arial" size="8pt"/><para hAlign="center" vAlign="middle"/><border><edge thickness="0.2mm"/></border></field>` &&
      `<field name="Quality" w="10mm" h="6mm"><ui><textEdit/></ui><font typeface="Arial" size="8pt"/><para hAlign="center" vAlign="middle"/><border><edge thickness="0.2mm"/></border>` &&
      `</field>` &&
      `<field name="Conversion" w="20mm" h="6mm"><ui><textEdit/></ui><font typeface="Arial" size="8pt"/><para hAlign="center" vAlign="middle"/><border><edge thickness="0.2mm"/></border>` &&
      `</field>` &&
      `<field name="QtyRequestedText" w="16mm" h="6mm"><ui><textEdit/></ui><font typeface="Arial" size="8pt"/><para hAlign="right" vAlign="middle"/><margin rightInset="1mm"/><border>` &&
      `<edge thickness="0.2mm"/><edge thickness="0.2mm"/><edge thickness="0.2mm"/><edge thickness="0.2mm"/></border><event activity="initialize">` &&
      `<script contentType="application/x-javascript">var p = String(this.parent.MergePos.rawValue == null ? "S" : this.parent.MergePos.rawValue);var c = p.charAt(0);if (c == "M" || c == ` &&
      `"L") this.border.getElement("edge", 0).presence = "hidden";if (c == "F" || c == "M") this.border.getElement("edge", 2).presence = "hidden";if (p.charAt(1) == "B") this.para.vAlign ` &&
      `= "bottom";</script></event></field>` &&
      `<field name="MergePos" presence="hidden"><ui><textEdit/></ui></field>` &&
      `<field name="QtyReceived" w="16mm" h="6mm"><ui><numericEdit/></ui><font typeface="Arial" size="8pt"/><para hAlign="right" vAlign="middle"/><margin rightInset="1mm"/><value>` &&
      `<decimal fracDigits="3"/></value><format><picture>num{z,zzz,zz9.99}</picture></format><border><edge thickness="0.2mm"/></border></field>` &&
      `<field name="Price" w="20mm" h="6mm"><ui><numericEdit/></ui><font typeface="Arial" size="8pt"/><para hAlign="right" vAlign="middle"/><margin rightInset="1mm"/><value>` &&
      `<decimal fracDigits="0"/></value><format><picture>num{zzz,zzz,zz9}</picture></format><border><edge thickness="0.2mm"/></border></field>` &&
      `<field name="Amount" w="24mm" h="6mm"><ui><numericEdit/></ui><font typeface="Arial" size="8pt"/><para hAlign="right" vAlign="middle"/><margin rightInset="1mm"/><value>` &&
      `<decimal fracDigits="0"/></value><format><picture>num{z,zzz,zzz,zz9}</picture></format><border><edge thickness="0.2mm"/></border></field>` &&
      `</subform>` &&
      `</subform>` &&
      `<subform layout="lr-tb" w="190mm">` &&
      `<draw w="114mm" h="6mm"><value><text>Cộng</text></value><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="center" vAlign="middle"/><border><edge thickness="0.2mm"/>` &&
      `</border></draw>` &&
      `<field name="TotalQtyRequested" w="16mm" h="6mm"><ui><numericEdit/></ui><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="right" vAlign="middle"/>` &&
      `<margin rightInset="1mm"/><value><decimal fracDigits="3"/></value><format><picture>num{z,zzz,zz9.99}</picture></format><border><edge thickness="0.2mm"/></border></field>` &&
      `<field name="TotalQtyReceived" w="16mm" h="6mm"><ui><numericEdit/></ui><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="right" vAlign="middle"/>` &&
      `<margin rightInset="1mm"/><value><decimal fracDigits="3"/></value><format><picture>num{z,zzz,zz9.99}</picture></format><border><edge thickness="0.2mm"/></border></field>` &&
      `<draw w="20mm" h="6mm"><value><text/></value><border><edge thickness="0.2mm"/></border></draw>` &&
      `<field name="TotalAmount" w="24mm" h="6mm"><ui><numericEdit/></ui><font typeface="Arial" size="8pt" weight="bold"/><para hAlign="right" vAlign="middle"/><margin rightInset="1mm"/>` &&
      `<value><decimal fracDigits="0"/></value><format><picture>num{z,zzz,zzz,zz9}</picture></format><border><edge thickness="0.2mm"/></border></field>` &&
      `</subform>` &&
      `<field name="AmountInWords" w="190mm" minH="7mm"><ui><textEdit multiLine="1"/></ui><font typeface="Arial" size="9pt" posture="italic"/><para vAlign="middle"/>` &&
      `<caption reserve="58mm"><font typeface="Arial" size="9pt"/><value><text>Tổng số tiền (viết bằng chữ):</text></value></caption></field>` &&
      `<subform layout="lr-tb" w="190mm">` &&
      `<subform layout="tb" w="47mm"><draw w="47mm" h="5mm"><value><text>Người giao hàng</text></value><font typeface="Arial" size="9pt" weight="bold"/><para hAlign="center"/></draw>` &&
      `<draw w="47mm" h="5mm"><value><text>(Ký, họ tên)</text></value><font typeface="Arial" size="8pt" posture="italic"/><para hAlign="center"/></draw><draw w="47mm" h="18mm"><value>` &&
      `<text/></value></draw><field name="Shipper" w="47mm" h="5mm"><ui><textEdit/></ui><font typeface="Arial" size="9pt" weight="bold"/><para hAlign="center"/></field></subform>` &&
      `<subform layout="tb" w="47mm"><draw w="47mm" h="5mm"><value><text>Thủ kho</text></value><font typeface="Arial" size="9pt" weight="bold"/><para hAlign="center"/></draw>` &&
      `<draw w="47mm" h="5mm"><value><text>(Ký, họ tên)</text></value><font typeface="Arial" size="8pt" posture="italic"/><para hAlign="center"/></draw><draw w="47mm" h="18mm"><value>` &&
      `<text/></value></draw><field name="StoreKeeper" w="47mm" h="5mm"><ui><textEdit/></ui><font typeface="Arial" size="9pt" weight="bold"/><para hAlign="center"/></field></subform>` &&
      `<subform layout="tb" w="47mm"><draw w="47mm" h="5mm"><value><text>Quản lý kho</text></value><font typeface="Arial" size="9pt" weight="bold"/><para hAlign="center"/></draw>` &&
      `<draw w="47mm" h="5mm"><value><text>(Ký, họ tên)</text></value><font typeface="Arial" size="8pt" posture="italic"/><para hAlign="center"/></draw><draw w="47mm" h="18mm"><value>` &&
      `<text/></value></draw><field name="WarehouseManager" w="47mm" h="5mm"><ui><textEdit/></ui><font typeface="Arial" size="9pt" weight="bold"/><para hAlign="center"/></field></subform>` &&
      `<subform layout="tb" w="47mm"><draw w="47mm" h="5mm"><value><text>Kế toán</text></value><font typeface="Arial" size="9pt" weight="bold"/><para hAlign="center"/></draw>` &&
      `<draw w="47mm" h="5mm"><value><text>(Ký, họ tên)</text></value><font typeface="Arial" size="8pt" posture="italic"/><para hAlign="center"/></draw><draw w="47mm" h="18mm"><value>` &&
      `<text/></value></draw><field name="Accountant" w="47mm" h="5mm"><ui><textEdit/></ui><font typeface="Arial" size="9pt" weight="bold"/><para hAlign="center"/></field></subform>` &&
      `</subform>` &&
      `</subform>` &&
      `</subform>` &&
      `</template>` &&
      `</xdp:xdp>` ).
  ENDMETHOD.

ENDCLASS.
