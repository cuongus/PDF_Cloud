*=====================================================================
* Tên/Mã     : ZBP_R_ADS_TEMPLATETP (local handler)
* Mô tả chung: Behavior handler quản lý template ADS: phân quyền tổng,
*              chặn trùng mã khi tạo, suy ra kiểu file từ đuôi tên file,
*              tăng phiên bản khi đổi file, kiểm tra mã/file/kiểu file
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_ADS_PDF
*=====================================================================
* Version   Ngày          Người sửa                Transport      Mô tả
*=====================================================================
* 1.0       30/10/2026    CB9980000013 - CuongUS   AK3K908751     Tạo mới
*=====================================================================
CLASS lhc_template DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS c_state_area TYPE string VALUE 'VALIDATE_TEMPLATE'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Template RESULT result.

    METHODS precheck_create FOR PRECHECK
      IMPORTING entities FOR CREATE Template.

    METHODS derivemimetype FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Template~deriveMimeType.

    METHODS setversion FOR DETERMINE ON SAVE
      IMPORTING keys FOR Template~setVersion.

    METHODS validatetemplate FOR VALIDATE ON SAVE
      IMPORTING keys FOR Template~validateTemplate.

    CLASS-METHODS is_allowed_mime_type
      IMPORTING iv_mime_type     TYPE csequence
      RETURNING VALUE(rv_result) TYPE abap_bool.

    CLASS-METHODS mime_type_of_file
      IMPORTING iv_file_name        TYPE csequence
      RETURNING VALUE(rv_mime_type) TYPE string.
ENDCLASS.

