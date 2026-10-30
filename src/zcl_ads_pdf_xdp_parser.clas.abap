*=====================================================================
* Tên/Mã     : ZCL_ADS_PDF_XDP_PARSER
* Mô tả chung: Đọc cây field có binding từ template XDP (LiveCycle) và sinh
*              XML dữ liệu từ cấu trúc ABAP theo tên field (normal binding):
*              - chỉ đọc trong <template>, subform không tên là "trong suốt"
*              - subform/field có <bind match="none"> không tạo dữ liệu
*              - field bind dataRef/global: không sinh theo tên, liệt kê ở
*                get_explicit_bindings( ) để bên gọi tự xử lý
*              - bảng nội bộ -> lặp phần tử (subform có occur)
*              - d -> YYYY-MM-DD, t -> HH:MM:SS, số -> RAW, abap_bool -> 1/0,
*                x -> hex, xstring -> base64 (image), ALPHA -> bỏ số 0 đầu
* Hạn chế    : số tiền CURR xuất theo giá trị nội bộ - dịch thập phân theo
*              tiền tệ trước (CDS decimal_shift / ZCL_ADS_PDF_XML=>ADD_AMOUNT);
*              hai subform anh em cùng tên (không lặp) dùng chung một nút dữ liệu
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_ADS_PDF
*=====================================================================
* Version   Ngày          Người sửa                Transport      Mô tả
*=====================================================================
* 1.0       30/10/2026    CB9980000013 - CuongUS   AK3K908751     Tạo mới (thay ZCL_XDP_PARSER)
*=====================================================================
CLASS zcl_ads_pdf_xdp_parser DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_alias,
        xdp_name  TYPE string,
        abap_name TYPE string,
      END OF ty_alias,
      "! XDP field/subform name -> ABAP component name (default: same name, upper case)
      tt_alias TYPE SORTED TABLE OF ty_alias WITH UNIQUE KEY xdp_name.

    TYPES:
      BEGIN OF ty_binding,
        path  TYPE string,
        match TYPE string,
        ref   TYPE string,
      END OF ty_binding,
      tt_binding TYPE STANDARD TABLE OF ty_binding WITH EMPTY KEY.

    "! Parse the XDP once; the instance can build XML for many data records
    CLASS-METHODS create
      IMPORTING iv_xdp           TYPE xstring
      RETURNING VALUE(ro_parser) TYPE REF TO zcl_ads_pdf_xdp_parser
      RAISING   zcx_ads_pdf.

    "! Field paths bound by name, e.g. form1/Header/Date
    METHODS get_field_paths
      RETURNING VALUE(rt_path) TYPE string_table.

    "! Fields with explicit binding (dataRef / global) - not filled by BUILD_XML
    METHODS get_explicit_bindings
      RETURNING VALUE(rt_binding) TYPE tt_binding.

    "! XML data (UTF-8) for the template, values taken from IS_DATA
    "! (IS_DATA corresponds to the top subform of the template)
    METHODS build_xml
      IMPORTING is_data       TYPE any
                it_alias      TYPE tt_alias OPTIONAL
      RETURNING VALUE(rv_xml) TYPE xstring
      RAISING   zcx_ads_pdf.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_node,
        id     TYPE i,
        parent TYPE i,
        name   TYPE string,
      END OF ty_node,
      "! Key parent + id: siblings come back in XDP order (id = insert order)
      tt_node TYPE STANDARD TABLE OF ty_node WITH EMPTY KEY
                   WITH UNIQUE SORTED KEY by_parent COMPONENTS parent id.

    DATA mt_node     TYPE tt_node.
    DATA mt_path     TYPE string_table.
    DATA mt_explicit TYPE tt_binding.

    METHODS parse
      IMPORTING iv_xdp TYPE xstring
      RAISING   zcx_ads_pdf.

    METHODS add_path
      IMPORTING it_segment TYPE string_table.

    METHODS write_children
      IMPORTING io_writer TYPE REF TO if_sxml_writer
                iv_parent TYPE i
                is_data   TYPE any
                it_alias  TYPE tt_alias
      RAISING   cx_sxml_name_error cx_sxml_state_error.

    METHODS write_element
      IMPORTING io_writer TYPE REF TO if_sxml_writer
                is_node   TYPE ty_node
                is_data   TYPE any
                it_alias  TYPE tt_alias
      RAISING   cx_sxml_name_error cx_sxml_state_error.

    CLASS-METHODS to_xfa_text
      IMPORTING iv_value       TYPE any
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.



