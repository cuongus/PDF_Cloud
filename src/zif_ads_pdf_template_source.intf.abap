*=====================================================================
* Tên/Mã     : ZIF_ADS_PDF_TEMPLATE_SOURCE
* Mô tả chung: Nguồn template XDP / ảnh cho bộ render (bảng ZADS_A_TEMPLATE
*              hoặc object Form trong ADT); tách ra để thay bằng test double
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_ADS_PDF
*=====================================================================
* Version   Ngày          Người sửa                Transport      Mô tả
*=====================================================================
* 1.0       30/10/2026    CB9980000013 - CuongUS   AK3K908751     Tạo mới
*=====================================================================
INTERFACE zif_ads_pdf_template_source
  PUBLIC.

  TYPES ty_template_id TYPE c LENGTH 40.
  TYPES tt_template_id TYPE STANDARD TABLE OF ty_template_id WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_template,
      template_id TYPE ty_template_id,
      content     TYPE xstring,
      mime_type   TYPE string,
      version     TYPE i,
      embed_fonts TYPE abap_bool,
    END OF ty_template,
    tt_template TYPE SORTED TABLE OF ty_template WITH UNIQUE KEY template_id.

  "! Read templates in one call. IDs are compared in upper case;
  "! an ID that does not exist is missing from the result (no exception).
  "! @parameter it_template_id | Template IDs
  "! @parameter rt_template    | Templates found
  "! @raising zcx_ads_pdf      | Technical error while reading
  METHODS get_templates
    IMPORTING it_template_id     TYPE tt_template_id
    RETURNING VALUE(rt_template) TYPE tt_template
    RAISING   zcx_ads_pdf.

ENDINTERFACE.