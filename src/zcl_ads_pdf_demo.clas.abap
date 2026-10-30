*=====================================================================
* Tên/Mã     : ZCL_ADS_PDF_DEMO
* Mô tả chung: Class đào tạo dùng package ZPK_ADS_PDF để sinh PDF. Chạy F9
*              trong ADT (if_oo_adt_classrun) - bài 0..9, dữ liệu giả lập,
*              template có sẵn trong bảng cũ ZCORE_TB_TEMPPDF:
*              0 Hello PDF (chạy mọi client) .. ZDEMO_INVOICE (XDP inline)
*              1 Khám phá template ............ FormVGMCasa
*              2 XML từ cấu trúc ABAP ......... FormVGMCasa (tờ khai VGM)
*              3 Dựng XML thủ công, tiền VND .. zphieuthu (phiếu thu 2 liên)
*              4 Nhiều chứng từ -> 1 PDF ...... zphieuketoan (3 phiếu kế toán)
*              5 In tem hàng loạt, field ảnh .. zbarcode_bin (4 tem, 1 lần gọi ADS)
*              6 Xử lý lỗi
*              7 Upload template vào bảng mới (EML) rồi render từ bảng mới
*              8 Print queue (render PDL; tạo item thật khi bật cờ)
*              9 FDP (chạy mọi client) ...... ZUI_ADS_DEMO_FDP -> XSD -> XML -> PDF
*              Template không có trong client đang chạy -> bài đó tự bỏ qua.
* Tham Số    : C_WRITE_TEMPLATE_TABLE - bật để bài 7 ghi bảng ZADS_A_TEMPLATE
*              C_CREATE_PRINT_ITEM    - bật để bài 8 tạo item trong print queue
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_ADS_PDF
*=====================================================================
* Version   Ngày          Người sửa                Transport      Mô tả
*=====================================================================
* 1.0       30/10/2026    CB9980000013 - CuongUS   AK3K908751     Tạo mới
*=====================================================================
CLASS zcl_ads_pdf_demo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    "! Bài 7: abap_true = copy FormVGMCasa vào bảng ZADS_A_TEMPLATE (EML + COMMIT)
    CONSTANTS c_write_template_table TYPE abap_bool VALUE abap_false.
    "! Bài 8: abap_true = tạo item thật trong print queue (COMMIT WORK)
    CONSTANTS c_create_print_item    TYPE abap_bool VALUE abap_false.

    "! Chạy cả 9 bài, trả về nhật ký (classrun in ra màn hình)
    METHODS run_all
      RETURNING VALUE(rt_log) TYPE string_table.

  PROTECTED SECTION.
  PRIVATE SECTION.
    "! Ảnh PNG 1x1 (hex) giả lập cho field ảnh ở bài 5
    CONSTANTS c_png_1x1_part1 TYPE string VALUE `89504E470D0A1A0A0000000D49484452000000010000000108060000001F15C489`.
    CONSTANTS c_png_1x1_part2 TYPE string VALUE `0000000A49444154789C63000100000500010D0A2DB40000000049454E44AE426082`.

    DATA mt_log      TYPE string_table.
    DATA mo_legacy   TYPE REF TO zif_ads_pdf_template_source.
    DATA mo_renderer TYPE REF TO zcl_ads_pdf_renderer.
    "! Renderer dùng template inline ZDEMO_INVOICE (bài 0, bài 9) - chạy được ở mọi client
    DATA mo_inline   TYPE REF TO zcl_ads_pdf_renderer.
    "! XML các bài trước, dùng lại ở bài 7 / 8
    DATA mv_vgm_xml  TYPE xstring.
    DATA mv_pkt_xml  TYPE xstring.

    METHODS log
      IMPORTING iv_text TYPE csequence.

    METHODS log_result
      IMPORTING is_result TYPE zcl_ads_pdf_renderer=>ty_result.

    "! Lọc các dòng lỗi / cảnh báo trong trace ADS (ZCX_ADS_PDF->MV_TRACE)
    METHODS log_trace_errors
      IMPORTING ix_error TYPE REF TO zcx_ads_pdf.

    "! Template có trong client đang chạy không (ghi nhật ký nếu bỏ qua)
    METHODS has_template
      IMPORTING iv_template_id TYPE csequence
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_ads_pdf.

    METHODS get_content
      IMPORTING iv_template_id   TYPE csequence
      RETURNING VALUE(rv_content) TYPE xstring
      RAISING   zcx_ads_pdf.

    "! In XML ra nhật ký, mỗi thẻ một dòng (để học viên nhìn cấu trúc)
    METHODS log_xml
      IMPORTING iv_xml TYPE xstring.

    METHODS lesson_00_hello       RAISING zcx_ads_pdf.
    METHODS lesson_01_explore     RAISING zcx_ads_pdf.
    METHODS lesson_02_from_struct RAISING zcx_ads_pdf.
    METHODS lesson_03_builder     RAISING zcx_ads_pdf.
    METHODS lesson_04_multi_doc   RAISING zcx_ads_pdf.
    METHODS lesson_05_labels      RAISING zcx_ads_pdf.
    METHODS lesson_06_errors      RAISING zcx_ads_pdf.
    METHODS lesson_07_upload      RAISING zcx_ads_pdf.
    METHODS lesson_08_print_queue RAISING zcx_ads_pdf.
    METHODS lesson_09_fdp         RAISING zcx_ads_pdf.