CLASS lhc_template IMPLEMENTATION.

  METHOD get_global_authorizations.
    "Không có authorization object riêng: quyền truy cập được kiểm soát ở mức
    "IAM app / business catalog của service ZUI_ADS_TEMPLATE_O4
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-Edit = if_abap_behv=>mk-on.
      result-%action-Edit = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD precheck_create.
    "Khoá nhập tay: báo trùng ngay khi tạo, không đợi đến lúc Activate
    IF entities IS INITIAL.
      RETURN.
    ENDIF.

    SELECT template_id FROM zads_a_template
      FOR ALL ENTRIES IN @entities
      WHERE template_id = @entities-TemplateId
      INTO TABLE @DATA(lt_active).

    SELECT templateid FROM zads_d_template
      FOR ALL ENTRIES IN @entities
      WHERE templateid = @entities-TemplateId
      INTO TABLE @DATA(lt_draft).

    LOOP AT entities INTO DATA(ls_entity).
      IF line_exists( lt_active[ template_id = ls_entity-TemplateId ] )
      OR line_exists( lt_draft[ templateid = ls_entity-TemplateId ] ).
        APPEND VALUE #( %cid       = ls_entity-%cid
                        %is_draft  = ls_entity-%is_draft
                        TemplateId = ls_entity-TemplateId ) TO failed-template.
        APPEND VALUE #( %cid                = ls_entity-%cid
                        %is_draft           = ls_entity-%is_draft
                        TemplateId          = ls_entity-TemplateId
                        %element-TemplateId = if_abap_behv=>mk-on
                        %msg                = new_message_with_text(
                                                severity = if_abap_behv_message=>severity-error
                                                text     = |Mã template { ls_entity-TemplateId } đã tồn tại (hoặc đang có bản nháp)| )
                      ) TO reported-template.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD derivemimetype.
    "Trình duyệt có thể gửi .xdp với kiểu rỗng / octet-stream -> suy ra từ đuôi file
    READ ENTITIES OF zr_ads_templatetp IN LOCAL MODE
      ENTITY Template
        FIELDS ( FileName MimeType ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_templates).

    DATA lt_update TYPE TABLE FOR UPDATE zr_ads_templatetp\\Template.
    LOOP AT lt_templates INTO DATA(ls_template).
      DATA(lv_mime_type) = mime_type_of_file( ls_template-FileName ).
      IF lv_mime_type IS NOT INITIAL
     AND ( ls_template-MimeType IS INITIAL OR to_lower( ls_template-MimeType ) = `application/octet-stream` ).
        APPEND VALUE #( %tky = ls_template-%tky MimeType = lv_mime_type ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zr_ads_templatetp IN LOCAL MODE
        ENTITY Template
          UPDATE FIELDS ( MimeType ) WITH lt_update.
    ENDIF.
  ENDMETHOD.

  METHOD setversion.
    "Mỗi lần tạo mới / thay file -> tăng phiên bản (đếm riêng ở từng tenant/client,
    "dữ liệu template không đi theo transport)
    READ ENTITIES OF zr_ads_templatetp IN LOCAL MODE
      ENTITY Template
        FIELDS ( TemplateVersion ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_templates).

    MODIFY ENTITIES OF zr_ads_templatetp IN LOCAL MODE
      ENTITY Template
        UPDATE FIELDS ( TemplateVersion )
        WITH VALUE #( FOR ls_template IN lt_templates
                      ( %tky            = ls_template-%tky
                        TemplateVersion = ls_template-TemplateVersion + 1 ) ).
  ENDMETHOD.

  METHOD validatetemplate.
    READ ENTITIES OF zr_ads_templatetp IN LOCAL MODE
      ENTITY Template
        FIELDS ( TemplateId FileContent MimeType ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_templates).

    LOOP AT lt_templates INTO DATA(ls_template).
      APPEND VALUE #( %tky        = ls_template-%tky
                      %state_area = c_state_area ) TO reported-template.

      "Mã template: chữ hoa, số, gạch dưới - tránh lệch hoa/thường khi tra cứu
      IF NOT matches( val = CONV string( ls_template-TemplateId ) pcre = `[A-Z0-9_]+` ).
        APPEND VALUE #( %tky = ls_template-%tky ) TO failed-template.
        APPEND VALUE #( %tky                = ls_template-%tky
                        %state_area         = c_state_area
                        %element-TemplateId = if_abap_behv=>mk-on
                        %msg                = new_message_with_text(
                                                severity = if_abap_behv_message=>severity-error
                                                text     = |Mã template '{ ls_template-TemplateId }' chỉ gồm A-Z, 0-9, _ (chữ hoa)| )
                      ) TO reported-template.
      ENDIF.

      IF ls_template-FileContent IS INITIAL.
        APPEND VALUE #( %tky = ls_template-%tky ) TO failed-template.
        APPEND VALUE #( %tky                 = ls_template-%tky
                        %state_area          = c_state_area
                        %element-FileContent = if_abap_behv=>mk-on
                        %msg                 = new_message_with_text(
                                                 severity = if_abap_behv_message=>severity-error
                                                 text     = `Chưa upload file template` )
                      ) TO reported-template.
      ELSEIF is_allowed_mime_type( ls_template-MimeType ) = abap_false.
        APPEND VALUE #( %tky = ls_template-%tky ) TO failed-template.
        APPEND VALUE #( %tky              = ls_template-%tky
                        %state_area       = c_state_area
                        %element-MimeType = if_abap_behv=>mk-on
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = |Kiểu file '{ ls_template-MimeType }' không được hỗ trợ (XDP, PNG, JPEG, BMP)| )
                      ) TO reported-template.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD is_allowed_mime_type.
    DATA(lv_mime_type) = to_lower( iv_mime_type ).
    rv_result = xsdbool( lv_mime_type = `application/vnd.adobe.xdp+xml`
                      OR lv_mime_type = `application/vnd.xdp`
                      OR lv_mime_type = `application/xml`
                      OR lv_mime_type = `text/xml`
                      OR lv_mime_type = `image/png`
                      OR lv_mime_type = `image/jpeg`
                      OR lv_mime_type = `image/bmp` ).
  ENDMETHOD.

  METHOD mime_type_of_file.
    DATA(lv_file_name) = to_lower( iv_file_name ).
    rv_mime_type = COND #( WHEN lv_file_name CP `*.xdp`  THEN `application/vnd.adobe.xdp+xml`
                           WHEN lv_file_name CP `*.png`  THEN `image/png`
                           WHEN lv_file_name CP `*.jpg` OR lv_file_name CP `*.jpeg` THEN `image/jpeg`
                           WHEN lv_file_name CP `*.bmp`  THEN `image/bmp` ).
  ENDMETHOD.

ENDCLASS.