*=====================================================================
* Tên/Mã     : ZCL_ADS_PDF_XML
* Mô tả chung: Dựng XML dữ liệu cho form ADS an toàn (tự escape & < >,
*              bỏ ký tự điều khiển làm hỏng XML), xuất UTF-8; kèm hàm định
*              dạng ngày / số / số tiền theo tiền tệ kiểu Việt Nam
* Tham Số    : create( iv_root ) - thẻ gốc, khớp tên subform gốc của XDP
* Lưu ý      : tên phần tử phải là tên XML hợp lệ (tên field/subform XDP)
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_ADS_PDF
*=====================================================================
* Version   Ngày          Người sửa                Transport      Mô tả
*=====================================================================
* 1.0       30/10/2026    CB9980000013 - CuongUS   AK3K908751     Tạo mới
*=====================================================================
CLASS zcl_ads_pdf_xml DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Start a document with root element IV_ROOT
    CLASS-METHODS create
      IMPORTING iv_root       TYPE csequence
      RETURNING VALUE(ro_xml) TYPE REF TO zcl_ads_pdf_xml.

    "! Open a container element (subform / repeating row)
    METHODS open
      IMPORTING iv_name       TYPE csequence
      RETURNING VALUE(ro_xml) TYPE REF TO zcl_ads_pdf_xml.

    "! Close the last opened element
    METHODS close
      RETURNING VALUE(ro_xml) TYPE REF TO zcl_ads_pdf_xml.

    "! &lt;name&gt;value&lt;/name&gt; - value is escaped automatically
    METHODS add
      IMPORTING iv_name       TYPE csequence
                iv_value      TYPE csequence
      RETURNING VALUE(ro_xml) TYPE REF TO zcl_ads_pdf_xml.

    "! Date in XFA data format YYYY-MM-DD (empty element if initial)
    METHODS add_date
      IMPORTING iv_name       TYPE csequence
                iv_date       TYPE d
      RETURNING VALUE(ro_xml) TYPE REF TO zcl_ads_pdf_xml.

    "! Number in XFA data format (no grouping, '.' as decimal separator)
    METHODS add_number
      IMPORTING iv_name       TYPE csequence
                iv_value      TYPE decfloat34
      RETURNING VALUE(ro_xml) TYPE REF TO zcl_ads_pdf_xml.

    "! Amount field (CURR, internal value) with the decimals of the currency
    "! applied, in XFA data format - e.g. VND/JPY internal 100.00 -> 10000
    METHODS add_amount
      IMPORTING iv_name       TYPE csequence
                iv_amount     TYPE p
                iv_currency   TYPE csequence
      RETURNING VALUE(ro_xml) TYPE REF TO zcl_ads_pdf_xml.

    "! Close all open elements and return the document (UTF-8)
    METHODS to_xstring
      RETURNING VALUE(rv_xml) TYPE xstring.

    "! Escape text for XML built as a string (legacy callers)
    CLASS-METHODS escape_text
      IMPORTING iv_text        TYPE csequence
      RETURNING VALUE(rv_text) TYPE string.

    "! String XML -> UTF-8 xstring for CL_FP_ADS_UTIL
    CLASS-METHODS string_to_xstring
      IMPORTING iv_xml        TYPE string
      RETURNING VALUE(rv_xml) TYPE xstring.

    "! DD/MM/YYYY (empty if initial)
    CLASS-METHODS format_date_vn
      IMPORTING iv_date        TYPE d
      RETURNING VALUE(rv_text) TYPE string.

    "! 1.234.567,89 - '.' groups thousands, ',' separates decimals
    CLASS-METHODS format_amount_vn
      IMPORTING iv_amount      TYPE decfloat34
                iv_decimals    TYPE i DEFAULT 0
      RETURNING VALUE(rv_text) TYPE string.

    "! Amount field (CURR, internal value) formatted with the decimals of
    "! the currency - e.g. VND internal 10000.00 -> 1.000.000
    CLASS-METHODS format_currency_vn
      IMPORTING iv_amount      TYPE p
                iv_currency    TYPE csequence
      RETURNING VALUE(rv_text) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_output TYPE REF TO cl_sxml_string_writer.
    DATA mo_writer TYPE REF TO if_sxml_writer.
    DATA mv_open   TYPE i.

    METHODS constructor
      IMPORTING iv_root TYPE csequence.

    CLASS-METHODS sanitize
      IMPORTING iv_text        TYPE csequence
      RETURNING VALUE(rv_text) TYPE string.

    "! RAW number text ('-1234.5') -> '-1.234,5'
    CLASS-METHODS group_vn
      IMPORTING iv_raw         TYPE string
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.



