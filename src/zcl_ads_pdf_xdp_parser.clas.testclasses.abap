*"* Unit tests ZCL_ADS_PDF_XDP_PARSER
CLASS ltcl_parser DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_line,
        qty  TYPE i,
        name TYPE string,
      END OF ty_line,
      BEGIN OF ty_items,
        line TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY,
      END OF ty_items,
      BEGIN OF ty_header,
        date         TYPE d,
        shipper_name TYPE string,
        paid         TYPE abap_bool,
        time         TYPE t,
        code         TYPE x LENGTH 2,
      END OF ty_header,
      BEGIN OF ty_main,
        header TYPE ty_header,
        note   TYPE string,
        flat   TYPE string,
        items  TYPE ty_items,
      END OF ty_main,
      BEGIN OF ty_form,
        main TYPE ty_main,
      END OF ty_form.

    METHODS field_paths       FOR TESTING RAISING zcx_ads_pdf.
    METHODS explicit_bindings FOR TESTING RAISING zcx_ads_pdf.
    METHODS xml_from_data     FOR TESTING RAISING zcx_ads_pdf.
    METHODS invalid_xdp       FOR TESTING.
    METHODS unnamed_root      FOR TESTING.

    CLASS-METHODS sample_xdp
      RETURNING VALUE(rv_xdp) TYPE xstring.
ENDCLASS.

CLASS ltcl_parser IMPLEMENTATION.

  METHOD sample_xdp.
    rv_xdp = cl_abap_conv_codepage=>create_out( codepage = `UTF-8` )->convert(
      `<?xml version="1.0" encoding="UTF-8"?>` &&
      `<xdp:xdp xmlns:xdp="http://ns.adobe.com/xdp/">` &&
      `<template xmlns="http://www.xfa.org/schema/xfa-template/3.3/">` &&
      `<subform name="Form"><subform name="Main">` &&
      `<subform name="Header">` &&
      `<field name="Date"><ui><dateTimeEdit/></ui></field>` &&
      `<field name="Shipper"/><field name="Paid"/><field name="Time"/><field name="Code"/>` &&
      `<field name="Internal"><bind match="none"/></field>` &&
      `<field name="Total"><bind match="dataRef" ref="$.Totals.Amount"/></field>` &&
      `</subform>` &&
      `<subform><field name="Note"/></subform>` &&
      `<subform name="Wrapper"><bind match="none"/><field name="Flat"/></subform>` &&
      `<subform name="Items"><subform name="Line"><occur max="-1"/>` &&
      `<field name="Qty"/><field name="Name"/></subform></subform>` &&
      `<draw name="Title"/>` &&
      `</subform></subform>` &&
      `</template>` &&
      `<config xmlns="http://www.xfa.org/schema/xci/3.0/"><field name="Ignored"/></config>` &&
      `</xdp:xdp>` ).
  ENDMETHOD.

  METHOD field_paths.
    DATA(lt_path) = zcl_ads_pdf_xdp_parser=>create( sample_xdp( ) )->get_field_paths( ).

    cl_abap_unit_assert=>assert_equals(
      act = lt_path
      exp = VALUE string_table( ( `Form/Main/Header/Date` )
                                ( `Form/Main/Header/Shipper` )
                                ( `Form/Main/Header/Paid` )
                                ( `Form/Main/Header/Time` )
                                ( `Form/Main/Header/Code` )
                                ( `Form/Main/Note` )
                                ( `Form/Main/Flat` )
                                ( `Form/Main/Items/Line/Qty` )
                                ( `Form/Main/Items/Line/Name` ) ) ).
  ENDMETHOD.

  METHOD explicit_bindings.
    DATA(lt_binding) = zcl_ads_pdf_xdp_parser=>create( sample_xdp( ) )->get_explicit_bindings( ).

    cl_abap_unit_assert=>assert_equals(
      act = lt_binding
      exp = VALUE zcl_ads_pdf_xdp_parser=>tt_binding(
              ( path = `Form/Main/Header/Total` match = `dataRef` ref = `$.Totals.Amount` ) ) ).
  ENDMETHOD.

  METHOD xml_from_data.
    DATA(ls_form) = VALUE ty_form(
      main = VALUE #( header = VALUE #( date = '20261030' shipper_name = `A & B` paid = abap_true code = 'AB01' )
                      note   = `N`
                      flat   = `F`
                      items  = VALUE #( line = VALUE #( ( qty = 2 name = `X` )
                                                        ( qty = 3 name = `Y` ) ) ) ) ).

    DATA(lv_xml) = cl_abap_conv_codepage=>create_in( codepage = `UTF-8` )->convert(
      zcl_ads_pdf_xdp_parser=>create( sample_xdp( ) )->build_xml(
        is_data  = ls_form
        it_alias = VALUE #( ( xdp_name = `Shipper` abap_name = `SHIPPER_NAME` ) ) ) ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_xml
      exp = `*<Form><Main><Header><Date>2026-10-30</Date><Shipper>A &amp; B</Shipper>` &&
            `<Paid>1</Paid><Time/><Code>AB01</Code></Header>` &&
            `<Note>N</Note><Flat>F</Flat><Items><Line><Qty>2</Qty><Name>X</Name></Line>` &&
            `<Line><Qty>3</Qty><Name>Y</Name></Line></Items></Main></Form>*` ).
  ENDMETHOD.

  METHOD invalid_xdp.
    TRY.
        zcl_ads_pdf_xdp_parser=>create(
          cl_abap_conv_codepage=>create_out( codepage = `UTF-8` )->convert( `<a><b></a>` ) ).
        cl_abap_unit_assert=>fail( `Phải báo lỗi XDP không hợp lệ` ).
      CATCH zcx_ads_pdf ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD unnamed_root.
    TRY.
        zcl_ads_pdf_xdp_parser=>create( cl_abap_conv_codepage=>create_out( codepage = `UTF-8` )->convert(
          `<xdp><template><subform><field name="A"/><field name="B"/></subform></template></xdp>` ) ).
        cl_abap_unit_assert=>fail( `Phải báo lỗi nhiều nút gốc` ).
      CATCH zcx_ads_pdf ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.