ENDCLASS.



CLASS zcl_ads_pdf_demo IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    LOOP AT run_all( ) INTO DATA(lv_line).
      out->write( lv_line ).
    ENDLOOP.
  ENDMETHOD.

  METHOD run_all.
    CLEAR mt_log.

    "Bước chuẩn bị: renderer đọc template từ bảng cũ (lcl_legacy_source).
    "Dự án thật: zcl_ads_pdf_renderer=>create( ) (bảng mới) hoặc create_for_forms( ).
    mo_legacy   = NEW lcl_legacy_source( ).
    mo_renderer = zcl_ads_pdf_renderer=>create( io_template_source = mo_legacy ).
    mo_inline   = zcl_ads_pdf_renderer=>create( io_template_source = NEW lcl_inline_source( ) ).

    DATA(lv_step) = 0.
    DO 10 TIMES.
      lv_step = sy-index - 1.
      log( `` ).
      TRY.
          CASE lv_step.
            WHEN 0. lesson_00_hello( ).
            WHEN 1. lesson_01_explore( ).
            WHEN 2. lesson_02_from_struct( ).
            WHEN 3. lesson_03_builder( ).
            WHEN 4. lesson_04_multi_doc( ).
            WHEN 5. lesson_05_labels( ).
            WHEN 6. lesson_06_errors( ).
            WHEN 7. lesson_07_upload( ).
            WHEN 8. lesson_08_print_queue( ).
            WHEN 9. lesson_09_fdp( ).
          ENDCASE.
        CATCH zcx_ads_pdf INTO DATA(lx_error).
          log( |  LỖI bài { lv_step }: { lx_error->get_text( ) }| ).
          log_trace_errors( lx_error ).
      ENDTRY.
    ENDDO.

    rt_log = mt_log.
  ENDMETHOD.

  METHOD lesson_00_hello.
    "Ví dụ nhỏ nhất: tự dựng XML + template + 1 lệnh render. Không cần bảng template.
    "Tên thẻ XML phải trùng tên subform/field trong XDP (Form > Invoice > ...).
    log( `BÀI 0 - Hello PDF: dựng XML -> render_single -> nhận PDF (template inline ZDEMO_INVOICE)` ).

    DATA(lo_xml) = zcl_ads_pdf_xml=>create( `Form` ).               "thẻ gốc = subform gốc 'Form'
    lo_xml->open( `Invoice` ).
    lo_xml->add( iv_name = `InvoiceNo`   iv_value = `HD0000` ).
    lo_xml->add( iv_name = `InvoiceDate` iv_value = `20261030` ).    "XDP khai <bind><picture>date{YYYYMMDD}
    lo_xml->add( iv_name = `SellerName`  iv_value = `CÔNG TY TNHH ABC (DEMO)` ).
    lo_xml->add( iv_name = `BuyerName`   iv_value = `Khách lẻ & đại lý <demo>` ).   "& < > tự escape
    lo_xml->open( `_Item` ).
    lo_xml->open( `InvoiceItem` ).                                   "subform lặp: mở 1 lần cho mỗi dòng
    lo_xml->add_number( iv_name = `ItemNo`   iv_value = 10 ).
    lo_xml->add( iv_name = `Description` iv_value = `Bàn làm việc` ).
    lo_xml->add_number( iv_name = `Quantity` iv_value = 1 ).
    lo_xml->add_number( iv_name = `Amount`   iv_value = 500000 ).        "field số: truyền số RAW
    lo_xml->close( ).                                                "InvoiceItem
    lo_xml->close( ).                                                "_Item
    lo_xml->add_number( iv_name = `TotalAmount` iv_value = 500000 ).
    DATA(lv_xml) = lo_xml->to_xstring( ).                            "tự đóng Invoice, Form

    log( `  XML gửi cho ADS (console ADT hiển thị &amp; thành &amp;amp; - dữ liệu thật chỉ escape 1 lần):` ).
    log_xml( lv_xml ).

    DATA(ls_pdf) = mo_inline->render_single( iv_template_id = lcl_inline_source=>c_template_id
                                             iv_xml         = lv_xml ).
    log_result( ls_pdf ).
    log( `  ls_pdf-pdf (xstring) -> lưu attachment / trả về Fiori; ls_pdf-pdf_base64 -> trả qua API` ).
  ENDMETHOD.

  METHOD log_xml.
    DATA lt_line TYPE string_table.
    DATA(lv_text) = cl_abap_conv_codepage=>create_in( codepage = `UTF-8` )->convert( iv_xml ).
    lv_text = replace( val = lv_text sub = `><` with = |>{ cl_abap_char_utilities=>newline }<| occ = 0 ).
    SPLIT lv_text AT cl_abap_char_utilities=>newline INTO TABLE lt_line.
    LOOP AT lt_line INTO DATA(lv_line).
      log( |    { lv_line }| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD lesson_01_explore.
    log( `BÀI 1 - Khám phá template: field nào bind theo tên, field nào bind tường minh` ).
    IF has_template( `FormVGMCasa` ) = abap_false.
      RETURN.
    ENDIF.

    "Parse 1 lần, dùng lại cho nhiều bản ghi
    DATA(lo_parser) = zcl_ads_pdf_xdp_parser=>create( get_content( `FormVGMCasa` ) ).

    LOOP AT lo_parser->get_field_paths( ) INTO DATA(lv_path).
      log( |  field: { lv_path }| ).
    ENDLOOP.
    "Field bind dataRef/global không sinh theo tên -> phải tự dựng XML (bài 3) hoặc dùng FDP (bài 9)
    log( |  bind tường minh (dataRef/global): { lines( lo_parser->get_explicit_bindings( ) ) }| ).
    log( `  => Đặt tên cấu trúc ABAP theo đường dẫn trên: Form-Main-Header-Date ...` ).
  ENDMETHOD.

  METHOD lesson_02_from_struct.
    "Cấu trúc ABAP đặt tên theo field XDP (không phân biệt hoa thường):
    "Form/Main/Header/{Date,Shipper}, Form/Main/Table/ContainerParticular(lặp)/Line/...
    "Field SỐ trong LiveCycle (numericEdit) phải nhận số RAW -> khai kiểu số (p/i),
    "parser xuất 24350.5; hiển thị 24.350,5 là việc của display pattern trong XDP.
    TYPES:
      BEGIN OF ty_line,
        stt             TYPE i,
        containerno     TYPE string,
        sizeofcontainer TYPE string,
        maxgrossweight  TYPE p LENGTH 10 DECIMALS 1,
        verifiedgweight TYPE p LENGTH 10 DECIMALS 1,
      END OF ty_line,
      BEGIN OF ty_particular,
        line TYPE ty_line,
      END OF ty_particular,
      BEGIN OF ty_table,
        containerparticular TYPE STANDARD TABLE OF ty_particular WITH EMPTY KEY,
      END OF ty_table,
      BEGIN OF ty_header,
        date    TYPE string,
        shipper TYPE string,
      END OF ty_header,
      BEGIN OF ty_main,
        header TYPE ty_header,
        table  TYPE ty_table,
      END OF ty_main,
      BEGIN OF ty_form,
        main TYPE ty_main,
      END OF ty_form.

    log( `BÀI 2 - Sinh XML từ cấu trúc ABAP (ZCL_ADS_PDF_XDP_PARSER->build_xml) và render` ).
    IF has_template( `FormVGMCasa` ) = abap_false.
      RETURN.
    ENDIF.

    "Dữ liệu giả lập: tờ khai khối lượng container (VGM) - 3 container
    DATA(ls_form) = VALUE ty_form(
      main = VALUE #(
        header = VALUE #( date    = |Hà Nội, ngày { zcl_ads_pdf_xml=>format_date_vn( '20261030' ) }|
                          shipper = `CÔNG TY TNHH ABC (DEMO)` )
        table  = VALUE #( containerparticular = VALUE #(
          ( line = VALUE #( stt = 1 containerno = `CSLU1234567` sizeofcontainer = `20GP`
                            maxgrossweight = '30480' verifiedgweight = '24350.5' ) )
          ( line = VALUE #( stt = 2 containerno = `CSLU7654321` sizeofcontainer = `40HC`
                            maxgrossweight = '32500' verifiedgweight = '28120.0' ) )
          ( line = VALUE #( stt = 3 containerno = `TGHU0011223` sizeofcontainer = `20GP`
                            maxgrossweight = '30480' verifiedgweight = '21905.8' ) ) ) ) ) ).

    mv_vgm_xml = zcl_ads_pdf_xdp_parser=>create( get_content( `FormVGMCasa` ) )->build_xml( ls_form ).
    log( |  XML: { xstrlen( mv_vgm_xml ) } byte, 3 container (trọng lượng là số RAW, vd 24350.5)| ).

    log_result( mo_renderer->render_single( iv_template_id = `FormVGMCasa` iv_xml = mv_vgm_xml ) ).
  ENDMETHOD.

  METHOD lesson_03_builder.
    log( `BÀI 3 - Dựng XML thủ công bằng ZCL_ADS_PDF_XML (tự escape, tiền VND theo tiền tệ)` ).
    IF has_template( `zphieuthu` ) = abap_false.
      RETURN.
    ENDIF.

    "Số tiền CURR giá trị nội bộ: VND 0 số lẻ -> 15000.00 nội bộ = 1.500.000 đồng
    DATA lv_amount TYPE p LENGTH 15 DECIMALS 2 VALUE '15000.00'.

    DATA(lo_xml) = zcl_ads_pdf_xml=>create( `form1` ).
    "Template có 2 liên giống nhau: main (liên 1), main_1 (liên 2)
    LOOP AT VALUE string_table( ( `main` ) ( `main_1` ) ) INTO DATA(lv_copy).
      lo_xml->open( lv_copy ).

      lo_xml->open( `HeaderSection` ).
      lo_xml->add( iv_name = `CompanyName`    iv_value = `CÔNG TY TNHH ABC (DEMO)` ).
      lo_xml->add( iv_name = `CompanyAddress` iv_value = `123 Đường Mẫu, Quận 1, TP. Hồ Chí Minh` ).
      lo_xml->add( iv_name = `SoPhieu`        iv_value = `PT-2026-000123` ).
      lo_xml->add( iv_name = `AccS`           iv_value = `1111` ).
      lo_xml->add( iv_name = `AccH`           iv_value = `131` ).
      lo_xml->add( iv_name = `Title`          iv_value = `PHIẾU THU` ).
      lo_xml->add( iv_name = `PostingDate`    iv_value = zcl_ads_pdf_xml=>format_date_vn( '20261030' ) ).
      lo_xml->close( ).

      lo_xml->open( `ContentSection` ).
      "Ký tự & < > được escape tự động - không cần REPLACE '&' như code cũ
      lo_xml->add( iv_name = `Doituong` iv_value = `Công ty TNHH Đá & Nội thất <Demo>` ).
      lo_xml->open( `Table2` )->open( `Row1` ).
      lo_xml->add( iv_name = `DiaChi` iv_value = `12 Nguyễn Trãi, Hà Nội` ).
      lo_xml->close( )->close( ).
      lo_xml->add( iv_name = `Diengiai`  iv_value = `Thu tiền hàng theo hoá đơn 0001234` ).
      lo_xml->add( iv_name = `sotien`    iv_value = zcl_ads_pdf_xml=>format_currency_vn( iv_amount = lv_amount iv_currency = `VND` ) ).
      lo_xml->add( iv_name = `sotienchu` iv_value = `Một triệu năm trăm nghìn đồng chẵn` ).
      lo_xml->add( iv_name = `Kemtheo`   iv_value = `02 chứng từ gốc` ).
      lo_xml->add( iv_name = `Nhandu`    iv_value = `Một triệu năm trăm nghìn đồng chẵn` ).
      lo_xml->close( ).

      lo_xml->open( `FooterSection` ).
      lo_xml->open( `Table1` ).
      lo_xml->open( `Row0` )->add( iv_name = `Date` iv_value = `Ngày 30 tháng 10 năm 2026` )->close( ).
      lo_xml->open( `Row2` ).
      lo_xml->add( iv_name = `ChanKy1` iv_value = `Nguyễn Văn A` ).
      lo_xml->add( iv_name = `ChanKy2` iv_value = `Trần Thị B` ).
      lo_xml->add( iv_name = `ChanKy3` iv_value = `Lê Văn C` ).
      lo_xml->add( iv_name = `ChanKy4` iv_value = `Phạm Thị D` ).
      lo_xml->add( iv_name = `ChanKy5` iv_value = `Hoàng Văn E` ).
      lo_xml->close( ).        "Row2
      lo_xml->close( ).        "Table1
      lo_xml->open( `Table4` )->open( `Row1` ).
      lo_xml->add( iv_name = `quydoi` iv_value = `Tỷ giá quy đổi: 1 VND` ).
      lo_xml->close( )->close( ).
      lo_xml->close( ).        "FooterSection

      lo_xml->close( ).        "main / main_1
    ENDLOOP.

    DATA(lv_xml) = lo_xml->to_xstring( ).
    log( |  sotien: { zcl_ads_pdf_xml=>format_currency_vn( iv_amount = lv_amount iv_currency = `VND` ) } (nội bộ { lv_amount })| ).
    log_result( mo_renderer->render_single( iv_template_id = `zphieuthu` iv_xml = lv_xml ) ).
  ENDMETHOD.

  METHOD lesson_04_multi_doc.
    "Phiếu kế toán: Form/Main/formHeader, formTable/Table1/Row1 (lặp), formFooter/Table2/Row2
    TYPES:
      BEGIN OF ty_row,
        documentitemtext TYPE string,
        tkno             TYPE string,
        tkco             TYPE string,
        cocodeamount     TYPE p LENGTH 15 DECIMALS 2,   "field số -> số RAW
      END OF ty_row,
      BEGIN OF ty_table1,
        row1 TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY,
      END OF ty_table1,
      BEGIN OF ty_formtable,
        table1 TYPE ty_table1,
      END OF ty_formtable,
      BEGIN OF ty_row2,
        created_by TYPE string,
        accountant TYPE string,
      END OF ty_row2,
      BEGIN OF ty_table2,
        row2 TYPE ty_row2,
      END OF ty_table2,
      BEGIN OF ty_footer,
        totalamount TYPE p LENGTH 15 DECIMALS 2,
        wordnum     TYPE string,
        table2      TYPE ty_table2,
      END OF ty_footer,
      BEGIN OF ty_header,
        fullname           TYPE string,
        addresscocode      TYPE string,
        date               TYPE string,
        accountingdocument TYPE string,
        nameobj            TYPE string,
        addressobj         TYPE string,
      END OF ty_header,
      BEGIN OF ty_main,
        formheader TYPE ty_header,
        formtable  TYPE ty_formtable,
        formfooter TYPE ty_footer,
      END OF ty_main,
      BEGIN OF ty_form,
        main TYPE ty_main,
      END OF ty_form.

    log( `BÀI 4 - Nhiều chứng từ -> 1 PDF (render + documents), alias tên field, bỏ base64` ).
    IF has_template( `zphieuketoan` ) = abap_false.
      RETURN.
    ENDIF.

    "Parse template 1 lần cho cả 3 chứng từ
    DATA(lo_parser) = zcl_ads_pdf_xdp_parser=>create( get_content( `zphieuketoan` ) ).
    "Field XDP 'Createby' khác tên thành phần ABAP 'CREATED_BY' -> alias
    DATA(lt_alias) = VALUE zcl_ads_pdf_xdp_parser=>tt_alias( ( xdp_name = `Createby` abap_name = `CREATED_BY` ) ).

    DATA lt_documents TYPE zcl_ads_pdf_renderer=>tt_xml.
    DO 3 TIMES.
      DATA(lv_doc_no) = |10000{ sy-index }|.
      DATA(ls_form) = VALUE ty_form(
        main = VALUE #(
          formheader = VALUE #( fullname           = `CÔNG TY TNHH ABC (DEMO)`
                                addresscocode      = `123 Đường Mẫu, Quận 1, TP. Hồ Chí Minh`
                                date               = zcl_ads_pdf_xml=>format_date_vn( '20261030' )
                                accountingdocument = lv_doc_no
                                nameobj            = |Nhà cung cấp số { sy-index }|
                                addressobj         = `Hà Nội` )
          formtable  = VALUE #( table1 = VALUE #( row1 = VALUE #(
                         ( documentitemtext = `Mua đá thô` tkno = `1521` tkco = `331`
                           cocodeamount = '12500000' )
                         ( documentitemtext = `Thuế GTGT 10%` tkno = `1331` tkco = `331`
                           cocodeamount = '1250000' ) ) ) )
          formfooter = VALUE #( totalamount = '13750000'
                                wordnum     = `Mười ba triệu bảy trăm năm mươi nghìn đồng`
                                table2      = VALUE #( row2 = VALUE #( created_by = `Nguyễn Văn A`
                                                                       accountant = `Trần Thị B` ) ) ) ) ).
      APPEND lo_parser->build_xml( is_data = ls_form it_alias = lt_alias ) TO lt_documents.
    ENDDO.
    mv_pkt_xml = lt_documents[ 1 ].

    DATA(ls_result) = mo_renderer->render( VALUE #( template_id = `zphieuketoan`
                                                    documents   = lt_documents
                                                    skip_base64 = abap_true ) ).
    log_result( ls_result ).
    log( `  skip_base64 = abap_true -> PDF_BASE64 rỗng, chỉ giữ PDF xstring (tiết kiệm bộ nhớ)` ).
  ENDMETHOD.

  METHOD lesson_05_labels.
    "Mỗi tem là 1 subform 'main' lặp lại dưới form1 -> bảng nội bộ MAIN
    TYPES:
      BEGIN OF ty_label,
        qrimg       TYPE xstring,     "field ảnh: xstring -> base64 tự động
        storagebin  TYPE string,
        storagebin2 TYPE string,
      END OF ty_label,
      BEGIN OF ty_form,
        main TYPE STANDARD TABLE OF ty_label WITH EMPTY KEY,
      END OF ty_form.

    log( `BÀI 5 - In tem hàng loạt: 1 XML có subform lặp = 1 lần gọi ADS; field ảnh (xstring)` ).
    IF has_template( `zbarcode_bin` ) = abap_false.
      RETURN.
    ENDIF.

    "Ảnh giả lập: PNG 1x1 (dự án thật: ảnh QR / logo đọc từ bảng template hoặc sinh ở UI)
    DATA(lv_image) = CONV xstring( c_png_1x1_part1 && c_png_1x1_part2 ).

    DATA(ls_form) = VALUE ty_form( main = VALUE #(
      ( qrimg = lv_image storagebin = `B3-H3` storagebin2 = `220000` )
      ( qrimg = lv_image storagebin = `B3-H3` storagebin2 = `220001` )
      ( qrimg = lv_image storagebin = `S-K01` storagebin2 = `D1` )
      ( qrimg = lv_image storagebin = `S-K01` storagebin2 = `D2` ) ) ).

    DATA(lv_xml) = zcl_ads_pdf_xdp_parser=>create( get_content( `zbarcode_bin` ) )->build_xml( ls_form ).
    log( |  4 tem, ảnh { xstrlen( lv_image ) } byte -> XML { xstrlen( lv_xml ) } byte, gọi ADS 1 lần| ).
    log_result( mo_renderer->render_single( iv_template_id = `zbarcode_bin` iv_xml = lv_xml ) ).
  ENDMETHOD.

  METHOD lesson_06_errors.
    log( `BÀI 6 - Xử lý lỗi: mọi lỗi là ZCX_ADS_PDF (text, mã template, trace ADS)` ).
    DATA(lv_xml) = zcl_ads_pdf_xml=>create( `form1` )->add( iv_name = `x` iv_value = `1` )->to_xstring( ).

    "a) Template không tồn tại
    TRY.
        mo_renderer->render_single( iv_template_id = `ZKHONG_TON_TAI` iv_xml = lv_xml ).
      CATCH zcx_ads_pdf INTO DATA(lx_missing).
        log( |  a) { lx_missing->get_text( ) } (mv_template_id = { lx_missing->mv_template_id })| ).
    ENDTRY.

    "b) Sai kiểu dữ liệu: field SỐ nhận chuỗi đã định dạng '24.350,5' -> ADS lỗi 29216
    IF has_template( `FormVGMCasa` ) = abap_true.
      DATA(lo_bad) = zcl_ads_pdf_xml=>create( `Form` ).
      lo_bad->open( `Main` )->open( `Table` )->open( `ContainerParticular` )->open( `Line` ).
      lo_bad->add( iv_name = `VerifiedGWeight` iv_value = `24.350,5` ).
      TRY.
          mo_renderer->render_single( iv_template_id = `FormVGMCasa` iv_xml = lo_bad->to_xstring( ) ).
        CATCH zcx_ads_pdf INTO DATA(lx_type).
          log( `  b) Field số nhận '24.350,5' -> ADS từ chối, các dòng lỗi trong trace:` ).
          log_trace_errors( lx_type ).
      ENDTRY.
    ENDIF.

    "c) File không phải XDP (Excel) -> ADS báo lỗi; trace_level > 0 để có trace chẩn đoán
    IF has_template( `zbom` ) = abap_true.
      TRY.
          mo_renderer->render( VALUE #( template_id = `zbom`
                                        documents   = VALUE #( ( lv_xml ) )
                                        trace_level = 1 ) ).
        CATCH zcx_ads_pdf INTO DATA(lx_ads).
          log( |  c) { substring( val = lx_ads->get_text( ) len = nmin( val1 = strlen( lx_ads->get_text( ) ) val2 = 160 ) ) }| ).
          log( |     trace ADS: { strlen( lx_ads->mv_trace ) } ký tự (lx->mv_trace), các dòng lỗi:| ).
          log_trace_errors( lx_ads ).
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD lesson_07_upload.
    log( `BÀI 7 - Upload template vào bảng mới ZADS_A_TEMPLATE (EML) rồi render bằng create( )` ).

    IF c_write_template_table = abap_true AND has_template( `FormVGMCasa` ) = abap_true.
      "Tạo trực tiếp bản active (không qua draft); precheck chặn trùng mã
      MODIFY ENTITIES OF zr_ads_templatetp
        ENTITY Template
          CREATE FIELDS ( TemplateId Description FileContent MimeType FileName )
          WITH VALUE #( ( %cid        = `VGM`
                          %is_draft   = if_abap_behv=>mk-off
                          TemplateId  = `ZVGM_DEMO`
                          Description = `Tờ khai VGM (demo)`
                          FileContent = get_content( `FormVGMCasa` )
                          MimeType    = `application/vnd.adobe.xdp+xml`
                          FileName    = `FormVGMCasa.xdp` ) )
        FAILED DATA(ls_failed)
        REPORTED DATA(ls_reported).

      IF ls_failed IS INITIAL.
        COMMIT ENTITIES RESPONSE OF zr_ads_templatetp
          FAILED DATA(ls_commit_failed)
          REPORTED DATA(ls_commit_reported).
        log( COND #( WHEN ls_commit_failed IS INITIAL THEN `  Đã ghi ZVGM_DEMO vào ZADS_A_TEMPLATE`
                                                      ELSE `  COMMIT ENTITIES lỗi` ) ).
      ELSE.
        LOOP AT ls_reported-template INTO DATA(ls_message).
          log( |  { ls_message-%msg->if_message~get_text( ) }| ).
        ENDLOOP.
      ENDIF.
    ELSE.
      log( `  (C_WRITE_TEMPLATE_TABLE = abap_false: không ghi bảng; bật cờ để chạy phần upload)` ).
    ENDIF.

    "Render bằng nguồn mặc định = bảng mới (cách dùng trong dự án thật)
    DATA(lo_renderer) = zcl_ads_pdf_renderer=>create( ).
    TRY.
        IF mv_vgm_xml IS INITIAL.
          log( `  Chưa có XML của bài 2 - bỏ qua phần render` ).
          RETURN.
        ENDIF.
        log_result( lo_renderer->render_single( iv_template_id = `ZVGM_DEMO` iv_xml = mv_vgm_xml ) ).
      CATCH zcx_ads_pdf INTO DATA(lx_error).
        log( |  { lx_error->get_text( ) } -> upload qua app ZUI_ADS_TEMPLATE_O4 hoặc bật cờ| ).
    ENDTRY.
  ENDMETHOD.

  METHOD lesson_08_print_queue.
    log( `BÀI 8 - Print queue: bước 1 render PDL, bước 2 tạo queue item` ).
    DATA(lt_queue) = cl_print_queue_utils=>get_pqname_list( ).
    log( |  Số print queue trong client: { lines( lt_queue ) }| ).
    IF lt_queue IS INITIAL OR mv_pkt_xml IS INITIAL.
      log( `  (không có queue hoặc chưa có XML của bài 4 - bỏ qua)` ).
      RETURN.
    ENDIF.

    DATA(lv_queue) = lt_queue[ 1 ].
    "Bước 1 - gọi ADS (trong RAP: ở action/determination, KHÔNG ở save)
    DATA(ls_output) = mo_renderer->render_for_print_queue( iv_template_id = `zphieuketoan`
                                                           iv_xml         = mv_pkt_xml
                                                           iv_queue_name  = lv_queue ).
    log( |  Queue { lv_queue }: { ls_output-pages } trang, { xstrlen( ls_output-data ) } byte theo định dạng của queue| ).

    "Bước 2 - tạo item (trong RAP: ở late save, item id từ cl_print_queue_utils=>create_queue_itemid( ))
    IF c_create_print_item = abap_true.
      DATA(lv_item) = zcl_ads_pdf_renderer=>add_to_print_queue( is_output        = ls_output
                                                                iv_queue_name    = lv_queue
                                                                iv_document_name = `DEMO_PHIEUKETOAN` ).
      COMMIT WORK.
      log( |  Đã tạo item { lv_item }| ).
    ELSE.
      log( `  (C_CREATE_PRINT_ITEM = abap_false: không tạo item thật)` ).
    ENDIF.
  ENDMETHOD.

  METHOD lesson_09_fdp.
    "Luồng FDP đầy đủ, dữ liệu giả lập, chạy được ở mọi client:
    "  CDS ZI_ADS_DEMO_INVOICE (header) --_Item--> ZI_ADS_DEMO_INVOICEITEM (dòng)
    "  Service definition ZUI_ADS_DEMO_FDP expose: Invoice, InvoiceItem
    "  B1 get_xsd  -> XSD: nạp vào LiveCycle làm data connection, kéo field ra form
    "  B2 read_xml -> XML 1 hoá đơn theo khoá; tên thẻ = tên expose / tên field CDS
    "  B3 render   -> template ZDEMO_INVOICE (thiết kế theo XSD ở B1)
    log( `BÀI 9 - FDP: CDS + service definition -> XSD (thiết kế form) -> XML (lúc in) -> PDF` ).

    DATA(lo_fdp) = zcl_ads_pdf_fdp=>create( `ZUI_ADS_DEMO_FDP` ).
    log( |  Khoá của root (truyền vào read_xml): { concat_lines_of( table = lo_fdp->get_key_names( ) sep = `, ` ) }| ).

    "B1 - lúc THIẾT KẾ form (làm 1 lần): lấy XSD, lưu file .xsd, LiveCycle: File > New Data Connection
    DATA(lv_xsd) = lo_fdp->get_xsd( ).
    log( |  B1 XSD: { xstrlen( lv_xsd ) } byte - phần tử gốc Form > Invoice > _Item > InvoiceItem (lặp)| ).

    "B2 - lúc IN: đọc dữ liệu 1 hoá đơn theo khoá
    DATA(lv_xml) = lo_fdp->read_xml( VALUE #( ( name = `InvoiceNo` value = `HD0001` ) ) ).
    log( `  B2 XML do FDP sinh ra (ngày dạng YYYYMMDD, số dạng RAW):` ).
    log_xml( lv_xml ).

    "B3 - render với template thiết kế theo XSD ở B1
    log_result( mo_inline->render_single( iv_template_id = lcl_inline_source=>c_template_id iv_xml = lv_xml ) ).
  ENDMETHOD.

  METHOD log.
    APPEND CONV string( iv_text ) TO mt_log.
  ENDMETHOD.

  METHOD log_result.
    log( |  PDF: { is_result-pages } trang, { is_result-documents } tài liệu, { xstrlen( is_result-pdf ) DIV 1024 } KB, | &&
         |base64 { strlen( is_result-pdf_base64 ) } ký tự| ).
  ENDMETHOD.

  METHOD log_trace_errors.
    DATA lt_line TYPE string_table.
    DATA(lv_count) = 0.

    "Trace ADS là văn bản nhiều dòng; dòng nguyên nhân chứa Error / Exception / Warning
    DATA(lv_trace) = replace( val = ix_error->mv_trace sub = cl_abap_char_utilities=>cr_lf
                              with = cl_abap_char_utilities=>newline occ = 0 ).
    SPLIT lv_trace AT cl_abap_char_utilities=>newline INTO TABLE lt_line.
    LOOP AT lt_line INTO DATA(lv_line).
      IF to_lower( lv_line ) CS `error` OR to_lower( lv_line ) CS `exception`
      OR to_lower( lv_line ) CS `warning` OR to_lower( lv_line ) CS `severe`.
        log( |     trace: { condense( lv_line ) }| ).
        lv_count += 1.
        IF lv_count = 6.
          EXIT.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD has_template.
    rv_found = xsdbool( mo_legacy->get_templates( VALUE #( ( CONV #( iv_template_id ) ) ) ) IS NOT INITIAL ).
    IF rv_found = abap_false.
      log( |  (bỏ qua: client { sy-mandt } không có template { iv_template_id } trong ZCORE_TB_TEMPPDF)| ).
    ENDIF.
  ENDMETHOD.

  METHOD get_content.
    DATA(lt_template) = mo_legacy->get_templates( VALUE #( ( CONV #( iv_template_id ) ) ) ).
    IF lt_template IS INITIAL.
      RAISE EXCEPTION NEW zcx_ads_pdf( iv_text = |Không có template { iv_template_id }| iv_template_id = iv_template_id ).
    ENDIF.
    rv_content = lt_template[ 1 ]-content.
  ENDMETHOD.

ENDCLASS.