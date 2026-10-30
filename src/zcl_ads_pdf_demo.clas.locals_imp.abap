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

*"* Nguồn template "inline": XDP hoá đơn mẫu ZDEMO_INVOICE viết sẵn trong code
*"* (bản file: docs/samples/demo_invoice.xdp - mở được bằng Adobe LiveCycle Designer).
*"* Cấu trúc khớp XML mà FDP sinh ra từ service definition ZUI_ADS_DEMO_FDP:
*"*   Form / Invoice / {InvoiceNo, InvoiceDate, SellerName, BuyerName, TotalAmount}
*"*   Form / Invoice / _Item / InvoiceItem (lặp) / {ItemNo, Description, Quantity, Amount}
CLASS lcl_inline_source DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_ads_pdf_template_source.
    CONSTANTS c_template_id TYPE zif_ads_pdf_template_source=>ty_template_id VALUE 'ZDEMO_INVOICE'.
    CLASS-METHODS demo_invoice_xdp
      RETURNING VALUE(rv_xdp) TYPE xstring.
ENDCLASS.

CLASS lcl_inline_source IMPLEMENTATION.
  METHOD zif_ads_pdf_template_source~get_templates.
    IF line_exists( it_template_id[ table_line = c_template_id ] ).
      INSERT VALUE #( template_id = c_template_id
                      content     = demo_invoice_xdp( )
                      mime_type   = `application/vnd.adobe.xdp+xml`
                      version     = 1
                      embed_fonts = abap_true ) INTO TABLE rt_template.
    ENDIF.
  ENDMETHOD.

  METHOD demo_invoice_xdp.
    rv_xdp = cl_abap_conv_codepage=>create_out( codepage = `UTF-8` )->convert(
      `<?xml version="1.0" encoding="UTF-8"?>` &&
      `<xdp:xdp xmlns:xdp="http://ns.adobe.com/xdp/">` &&
      `<template xmlns="http://www.xfa.org/schema/xfa-template/3.3/">` &&
      `  <subform name="Form" layout="tb">` &&
      `    <pageSet>` &&
      `      <pageArea name="Page1" id="Page1">` &&
      `        <contentArea x="15mm" y="15mm" w="180mm" h="267mm"/>` &&
      `        <medium stock="a4" short="210mm" long="297mm"/>` &&
      `      </pageArea>` &&
      `    </pageSet>` &&
      `    <subform name="Invoice" layout="tb" w="180mm">` &&
      `      <draw name="Title" w="180mm" h="12mm">` &&
      `        <value><text>HOÁ ĐƠN BÁN HÀNG (DEMO)</text></value>` &&
      `        <font typeface="Arial" size="16pt" weight="bold"/>` &&
      `        <para hAlign="center"/>` &&
      `      </draw>` &&
      `      <field name="InvoiceNo" w="180mm" h="7mm">` &&
      `        <ui><textEdit/></ui>` &&
      `        <font typeface="Arial" size="10pt"/>` &&
      `        <caption reserve="35mm"><value><text>Số hoá đơn:</text></value></caption>` &&
      `      </field>` &&
      `      <field name="InvoiceDate" w="180mm" h="7mm">` &&
      `        <ui><dateTimeEdit/></ui>` &&
      `        <font typeface="Arial" size="10pt"/>` &&
      `        <caption reserve="35mm"><value><text>Ngày:</text></value></caption>` &&
      `        <value><date/></value>` &&
      `        <format><picture>date{DD/MM/YYYY}</picture></format>` &&
      `        <bind match="once"><picture>date{YYYYMMDD}</picture></bind>` &&
      `      </field>` &&
      `      <field name="SellerName" w="180mm" h="7mm">` &&
      `        <ui><textEdit/></ui>` &&
      `        <font typeface="Arial" size="10pt"/>` &&
      `        <caption reserve="35mm"><value><text>Bên bán:</text></value></caption>` &&
      `      </field>` &&
      `      <field name="BuyerName" w="180mm" h="7mm">` &&
      `        <ui><textEdit/></ui>` &&
      `        <font typeface="Arial" size="10pt"/>` &&
      `        <caption reserve="35mm"><value><text>Bên mua:</text></value></caption>` &&
      `      </field>` &&
      `      <draw name="ItemHeader" w="180mm" h="8mm">` &&
      `        <value><text>STT      Diễn giải                                              SL        Thành tiền</text></value>` &&
      `        <font typeface="Arial" size="10pt" weight="bold"/>` &&
      `      </draw>` &&
      `      <subform name="_Item" layout="tb" w="180mm">` &&
      `        <subform name="InvoiceItem" layout="lr-tb" w="180mm">` &&
      `          <occur min="0" max="-1"/>` &&
      `          <field name="ItemNo" w="15mm" h="7mm">` &&
      `            <ui><numericEdit/></ui>` &&
      `            <font typeface="Arial" size="10pt"/>` &&
      `            <value><integer/></value>` &&
      `          </field>` &&
      `          <field name="Description" w="105mm" h="7mm">` &&
      `            <ui><textEdit/></ui>` &&
      `            <font typeface="Arial" size="10pt"/>` &&
      `          </field>` &&
      `          <field name="Quantity" w="20mm" h="7mm">` &&
      `            <ui><numericEdit/></ui>` &&
      `            <font typeface="Arial" size="10pt"/>` &&
      `            <value><integer/></value>` &&
      `            <para hAlign="right"/>` &&
      `          </field>` &&
      `          <field name="Amount" w="40mm" h="7mm">` &&
      `            <ui><numericEdit/></ui>` &&
      `            <font typeface="Arial" size="10pt"/>` &&
      `            <value><decimal fracDigits="0"/></value>` &&
      `            <format><picture>num{zzz,zzz,zzz,zz9}</picture></format>` &&
      `            <para hAlign="right"/>` &&
      `          </field>` &&
      `        </subform>` &&
      `      </subform>` &&
      `      <field name="TotalAmount" w="180mm" h="8mm">` &&
      `        <ui><numericEdit/></ui>` &&
      `        <font typeface="Arial" size="11pt" weight="bold"/>` &&
      `        <caption reserve="140mm"><value><text>Tổng cộng (VND):</text></value></caption>` &&
      `        <value><decimal fracDigits="0"/></value>` &&
      `        <format><picture>num{zzz,zzz,zzz,zz9}</picture></format>` &&
      `        <para hAlign="right"/>` &&
      `      </field>` &&
      `    </subform>` &&
      `  </subform>` &&
      `</template>` &&
      `</xdp:xdp>` ).
  ENDMETHOD.
ENDCLASS.