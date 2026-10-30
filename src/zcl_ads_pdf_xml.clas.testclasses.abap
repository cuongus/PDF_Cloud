*"* Unit tests ZCL_ADS_PDF_XML
CLASS ltcl_xml DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS amount_grouping   FOR TESTING.
    METHODS amount_negative   FOR TESTING.
    METHODS amount_zero       FOR TESTING.
    METHODS currency_decimals FOR TESTING.
    METHODS date_vn           FOR TESTING.
    METHODS escape_special    FOR TESTING.
    METHODS builder_escapes   FOR TESTING.
    METHODS builder_formats   FOR TESTING.

    CLASS-METHODS to_string
      IMPORTING iv_xml         TYPE xstring
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.

CLASS ltcl_xml IMPLEMENTATION.

  METHOD amount_grouping.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ads_pdf_xml=>format_amount_vn( iv_amount = CONV #( '1234567.891' ) iv_decimals = 2 )
      exp = `1.234.567,89` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ads_pdf_xml=>format_amount_vn( CONV #( '123456' ) )
      exp = `123.456` ).
  ENDMETHOD.

  METHOD amount_negative.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ads_pdf_xml=>format_amount_vn( CONV #( '-1000' ) )
      exp = `-1.000` ).
  ENDMETHOD.

  METHOD amount_zero.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ads_pdf_xml=>format_amount_vn( CONV #( '-0.001' ) )
      exp = `0` ).
  ENDMETHOD.

  METHOD currency_decimals.
    "JPY: 0 số lẻ (TCURX chuẩn) -> giá trị nội bộ 123.45 là 12345 yên
    DATA lv_amount TYPE p LENGTH 15 DECIMALS 2 VALUE '123.45'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ads_pdf_xml=>format_currency_vn( iv_amount = lv_amount iv_currency = `JPY` )
      exp = `12.345` ).
    lv_amount = '1234.5'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ads_pdf_xml=>format_currency_vn( iv_amount = lv_amount iv_currency = `USD` )
      exp = `1.234,50` ).
  ENDMETHOD.

  METHOD date_vn.
    cl_abap_unit_assert=>assert_equals( act = zcl_ads_pdf_xml=>format_date_vn( '20261030' )
                                        exp = `30/10/2026` ).
    cl_abap_unit_assert=>assert_initial( zcl_ads_pdf_xml=>format_date_vn( VALUE #( ) ) ).
  ENDMETHOD.

  METHOD escape_special.
    cl_abap_unit_assert=>assert_equals( act = zcl_ads_pdf_xml=>escape_text( `A & B <C> ]]>` )
                                        exp = `A &amp; B &lt;C> ]]&gt;` ).
  ENDMETHOD.

  METHOD builder_escapes.
    DATA(lo_xml) = zcl_ads_pdf_xml=>create( `Form` ).
    lo_xml->open( `Header` ).
    lo_xml->add( iv_name  = `Name`
                 iv_value = |Công ty A & B <VN>{ cl_abap_char_utilities=>backspace }| ).

    DATA(lv_xml) = to_string( lo_xml->to_xstring( ) ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_xml
      exp = `*<Form><Header><Name>Công ty A &amp; B &lt;VN&gt;</Name></Header></Form>*` ).
  ENDMETHOD.

  METHOD builder_formats.
    DATA lv_jpy TYPE p LENGTH 15 DECIMALS 2 VALUE '100.00'.
    DATA(lo_xml) = zcl_ads_pdf_xml=>create( `Form` ).
    lo_xml->add_date( iv_name = `Date` iv_date = '20261030' ).
    lo_xml->add_date( iv_name = `Empty` iv_date = VALUE #( ) ).
    lo_xml->add_number( iv_name = `Amount` iv_value = CONV #( '1234.50' ) ).
    lo_xml->add_amount( iv_name = `Yen` iv_amount = lv_jpy iv_currency = `JPY` ).

    DATA(lv_xml) = to_string( lo_xml->to_xstring( ) ).

    cl_abap_unit_assert=>assert_char_cp( act = lv_xml exp = `*<Date>2026-10-30</Date>*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_xml exp = `*<Empty/>*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_xml exp = `*<Amount>1234.5*</Amount>*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_xml exp = `*<Yen>10000</Yen>*` ).
  ENDMETHOD.

  METHOD to_string.
    rv_text = cl_abap_conv_codepage=>create_in( codepage = `UTF-8` )->convert( iv_xml ).
  ENDMETHOD.

ENDCLASS.