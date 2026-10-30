*=====================================================================
* Tên/Mã     : ZCL_ADS_DEMO_CE_QUERY
* Mô tả chung: Query provider cho 2 custom entity demo ZI_ADS_DEMO_ORDER_CE /
*              ZI_ADS_DEMO_ORDERLINE_CE: trả dữ liệu GIẢ LẬP, áp filter (FDP
*              lọc dòng con theo khoá cha), paging, sort, đếm tổng.
*              Minh hoạ FDP (ZCL_ADS_PDF_FDP) đọc được dữ liệu từ class query.
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_ADS_PDF
*=====================================================================
* Version   Ngày          Người sửa                Transport      Mô tả
*=====================================================================
* 1.0       30/10/2026    CB9980000013 - CuongUS   AK3K908751     Tạo mới
*=====================================================================
CLASS zcl_ads_demo_ce_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES tt_order TYPE STANDARD TABLE OF zi_ads_demo_order_ce WITH EMPTY KEY.
    TYPES tt_line  TYPE STANDARD TABLE OF zi_ads_demo_orderline_ce WITH EMPTY KEY.

    CLASS-METHODS mock_orders
      RETURNING VALUE(rt_order) TYPE tt_order.

    CLASS-METHODS mock_lines
      RETURNING VALUE(rt_line) TYPE tt_line.

    "! Áp filter / sort / paging của request lên bảng dữ liệu rồi trả về response
    CLASS-METHODS respond
      IMPORTING io_request  TYPE REF TO if_rap_query_request
                io_response TYPE REF TO if_rap_query_response
      CHANGING  ct_data     TYPE STANDARD TABLE
      RAISING   cx_rap_query_provider.
ENDCLASS.



CLASS zcl_ads_demo_ce_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    CASE io_request->get_entity_id( ).
      WHEN 'ZI_ADS_DEMO_ORDER_CE'.
        DATA(lt_order) = mock_orders( ).
        respond( EXPORTING io_request = io_request io_response = io_response CHANGING ct_data = lt_order ).
      WHEN 'ZI_ADS_DEMO_ORDERLINE_CE'.
        DATA(lt_line) = mock_lines( ).
        respond( EXPORTING io_request = io_request io_response = io_response CHANGING ct_data = lt_line ).
    ENDCASE.
  ENDMETHOD.

  METHOD respond.
    "Filter: FDP đọc dòng con bằng filter OrderNo = <khoá cha>
    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filter.      "filter không đổi được sang range -> trả hết
    ENDTRY.

    LOOP AT lt_filter INTO DATA(ls_filter).
      DATA(lt_range) = ls_filter-range.
      LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<ls_row>).
        DATA(lv_index) = sy-tabix.
        ASSIGN COMPONENT ls_filter-name OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_value>).
        IF sy-subrc = 0 AND <lv_value> NOT IN lt_range.
          DELETE ct_data INDEX lv_index.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    "Sort: framework yêu cầu đọc thông tin sort/paging dù dữ liệu nhỏ
    DATA(lt_sort) = io_request->get_sort_elements( ).
    LOOP AT lt_sort INTO DATA(ls_sort).
      SORT ct_data BY (ls_sort-element_name) ASCENDING.
      IF ls_sort-descending = abap_true.
        SORT ct_data BY (ls_sort-element_name) DESCENDING.
      ENDIF.
    ENDLOOP.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( ct_data ) ).
    ENDIF.

    IF io_request->is_data_requested( ).
      DATA(lo_paging) = io_request->get_paging( ).
      DATA(lv_offset) = lo_paging->get_offset( ).
      DATA(lv_size)   = lo_paging->get_page_size( ).
      IF lv_offset > 0.
        DELETE ct_data TO lv_offset.
      ENDIF.
      IF lv_size <> if_rap_query_paging=>page_size_unlimited AND lines( ct_data ) > lv_size.
        DELETE ct_data FROM lv_size + 1.
      ENDIF.
      io_response->set_data( ct_data ).
    ENDIF.
  ENDMETHOD.

  METHOD mock_orders.
    rt_order = VALUE #(
      ( OrderNo = 'DH0001' OrderDate = '20261030' Customer = 'Công ty TNHH XYZ (DEMO)'
        QrContent = 'https://example.com/order/DH0001' TotalAmount = 2350000 )
      ( OrderNo = 'DH0002' OrderDate = '20261031' Customer = 'Cửa hàng ABC (DEMO)'
        QrContent = 'https://example.com/order/DH0002' TotalAmount = 900000 ) ).
  ENDMETHOD.

  METHOD mock_lines.
    rt_line = VALUE #(
      ( OrderNo = 'DH0001' ItemNo = 10 Product = 'Bàn làm việc'  Quantity = 2 Amount = 1000000 )
      ( OrderNo = 'DH0001' ItemNo = 20 Product = 'Ghế xoay'      Quantity = 3 Amount = 1200000 )
      ( OrderNo = 'DH0001' ItemNo = 30 Product = 'Phí giao hàng' Quantity = 1 Amount = 150000 )
      ( OrderNo = 'DH0002' ItemNo = 10 Product = 'Kệ sách'       Quantity = 1 Amount = 900000 ) ).
  ENDMETHOD.

ENDCLASS.