CLASS zcl_ads_pdf_xdp_parser IMPLEMENTATION.

  METHOD create.
    ro_parser = NEW #( ).
    ro_parser->parse( iv_xdp ).
  ENDMETHOD.

  METHOD get_field_paths.
    rt_path = mt_path.
  ENDMETHOD.

  METHOD get_explicit_bindings.
    rt_binding = mt_explicit.
  ENDMETHOD.

  METHOD parse.
    TYPES:
      BEGIN OF ty_segment,
        no   TYPE i,
        name TYPE string,
      END OF ty_segment,
      tt_segment TYPE STANDARD TABLE OF ty_segment WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_frame,
        tag         TYPE string,
        segment_no  TYPE i,
        field_index TYPE i,
      END OF ty_frame.
    TYPES:
      BEGIN OF ty_field,
        segments TYPE tt_segment,
        unbound  TYPE abap_bool,
        match    TYPE string,
        ref      TYPE string,
      END OF ty_field.

    DATA lt_frame       TYPE STANDARD TABLE OF ty_frame WITH EMPTY KEY.
    DATA lt_field       TYPE STANDARD TABLE OF ty_field WITH EMPTY KEY.
    DATA lt_segment     TYPE tt_segment.
    DATA lt_transparent TYPE SORTED TABLE OF i WITH UNIQUE KEY table_line.
    DATA lv_segment_no  TYPE i.
    DATA lv_in_template TYPE abap_bool.
    DATA lv_template    TYPE abap_bool.
    DATA lv_attr_name   TYPE string.
    DATA lv_attr_match  TYPE string.
    DATA lv_attr_ref    TYPE string.

    DATA(lo_reader) = cl_sxml_string_reader=>create( iv_xdp ).

    TRY.
        DO.
          lo_reader->next_node( ).

          CASE lo_reader->node_type.
            WHEN if_sxml_node=>co_nt_final.
              EXIT.

            WHEN if_sxml_node=>co_nt_element_open.
              DATA(ls_frame) = VALUE ty_frame( tag = lo_reader->name ).
              DATA(ls_parent) = VALUE ty_frame( ).
              IF lt_frame IS NOT INITIAL.
                ls_parent = lt_frame[ lines( lt_frame ) ].
              ENDIF.

              CLEAR: lv_attr_name, lv_attr_match, lv_attr_ref.
              DO.
                lo_reader->next_attribute( ).
                IF lo_reader->node_type <> if_sxml_node=>co_nt_attribute.
                  EXIT.
                ENDIF.
                CASE lo_reader->name.
                  WHEN `name`.
                    lv_attr_name = lo_reader->value.
                  WHEN `match`.
                    lv_attr_match = lo_reader->value.
                  WHEN `ref`.
                    lv_attr_ref = lo_reader->value.
                ENDCASE.
              ENDDO.

              IF ls_frame-tag = `template` AND lv_in_template = abap_false.
                lv_in_template = abap_true.
                lv_template    = abap_true.
              ELSEIF lv_in_template = abap_true.
                CASE ls_frame-tag.
                  WHEN `subform` OR `exclGroup` OR `field`.
                    "Field con của exclGroup (radio) bind vào chính exclGroup
                    IF lv_attr_name IS NOT INITIAL AND ls_parent-tag <> `exclGroup`.
                      lv_segment_no += 1.
                      APPEND VALUE #( no = lv_segment_no name = lv_attr_name ) TO lt_segment.
                      ls_frame-segment_no = lv_segment_no.
                      IF ls_frame-tag <> `subform`.
                        APPEND VALUE #( segments = lt_segment ) TO lt_field.
                        ls_frame-field_index = lines( lt_field ).
                      ENDIF.
                    ENDIF.
                  WHEN `bind`.
                    IF ls_parent-field_index > 0.
                      CASE lv_attr_match.
                        WHEN `none`.
                          lt_field[ ls_parent-field_index ]-unbound = abap_true.
                        WHEN `dataRef` OR `global`.
                          lt_field[ ls_parent-field_index ]-match = lv_attr_match.
                          lt_field[ ls_parent-field_index ]-ref   = lv_attr_ref.
                      ENDCASE.
                    ELSEIF ls_parent-segment_no > 0 AND lv_attr_match = `none`.
                      "Subform không bind dữ liệu -> không tạo cấp trong XML
                      INSERT ls_parent-segment_no INTO TABLE lt_transparent.
                    ENDIF.
                ENDCASE.
              ENDIF.

              APPEND ls_frame TO lt_frame.

            WHEN if_sxml_node=>co_nt_element_close.
              IF lt_frame IS INITIAL.
                CONTINUE.
              ENDIF.
              ls_frame = lt_frame[ lines( lt_frame ) ].
              DELETE lt_frame INDEX lines( lt_frame ).
              IF ls_frame-segment_no > 0.
                DELETE lt_segment INDEX lines( lt_segment ).
              ENDIF.
              IF ls_frame-tag = `template`.
                lv_in_template = abap_false.
              ENDIF.
          ENDCASE.
        ENDDO.
      CATCH cx_sxml_parse_error cx_sxml_state_error INTO DATA(lx_sxml).
        RAISE EXCEPTION NEW zcx_ads_pdf( previous = lx_sxml
                                         iv_text  = |XDP không hợp lệ: { lx_sxml->get_text( ) }| ).
    ENDTRY.

    IF lv_template = abap_false.
      RAISE EXCEPTION NEW zcx_ads_pdf( iv_text = `XDP không có phần <template>` ).
    ENDIF.

    LOOP AT lt_field INTO DATA(ls_field) WHERE unbound = abap_false.
      DATA(lt_name) = VALUE string_table( ).
      LOOP AT ls_field-segments INTO DATA(ls_segment).
        IF NOT line_exists( lt_transparent[ table_line = ls_segment-no ] ).
          APPEND ls_segment-name TO lt_name.
        ENDIF.
      ENDLOOP.

      DATA(lv_path) = concat_lines_of( table = lt_name sep = `/` ).
      IF ls_field-match IS NOT INITIAL.
        APPEND VALUE #( path = lv_path match = ls_field-match ref = ls_field-ref ) TO mt_explicit.
        CONTINUE.
      ENDIF.
      add_path( lt_name ).
      APPEND lv_path TO mt_path.
    ENDLOOP.

    DATA(lv_roots) = REDUCE i( INIT n = 0
                               FOR ls_root IN mt_node USING KEY by_parent WHERE ( parent = 0 )
                               NEXT n = n + 1 ).
    IF lv_roots > 1.
      RAISE EXCEPTION NEW zcx_ads_pdf(
        iv_text = |Template có { lv_roots } nút gốc dữ liệu - đặt tên cho subform gốc trong LiveCycle| ).
    ENDIF.
  ENDMETHOD.

  METHOD add_path.
    DATA lv_parent TYPE i.

    LOOP AT it_segment INTO DATA(lv_segment).
      DATA(lv_found) = 0.
      LOOP AT mt_node INTO DATA(ls_node) USING KEY by_parent
           WHERE parent = lv_parent AND name = lv_segment.
        lv_found = ls_node-id.
        EXIT.
      ENDLOOP.
      IF lv_found = 0.
        lv_found = lines( mt_node ) + 1.
        INSERT VALUE #( id = lv_found parent = lv_parent name = lv_segment ) INTO TABLE mt_node.
      ENDIF.
      lv_parent = lv_found.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_xml.
    DATA(lo_output) = cl_sxml_string_writer=>create( ).
    DATA(lo_writer) = CAST if_sxml_writer( lo_output ).

    TRY.
        "Subform gốc của template tương ứng với chính IS_DATA
        LOOP AT mt_node INTO DATA(ls_root) USING KEY by_parent WHERE parent = 0.
          lo_writer->open_element( name = ls_root-name ).
          write_children( io_writer = lo_writer iv_parent = ls_root-id is_data = is_data it_alias = it_alias ).
          lo_writer->close_element( ).
        ENDLOOP.
      CATCH cx_sxml_name_error cx_sxml_state_error INTO DATA(lx_sxml).
        RAISE EXCEPTION NEW zcx_ads_pdf( previous = lx_sxml
                                         iv_text  = |Sinh XML lỗi: { lx_sxml->get_text( ) }| ).
    ENDTRY.

    rv_xml = lo_output->get_output( ).
  ENDMETHOD.

  METHOD write_children.
    FIELD-SYMBOLS <lt_rows> TYPE ANY TABLE.

    IF cl_abap_typedescr=>describe_by_data( is_data )->kind <> cl_abap_typedescr=>kind_struct.
      RETURN.
    ENDIF.

    LOOP AT mt_node INTO DATA(ls_node) USING KEY by_parent WHERE parent = iv_parent.
      DATA(lv_component) = VALUE #( it_alias[ xdp_name = ls_node-name ]-abap_name DEFAULT ls_node-name ).
      ASSIGN COMPONENT to_upper( lv_component ) OF STRUCTURE is_data TO FIELD-SYMBOL(<lv_component>).
      IF sy-subrc <> 0.
        CONTINUE.     "không có dữ liệu -> field để trống trên form
      ENDIF.

      IF cl_abap_typedescr=>describe_by_data( <lv_component> )->kind = cl_abap_typedescr=>kind_table.
        ASSIGN <lv_component> TO <lt_rows>.
        LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
          write_element( io_writer = io_writer is_node = ls_node is_data = <ls_row> it_alias = it_alias ).
        ENDLOOP.
      ELSE.
        write_element( io_writer = io_writer is_node = ls_node is_data = <lv_component> it_alias = it_alias ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD write_element.
    io_writer->open_element( name = is_node-name ).

    CASE cl_abap_typedescr=>describe_by_data( is_data )->kind.
      WHEN cl_abap_typedescr=>kind_struct.
        write_children( io_writer = io_writer iv_parent = is_node-id is_data = is_data it_alias = it_alias ).
      WHEN cl_abap_typedescr=>kind_elem.
        DATA(lv_text) = to_xfa_text( is_data ).
        IF lv_text IS NOT INITIAL.
          io_writer->write_value( lv_text ).
        ENDIF.
    ENDCASE.

    io_writer->close_element( ).
  ENDMETHOD.

  METHOD to_xfa_text.
    DATA(lo_type) = cl_abap_typedescr=>describe_by_data( iv_value ).

    "Checkbox XFA mặc định: on = 1, off = 0
    DATA(lv_type_name) = lo_type->get_relative_name( ).
    IF lv_type_name = `ABAP_BOOL` OR lv_type_name = `ABAP_BOOLEAN`.
      rv_text = COND #( WHEN iv_value IS INITIAL THEN `0` ELSE `1` ).
      RETURN.
    ENDIF.

    CASE lo_type->type_kind.
      WHEN cl_abap_typedescr=>typekind_date.
        DATA(lv_date) = CONV d( iv_value ).
        IF lv_date IS NOT INITIAL.
          rv_text = |{ lv_date+0(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }|.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_time.
        DATA(lv_time) = CONV t( iv_value ).
        IF lv_time IS NOT INITIAL.
          rv_text = |{ lv_time+0(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }|.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_int  OR cl_abap_typedescr=>typekind_int1
        OR cl_abap_typedescr=>typekind_int2 OR cl_abap_typedescr=>typekind_int8
        OR cl_abap_typedescr=>typekind_packed OR cl_abap_typedescr=>typekind_decfloat
        OR cl_abap_typedescr=>typekind_decfloat16 OR cl_abap_typedescr=>typekind_decfloat34.
        DATA(lv_number) = CONV decfloat34( iv_value ).
        rv_text = |{ lv_number NUMBER = RAW }|.
      WHEN cl_abap_typedescr=>typekind_float.
        "decfloat16: bỏ phần nhiễu nhị phân (0.1 -> 0.1, không phải 0.1000000000000000055)
        DATA(lv_float) = CONV decfloat16( iv_value ).
        rv_text = |{ lv_float NUMBER = RAW }|.
      WHEN cl_abap_typedescr=>typekind_hex.
        rv_text = |{ CONV xstring( iv_value ) }|.
      WHEN cl_abap_typedescr=>typekind_xstring.
        "Ảnh nhúng (image field) -> base64
        rv_text = cl_web_http_utility=>encode_x_base64( CONV xstring( iv_value ) ).
      WHEN cl_abap_typedescr=>typekind_utclong.
        DATA(lv_utc) = CONV utclong( iv_value ).
        rv_text = |{ lv_utc TIMESTAMP = ISO }|.
      WHEN OTHERS.
        IF CAST cl_abap_elemdescr( lo_type )->edit_mask = `==ALPHA`.
          rv_text = |{ iv_value ALPHA = OUT }|.
        ELSE.
          rv_text = CONV string( iv_value ).
        ENDIF.
    ENDCASE.

    "Ký tự điều khiển (trừ TAB, LF, CR) không hợp lệ trong XML 1.0
    rv_text = replace( val = rv_text pcre = `[\x00-\x08\x0B\x0C\x0E-\x1F]` with = `` occ = 0 ).
  ENDMETHOD.

ENDCLASS.