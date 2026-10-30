*=====================================================================
* Tên/Mã     : ZCL_DEMO_ADS_PNK_QUERY
* Mô tả chung: Query provider cho ZR_DEMO_ADS_PNK (phiếu nhập kho) và
*              ZI_DEMO_ADS_PNKITEM (dòng hàng): dữ liệu GIẢ LẬP, áp filter,
*              sort, paging, đếm tổng. Dùng cho app Fiori và cho FDP
*              (ZCL_ADS_PDF_FDP đọc dữ liệu in qua chính class này).
*              Người ký (giao hàng, quản lý kho, thủ kho, kế toán): nhập ở
*              filter bar thì ghi đè giá trị trên mọi dòng, không dùng để lọc.
* Tác giả    : CB9980000013 - CuongUS
* Ngày tạo   : 30/10/2026
* Package    : ZPK_DEMO_2
*=====================================================================
CLASS zcl_demo_ads_pnk_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

    TYPES:
      BEGIN OF ty_signer,
        shipper           TYPE c LENGTH 60,
        warehouse_manager TYPE c LENGTH 60,
        store_keeper      TYPE c LENGTH 60,
        accountant        TYPE c LENGTH 60,
      END OF ty_signer.

    TYPES tt_header TYPE STANDARD TABLE OF zr_demo_ads_pnk WITH EMPTY KEY.
    TYPES tt_item   TYPE STANDARD TABLE OF zi_demo_ads_pnkitem WITH EMPTY KEY.

    "! Người ký dùng khi in: FDP gọi lại query trong cùng phiên nên class in
    "! đặt giá trị ở đây trước khi đọc XML (trống = giữ giá trị giả lập)
    CLASS-METHODS set_signer
      IMPORTING is_signer TYPE ty_signer.

    CLASS-METHODS mock_headers
      RETURNING VALUE(rt_header) TYPE tt_header.

    CLASS-METHODS mock_items
      RETURNING VALUE(rt_item) TYPE tt_item.

    "! Đọc số tiền bằng chữ tiếng Việt, vd 1.650.000 -> Một triệu sáu trăm năm mươi nghìn đồng
    CLASS-METHODS amount_in_words_vn
      IMPORTING iv_amount       TYPE decfloat34
      RETURNING VALUE(rv_words) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA gs_signer TYPE ty_signer.

    CONSTANTS:
      BEGIN OF c_signer_field,
        shipper           TYPE string VALUE `SHIPPER`,
        warehouse_manager TYPE string VALUE `WAREHOUSEMANAGER`,
        store_keeper      TYPE string VALUE `STOREKEEPER`,
        accountant        TYPE string VALUE `ACCOUNTANT`,
      END OF c_signer_field.

    "! Áp filter / sort / paging của request lên bảng dữ liệu rồi trả về response
    CLASS-METHODS respond
      IMPORTING io_request  TYPE REF TO if_rap_query_request
                io_response TYPE REF TO if_rap_query_response
                it_filter   TYPE if_rap_query_filter=>tt_name_range_pairs
      CHANGING  ct_data     TYPE STANDARD TABLE
      RAISING   cx_rap_query_provider.

    CLASS-METHODS apply_signer
      IMPORTING it_filter TYPE if_rap_query_filter=>tt_name_range_pairs
      CHANGING  ct_header TYPE tt_header.

    CLASS-METHODS set_merge_info
      CHANGING ct_item TYPE tt_item.

    CLASS-METHODS read_triple
      IMPORTING iv_number       TYPE i
                iv_full         TYPE abap_bool
      RETURNING VALUE(rv_words) TYPE string.
ENDCLASS.



