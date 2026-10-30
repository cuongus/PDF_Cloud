*=====================================================================
* Tên/Mã     : ZIF_ADS_PDF_ENGINE
* Mô tả chung: Lớp gọi Adobe Document Services (render PDF/PDL, gộp PDF);
*              tách ra để unit test không cần gọi ADS thật
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_ADS_PDF
*=====================================================================
* Version   Ngày          Người sửa                Transport      Mô tả
*=====================================================================
* 1.0       30/10/2026    CB9980000013 - CuongUS   AK3K908751     Tạo mới
*=====================================================================
INTERFACE zif_ads_pdf_engine
  PUBLIC.

  TYPES:
    BEGIN OF ty_options,
      locale      TYPE string,
      embed_fonts TYPE abap_bool,
      trace_level TYPE i,
    END OF ty_options.

  TYPES:
    BEGIN OF ty_output,
      data  TYPE xstring,
      pages TYPE i,
    END OF ty_output.

  TYPES tt_pdf TYPE STANDARD TABLE OF xstring WITH EMPTY KEY.

  "! Render one XML data document with an XDP layout into a PDF
  METHODS render_pdf
    IMPORTING iv_xml           TYPE xstring
              iv_layout        TYPE xstring
              is_options       TYPE ty_options
    RETURNING VALUE(rs_output) TYPE ty_output
    RAISING   zcx_ads_pdf.

  "! Render in the print format (PDL) of a print queue
  METHODS render_pdl
    IMPORTING iv_xml           TYPE xstring
              iv_layout        TYPE xstring
              iv_queue_name    TYPE csequence
              is_options       TYPE ty_options
    RETURNING VALUE(rs_output) TYPE ty_output
    RAISING   zcx_ads_pdf.

  "! Merge PDFs in table order into one PDF
  METHODS merge
    IMPORTING it_pdf        TYPE tt_pdf
    RETURNING VALUE(rv_pdf) TYPE xstring
    RAISING   zcx_ads_pdf.

ENDINTERFACE.