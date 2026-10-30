*=====================================================================
* Tên/Mã     : ZCL_ADS_PDF_FDP
* Mô tả chung: Lấy XML dữ liệu và XSD cho form từ service definition
*              (RAP Data Services for Print Forms, API đã release
*              CL_FP_FDP_SERVICES) - thay cho việc tự ghép XML bằng chuỗi.
*              XSD dùng làm data connection trong Adobe LiveCycle Designer.
* Tham Số    : create( iv_service_definition ) - service definition (chữ hoa),
*              không cần service binding
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_ADS_PDF
*=====================================================================
* Version   Ngày          Người sửa                Transport      Mô tả
*=====================================================================
* 1.0       30/10/2026    CB9980000013 - CuongUS   AK3K908751     Tạo mới
*=====================================================================
CLASS zcl_ads_pdf_fdp DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_key,
        name  TYPE string,
        value TYPE string,
      END OF ty_key,
      tt_key TYPE STANDARD TABLE OF ty_key WITH EMPTY KEY.

    CLASS-METHODS create
      IMPORTING iv_service_definition TYPE csequence
      RETURNING VALUE(ro_fdp)         TYPE REF TO zcl_ads_pdf_fdp
      RAISING   zcx_ads_pdf.

    "! Key fields the caller has to fill (root entity keys)
    METHODS get_key_names
      RETURNING VALUE(rt_name) TYPE string_table.

    "! XML data of one root instance (key names are case-insensitive)
    METHODS read_xml
      IMPORTING it_key        TYPE tt_key
                iv_language   TYPE sy-langu DEFAULT sy-langu
      RETURNING VALUE(rv_xml) TYPE xstring
      RAISING   zcx_ads_pdf.

    "! XSD of the data - import into LiveCycle Designer as data connection
    METHODS get_xsd
      RETURNING VALUE(rv_xsd) TYPE xstring
      RAISING   zcx_ads_pdf.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_api     TYPE REF TO if_fp_fdp_api.
    DATA mv_service TYPE string.
ENDCLASS.



CLASS zcl_ads_pdf_fdp IMPLEMENTATION.

  METHOD create.
    ro_fdp = NEW #( ).
    ro_fdp->mv_service = to_upper( iv_service_definition ).
    TRY.
        ro_fdp->mo_api = cl_fp_fdp_services=>get_instance( CONV #( ro_fdp->mv_service ) ).
      CATCH cx_fp_fdp_error INTO DATA(lx_fdp).
        RAISE EXCEPTION NEW zcx_ads_pdf( previous = lx_fdp
                                         iv_text  = |Service definition { ro_fdp->mv_service }: { lx_fdp->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD get_key_names.
    rt_name = VALUE #( FOR ls_key IN mo_api->get_keys( ) ( ls_key-name ) ).
  ENDMETHOD.

  METHOD read_xml.
    DATA(lt_select) = mo_api->get_keys( ).

    LOOP AT lt_select ASSIGNING FIELD-SYMBOL(<ls_select>).
      DATA(lv_found) = abap_false.
      LOOP AT it_key INTO DATA(ls_key).
        IF to_upper( ls_key-name ) = to_upper( <ls_select>-name ).
          <ls_select>-value = ls_key-value.
          lv_found = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_found = abap_false.
        RAISE EXCEPTION NEW zcx_ads_pdf( iv_text = |Thiếu giá trị khoá { <ls_select>-name } của { mv_service }| ).
      ENDIF.
    ENDLOOP.

    TRY.
        rv_xml = mo_api->read_to_xml_v2( it_select = lt_select iv_language = iv_language ).
      CATCH cx_fp_fdp_error INTO DATA(lx_fdp).
        RAISE EXCEPTION NEW zcx_ads_pdf( previous = lx_fdp
                                         iv_text  = |Đọc dữ liệu { mv_service }: { lx_fdp->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD get_xsd.
    TRY.
        rv_xsd = mo_api->get_xsd_v2( ).
      CATCH cx_fp_fdp_error INTO DATA(lx_fdp).
        RAISE EXCEPTION NEW zcx_ads_pdf( previous = lx_fdp
                                         iv_text  = |XSD { mv_service }: { lx_fdp->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.