CLASS zcl_demo_ads_pnk_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filter.      "filter không đổi được sang range -> trả hết
    ENDTRY.

    CASE io_request->get_entity_id( ).
      WHEN 'ZR_DEMO_ADS_PNK'.
        DATA(lt_header) = mock_headers( ).
        apply_signer( EXPORTING it_filter = lt_filter CHANGING ct_header = lt_header ).
        "Người ký không phải tiêu chí lọc
        DELETE lt_filter WHERE name = c_signer_field-shipper
                            OR name = c_signer_field-warehouse_manager
                            OR name = c_signer_field-store_keeper
                            OR name = c_signer_field-accountant.
        respond( EXPORTING io_request  = io_request
                           io_response = io_response
                           it_filter   = lt_filter
                 CHANGING  ct_data     = lt_header ).
      WHEN 'ZI_DEMO_ADS_PNKITEM'.
        DATA(lt_item) = mock_items( ).
        respond( EXPORTING io_request  = io_request
                           io_response = io_response
                           it_filter   = lt_filter
                 CHANGING  ct_data     = lt_item ).
    ENDCASE.
  ENDMETHOD.

  METHOD set_signer.
    gs_signer = is_signer.
  ENDMETHOD.

  METHOD apply_signer.
    DATA(ls_signer) = gs_signer.

    "Giá trị nhập ở filter bar (EQ) được ưu tiên hơn giá trị đặt khi in
    LOOP AT it_filter INTO DATA(ls_filter).
      DATA(lv_value) = VALUE #( ls_filter-range[ 1 ]-low OPTIONAL ).
      IF lv_value IS INITIAL.
        CONTINUE.
      ENDIF.
      CASE ls_filter-name.
        WHEN c_signer_field-shipper.
          ls_signer-shipper = lv_value.
        WHEN c_signer_field-warehouse_manager.
          ls_signer-warehouse_manager = lv_value.
        WHEN c_signer_field-store_keeper.
          ls_signer-store_keeper = lv_value.
        WHEN c_signer_field-accountant.
          ls_signer-accountant = lv_value.
      ENDCASE.
    ENDLOOP.

    LOOP AT ct_header ASSIGNING FIELD-SYMBOL(<ls_header>).
      IF ls_signer-shipper IS NOT INITIAL.
        <ls_header>-shipper = ls_signer-shipper.
      ENDIF.
      IF ls_signer-warehouse_manager IS NOT INITIAL.
        <ls_header>-warehousemanager = ls_signer-warehouse_manager.
      ENDIF.
      IF ls_signer-store_keeper IS NOT INITIAL.
        <ls_header>-storekeeper = ls_signer-store_keeper.
      ENDIF.
      IF ls_signer-accountant IS NOT INITIAL.
        <ls_header>-accountant = ls_signer-accountant.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD respond.
    "Filter: list report lọc theo filter bar; FDP / object page đọc dòng con theo khoá cha
    LOOP AT it_filter INTO DATA(ls_filter).
      DATA(lt_range) = ls_filter-range.
      LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<ls_row>).
        DATA(lv_index) = sy-tabix.
        ASSIGN COMPONENT ls_filter-name OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_value>).
        IF sy-subrc = 0 AND <lv_value> NOT IN lt_range.
          DELETE ct_data INDEX lv_index.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    LOOP AT io_request->get_sort_elements( ) INTO DATA(ls_sort).
      IF ls_sort-descending = abap_true.
        SORT ct_data BY (ls_sort-element_name) DESCENDING.
      ELSE.
        SORT ct_data BY (ls_sort-element_name) ASCENDING.
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

  METHOD mock_headers.
    rt_header = VALUE #( fiscalyear       = '2026'
                         shipper          = 'Nguyễn Văn Giao'
                         warehousemanager = 'Trần Thị Quản'
                         storekeeper      = 'Lê Văn Kho'
                         accountant       = 'Phạm Thị Toán'
      ( docno = '5000000101' postingdate = '20261026' purchaseorder = '4500001201'
        supplier = 'Công ty TNHH Vật liệu Mẫu A' storagelocation = 'Kho nguyên liệu 1'
        headertext = 'Nhập đá tấm theo đơn mua tháng 10' )
      ( docno = '5000000102' postingdate = '20261027' purchaseorder = '4500001202'
        supplier = 'Công ty CP Khoáng sản Mẫu B' storagelocation = 'Kho nguyên liệu 2'
        headertext = 'Nhập bột khoáng & phụ gia' )
      ( docno = '5000000103' postingdate = '20261028' purchaseorder = '4500001203'
        supplier = 'Công ty TNHH Hoá chất Mẫu C' storagelocation = 'Kho hoá chất'
        headertext = 'Nhập nhựa resin <lô 2>' )
      ( docno = '5000000104' postingdate = '20261029' purchaseorder = '4500001204'
        supplier = 'Công ty TNHH Bao bì Mẫu D' storagelocation = 'Kho bao bì'
        headertext = 'Nhập pallet và màng co' )
      ( docno = '5000000105' postingdate = '20261030' purchaseorder = '4500001205'
        supplier = 'Công ty CP Thiết bị Mẫu E' storagelocation = 'Kho phụ tùng'
        headertext = 'Nhập phụ tùng bảo trì' ) ).

    DATA(lt_item) = mock_items( ).
    LOOP AT rt_header ASSIGNING FIELD-SYMBOL(<ls_header>).
      <ls_header>-totalamount = REDUCE decfloat34( INIT lv_sum = CONV decfloat34( 0 )
                                                   FOR ls_item IN lt_item
                                                   WHERE ( docno = <ls_header>-docno AND fiscalyear = <ls_header>-fiscalyear )
                                                   NEXT lv_sum = lv_sum + ls_item-amount ).
      "SL yêu cầu: mỗi nhóm gộp cộng một lần (dòng đơn / dòng đầu nhóm)
      <ls_header>-totalqtyrequested = REDUCE decfloat34( INIT lv_req = CONV decfloat34( 0 )
                                                         FOR ls_item IN lt_item
                                                         WHERE ( docno = <ls_header>-docno AND fiscalyear = <ls_header>-fiscalyear
                                                             AND ( mergepos(1) = 'S' OR mergepos(1) = 'F' ) )
                                                         NEXT lv_req = lv_req + ls_item-qtyrequested ).
      <ls_header>-totalqtyreceived = REDUCE decfloat34( INIT lv_rec = CONV decfloat34( 0 )
                                                        FOR ls_item IN lt_item
                                                        WHERE ( docno = <ls_header>-docno AND fiscalyear = <ls_header>-fiscalyear )
                                                        NEXT lv_rec = lv_rec + ls_item-qtyreceived ).
      <ls_header>-amountinwords = amount_in_words_vn( CONV #( <ls_header>-totalamount ) ).
      <ls_header>-qrcontent = |PNK:{ <ls_header>-docno }/{ <ls_header>-fiscalyear }|
                           && |;NGAY:{ <ls_header>-postingdate };TIEN:{ <ls_header>-totalamount }|.
    ENDLOOP.
  ENDMETHOD.

  METHOD mock_items.
    "Dòng 1-7 của phiếu 101 giống dữ liệu mẫu ZC_DEMO_ADS_PDF_1
    rt_item = VALUE #( fiscalyear = '2026'
      ( docno = '5000000101' itemno = 1 material = '300006770' materialname = 'C1005-P-J20-1' unit = 'TAM' conversion = '5.445 M2' quality = 'A'
        qtyrequested = 3 qtyreceived = 3 price = 1250000 )
      ( docno = '5000000101' itemno = 2 material = '300006770' materialname = 'C1005-P-J20-1' unit = 'TAM' conversion = '5.445 M2' quality = 'A-'
        qtyrequested = 3 qtyreceived = 2 price = 1100000 )
      ( docno = '5000000101' itemno = 3 material = '300006770' materialname = 'C1005-P-J20-1' unit = 'TAM' conversion = '5.445 M2' quality = 'B'
        qtyrequested = 3 qtyreceived = 3 price = 950000 )
      ( docno = '5000000101' itemno = 4 material = '300006770' materialname = 'C1005-P-J20-1' unit = 'TAM' conversion = '5.445 M2' quality = 'C'
        qtyrequested = 3 qtyreceived = 1 price = 700000 )
      ( docno = '5000000101' itemno = 5 material = '300006771' materialname = 'C2104-P-J13-1' unit = 'TAM' conversion = '5.445 M2' quality = 'A'
        qtyrequested = 3 qtyreceived = 3 price = 1350000 )
      ( docno = '5000000101' itemno = 6 material = '300006771' materialname = 'C2104-P-J13-1' unit = 'TAM' conversion = '5.445 M2' quality = 'A-'
        qtyrequested = 3 qtyreceived = 3 price = 1200000 )
      ( docno = '5000000101' itemno = 7 material = '300006771' materialname = 'C2104-P-J13-1' unit = 'TAM' conversion = '5.445 M2' quality = 'B'
        qtyrequested = 3 qtyreceived = 2 price = 1000000 )
      ( docno = '5000000102' itemno = 1 material = '200001001' materialname = 'Bột thạch anh 0.1-0.3mm'
        unit = 'KG' conversion = '' quality = 'A' qtyrequested = 2000 qtyreceived = 2000 price = 4500 )
      ( docno = '5000000102' itemno = 2 material = '200001002' materialname = 'Bột thạch anh siêu mịn'
        unit = 'KG' conversion = '' quality = 'A' qtyrequested = 1500 qtyreceived = '1480.5' price = 6200 )
      ( docno = '5000000102' itemno = 3 material = '200001010' materialname = 'Phụ gia tạo màu & ổn định'
        unit = 'KG' conversion = '' quality = 'A' qtyrequested = 50 qtyreceived = 50 price = 85000 )
      ( docno = '5000000103' itemno = 1 material = '210000301' materialname = 'Nhựa resin không no'
        unit = 'KG' conversion = '25 KG/thùng' quality = 'A' qtyrequested = 500 qtyreceived = 500 price = 52000 )
      ( docno = '5000000103' itemno = 2 material = '210000302' materialname = 'Chất xúc tác <MEKP>'
        unit = 'KG' conversion = '' quality = 'A' qtyrequested = 20 qtyreceived = 20 price = 120000 )
      ( docno = '5000000104' itemno = 1 material = '400000011' materialname = 'Pallet gỗ 1200x1000'
        unit = 'CAI' conversion = '' quality = 'A' qtyrequested = 100 qtyreceived = 98 price = 185000 )
      ( docno = '5000000104' itemno = 2 material = '400000020' materialname = 'Màng co PE 500mm'
        unit = 'CUO' conversion = '18 KG/cuộn' quality = 'A' qtyrequested = 40 qtyreceived = 40 price = 420000 )
      ( docno = '5000000105' itemno = 1 material = '500000101' materialname = 'Lưỡi cắt kim cương D350'
        unit = 'CAI' conversion = '' quality = 'A' qtyrequested = 10 qtyreceived = 10 price = 2350000 )
      ( docno = '5000000105' itemno = 2 material = '500000105' materialname = 'Vòng bi 6205-2RS'
        unit = 'CAI' conversion = '' quality = 'A' qtyrequested = 24 qtyreceived = 24 price = 95000 )
      ( docno = '5000000105' itemno = 3 material = '500000120' materialname = 'Dầu thuỷ lực ISO VG46'
        unit = 'LIT' conversion = '18 LIT/xô' quality = 'A' qtyrequested = 36 qtyreceived = 36 price = 68000 ) ).

    LOOP AT rt_item ASSIGNING FIELD-SYMBOL(<ls_item>).
      <ls_item>-amount = round( val = CONV decfloat34( <ls_item>-qtyreceived * <ls_item>-price ) dec = 0 ).
    ENDLOOP.

    set_merge_info( CHANGING ct_item = rt_item ).
  ENDMETHOD.

  METHOD set_merge_info.
    "Nhóm = các dòng liền nhau cùng phiếu + mã hàng + SL yêu cầu -> form in gộp ô SL yêu cầu
    DATA(lv_start) = 1.
    DATA(lv_count) = lines( ct_item ).

    WHILE lv_start <= lv_count.
      DATA(ls_first) = ct_item[ lv_start ].
      DATA(lv_end) = lv_start.
      WHILE lv_end < lv_count
        AND ct_item[ lv_end + 1 ]-docno        = ls_first-docno
        AND ct_item[ lv_end + 1 ]-fiscalyear   = ls_first-fiscalyear
        AND ct_item[ lv_end + 1 ]-material     = ls_first-material
        AND ct_item[ lv_end + 1 ]-qtyrequested = ls_first-qtyrequested.
        lv_end += 1.
      ENDWHILE.

      DATA(lv_size) = lv_end - lv_start + 1.
      "Số in ở dòng giữa nhóm; nhóm chẵn: dòng n/2, canh đáy ô cho gần tâm nhóm
      DATA(lv_show) = lv_start + ( lv_size - 1 ) DIV 2.
      DATA(lv_qty)  = CONV decfloat34( ls_first-qtyrequested ).
      DATA(lv_text) = zcl_ads_pdf_xml=>format_amount_vn(
                        iv_amount   = lv_qty
                        iv_decimals = COND #( WHEN frac( lv_qty ) = 0 THEN 0 ELSE 2 ) ).

      DO lv_size TIMES.
        DATA(lv_row) = lv_start + sy-index - 1.
        ASSIGN ct_item[ lv_row ] TO FIELD-SYMBOL(<ls_row>).
        <ls_row>-mergepos = COND #( WHEN lv_size = 1        THEN 'S'
                                    WHEN lv_row = lv_start  THEN 'F'
                                    WHEN lv_row = lv_end    THEN 'L'
                                    ELSE 'M' ).
        IF lv_row = lv_show.
          <ls_row>-qtyrequestedtext = lv_text.
          IF lv_size MOD 2 = 0.
            <ls_row>-mergepos+1(1) = 'B'.
          ENDIF.
        ENDIF.
      ENDDO.

      lv_start = lv_end + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD amount_in_words_vn.
    CONSTANTS lc_billion TYPE decfloat34 VALUE 1000000000.
    DATA lt_part TYPE string_table.

    DATA(lv_amount) = abs( round( val = iv_amount dec = 0 ) ).
    IF lv_amount = 0.
      rv_words = `Không đồng`.
      RETURN.
    ENDIF.

    "Tách nhóm tỷ (đệ quy cho số >= 1.000 tỷ), sau đó triệu - nghìn - đơn vị
    DATA(lv_billion) = trunc( lv_amount / lc_billion ).
    DATA(lv_rest)    = CONV i( lv_amount - lv_billion * lc_billion ).

    IF lv_billion > 0.
      DATA(lv_billion_words) = amount_in_words_vn( lv_billion ).
      "bỏ chữ ' đồng' ở cuối kết quả đệ quy, viết thường chữ đầu
      lv_billion_words = substring( val = lv_billion_words len = strlen( lv_billion_words ) - 5 ).
      APPEND |{ to_lower( lv_billion_words ) } tỷ| TO lt_part.
    ENDIF.

    DATA(lv_million)  = lv_rest DIV 1000000.
    DATA(lv_thousand) = ( lv_rest MOD 1000000 ) DIV 1000.
    DATA(lv_unit)     = lv_rest MOD 1000.

    "Nhóm đứng sau một nhóm đã đọc phải đọc đủ 3 chữ số (vd 'không trăm linh năm')
    IF lv_million > 0.
      APPEND |{ read_triple( iv_number = lv_million iv_full = xsdbool( lt_part IS NOT INITIAL ) ) } triệu| TO lt_part.
    ENDIF.
    IF lv_thousand > 0.
      APPEND |{ read_triple( iv_number = lv_thousand iv_full = xsdbool( lt_part IS NOT INITIAL ) ) } nghìn| TO lt_part.
    ENDIF.
    IF lv_unit > 0.
      APPEND read_triple( iv_number = lv_unit iv_full = xsdbool( lt_part IS NOT INITIAL ) ) TO lt_part.
    ENDIF.

    rv_words = |{ concat_lines_of( table = lt_part sep = ` ` ) } đồng|.
    rv_words = to_upper( substring( val = rv_words len = 1 ) ) && substring( val = rv_words off = 1 ).
  ENDMETHOD.

  METHOD read_triple.
    CONSTANTS lc_digits TYPE string VALUE `không,một,hai,ba,bốn,năm,sáu,bảy,tám,chín`.
    DATA lt_part TYPE string_table.

    SPLIT lc_digits AT ',' INTO TABLE DATA(lt_digit).
    DATA(lv_hundred) = iv_number DIV 100.
    DATA(lv_ten)     = ( iv_number MOD 100 ) DIV 10.
    DATA(lv_one)     = iv_number MOD 10.

    IF lv_hundred > 0 OR iv_full = abap_true.
      APPEND |{ lt_digit[ lv_hundred + 1 ] } trăm| TO lt_part.
    ENDIF.

    CASE lv_ten.
      WHEN 0.
        IF lv_one > 0 AND lt_part IS NOT INITIAL.
          APPEND `linh` TO lt_part.
        ENDIF.
      WHEN 1.
        APPEND `mười` TO lt_part.
      WHEN OTHERS.
        APPEND |{ lt_digit[ lv_ten + 1 ] } mươi| TO lt_part.
    ENDCASE.

    CASE lv_one.
      WHEN 0.
      WHEN 1.
        APPEND COND string( WHEN lv_ten > 1 THEN `mốt` ELSE `một` ) TO lt_part.
      WHEN 4.
        APPEND COND string( WHEN lv_ten > 1 THEN `tư` ELSE `bốn` ) TO lt_part.
      WHEN 5.
        APPEND COND string( WHEN lv_ten > 0 THEN `lăm` ELSE `năm` ) TO lt_part.
      WHEN OTHERS.
        APPEND lt_digit[ lv_one + 1 ] TO lt_part.
    ENDCASE.

    rv_words = concat_lines_of( table = lt_part sep = ` ` ).
  ENDMETHOD.

ENDCLASS.