CLASS zcl_ads_pdf_xml IMPLEMENTATION.

  METHOD constructor.
    mo_output = cl_sxml_string_writer=>create( ).
    mo_writer = mo_output.
    mo_writer->open_element( name = CONV #( iv_root ) ).
    mv_open = 1.
  ENDMETHOD.

  METHOD create.
    ro_xml = NEW #( iv_root ).
  ENDMETHOD.

  METHOD open.
    mo_writer->open_element( name = CONV #( iv_name ) ).
    mv_open += 1.
    ro_xml = me.
  ENDMETHOD.

  METHOD close.
    IF mv_open > 0.
      mo_writer->close_element( ).
      mv_open -= 1.
    ENDIF.
    ro_xml = me.
  ENDMETHOD.

  METHOD add.
    mo_writer->open_element( name = CONV #( iv_name ) ).
    DATA(lv_value) = sanitize( iv_value ).
    IF lv_value IS NOT INITIAL.
      mo_writer->write_value( lv_value ).     "SXML writer escapes & < >
    ENDIF.
    mo_writer->close_element( ).
    ro_xml = me.
  ENDMETHOD.

  METHOD add_date.
    ro_xml = add( iv_name  = iv_name
                  iv_value = COND string( WHEN iv_date IS INITIAL THEN ``
                                          ELSE |{ iv_date+0(4) }-{ iv_date+4(2) }-{ iv_date+6(2) }| ) ).
  ENDMETHOD.

  METHOD add_number.
    ro_xml = add( iv_name = iv_name iv_value = |{ iv_value NUMBER = RAW }| ).
  ENDMETHOD.

  METHOD add_amount.
    ro_xml = add( iv_name = iv_name iv_value = |{ iv_amount CURRENCY = iv_currency NUMBER = RAW }| ).
  ENDMETHOD.

  METHOD to_xstring.
    WHILE mv_open > 0.
      close( ).
    ENDWHILE.
    rv_xml = mo_output->get_output( ).
  ENDMETHOD.

  METHOD escape_text.
    rv_text = escape( val = sanitize( iv_text ) format = cl_abap_format=>e_xml_text ).
    "']]>' không được xuất hiện trong text node
    rv_text = replace( val = rv_text sub = `]]>` with = `]]&gt;` occ = 0 ).
  ENDMETHOD.

  METHOD string_to_xstring.
    rv_xml = cl_abap_conv_codepage=>create_out( codepage = `UTF-8` )->convert( iv_xml ).
  ENDMETHOD.

  METHOD format_date_vn.
    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.
    rv_text = |{ iv_date+6(2) }/{ iv_date+4(2) }/{ iv_date+0(4) }|.
  ENDMETHOD.

  METHOD format_amount_vn.
    DATA(lv_decimals) = nmax( val1 = 0 val2 = iv_decimals ).
    DATA(lv_rounded)  = round( val = iv_amount dec = lv_decimals ).
    rv_text = group_vn( |{ lv_rounded DECIMALS = lv_decimals NUMBER = RAW }| ).
  ENDMETHOD.

  METHOD format_currency_vn.
    rv_text = group_vn( |{ iv_amount CURRENCY = iv_currency NUMBER = RAW }| ).
  ENDMETHOD.

  METHOD group_vn.
    DATA lv_int  TYPE string.
    DATA lv_frac TYPE string.

    DATA(lv_raw) = condense( iv_raw ).
    DATA(lv_negative) = xsdbool( lv_raw CA `-` ).
    lv_raw = replace( val = lv_raw sub = `-` with = `` occ = 0 ).
    SPLIT lv_raw AT `.` INTO lv_int lv_frac.

    "Nhóm hàng nghìn bằng dấu chấm, từ phải sang trái
    DATA(lv_len) = strlen( lv_int ).
    DO lv_len TIMES.
      rv_text = substring( val = lv_int off = lv_len - sy-index len = 1 ) && rv_text.
      IF sy-index MOD 3 = 0 AND sy-index < lv_len.
        rv_text = `.` && rv_text.
      ENDIF.
    ENDDO.

    IF lv_frac IS NOT INITIAL.
      rv_text = |{ rv_text },{ lv_frac }|.
    ENDIF.
    "Không in '-0'
    IF lv_negative = abap_true AND rv_text CN `0.,`.
      rv_text = `-` && rv_text.
    ENDIF.
  ENDMETHOD.

  METHOD sanitize.
    "Ký tự điều khiển (trừ TAB, LF, CR) không hợp lệ trong XML 1.0 -> ADS lỗi
    rv_text = replace( val = iv_text pcre = `[\x00-\x08\x0B\x0C\x0E-\x1F]` with = `` occ = 0 ).
  ENDMETHOD.

ENDCLASS.