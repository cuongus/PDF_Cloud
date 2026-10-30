*=====================================================================
* Behavior pool ZR_DEMO_ADS_PNK (demo FDP phiếu nhập kho, dữ liệu giả lập)
* - printPreview  : in các phiếu đã chọn -> danh sách PDF base64
* - getDesignFiles: XSD (từ FDP) + XDP mẫu cho người thiết kế form
*=====================================================================
CLASS lhc_goodsreceipt DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR GoodsReceipt RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ GoodsReceipt RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK GoodsReceipt.

    METHODS printpreview FOR MODIFY
      IMPORTING keys FOR ACTION GoodsReceipt~printPreview RESULT result.

    METHODS getdesignfiles FOR READ
      IMPORTING keys FOR FUNCTION GoodsReceipt~getDesignFiles RESULT result.
ENDCLASS.

CLASS lhc_goodsreceipt IMPLEMENTATION.

  METHOD get_global_authorizations.
    "Demo: mọi user có app đều được in (kết quả rỗng = cho phép)
  ENDMETHOD.

  METHOD read.
    "Không dùng: dữ liệu đọc qua query class ZCL_DEMO_ADS_PNK_QUERY
  ENDMETHOD.

  METHOD lock.
    "Chỉ in, không sửa dữ liệu -> không cần khoá
  ENDMETHOD.

  METHOD printpreview.
    DATA(lo_print) = NEW zcl_demo_ads_pnk_print( ).

    LOOP AT keys INTO DATA(ls_key).
      TRY.
          DATA(lt_file) = lo_print->print_preview(
                            it_key    = zcl_demo_ads_pnk_print=>parse_keys( ls_key-%param-documentkeys )
                            is_signer = VALUE #( shipper           = ls_key-%param-shipper
                                                 warehouse_manager = ls_key-%param-warehousemanager
                                                 store_keeper      = ls_key-%param-storekeeper
                                                 accountant        = ls_key-%param-accountant ) ).
          LOOP AT lt_file INTO DATA(ls_file).
            APPEND VALUE #( %cid   = ls_key-%cid
                            %param = VALUE #( filename    = ls_file-file_name
                                              mimetype    = ls_file-mime_type
                                              filecontent = ls_file-content ) ) TO result.
          ENDLOOP.
        CATCH zcx_ads_pdf INTO DATA(lx_pdf).
          APPEND VALUE #( %cid = ls_key-%cid ) TO failed-goodsreceipt.
          APPEND VALUE #( %cid = ls_key-%cid
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = lx_pdf->get_text( ) ) ) TO reported-goodsreceipt.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD getdesignfiles.
    LOOP AT keys INTO DATA(ls_key).
      TRY.
          LOOP AT NEW zcl_demo_ads_pnk_print( )->get_design_files( ) INTO DATA(ls_file).
            APPEND VALUE #( %cid   = ls_key-%cid
                            %param = VALUE #( filename    = ls_file-file_name
                                              mimetype    = ls_file-mime_type
                                              filecontent = ls_file-content ) ) TO result.
          ENDLOOP.
        CATCH zcx_ads_pdf INTO DATA(lx_pdf).
          APPEND VALUE #( %cid = ls_key-%cid ) TO failed-goodsreceipt.
          APPEND VALUE #( %cid = ls_key-%cid
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = lx_pdf->get_text( ) ) ) TO reported-goodsreceipt.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_zr_demo_ads_pnk DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save REDEFINITION.
    METHODS cleanup REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_zr_demo_ads_pnk IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
    "Không lưu gì: action chỉ trả PDF
  ENDMETHOD.

  METHOD cleanup.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.