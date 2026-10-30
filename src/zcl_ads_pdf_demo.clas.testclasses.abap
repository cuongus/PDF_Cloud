*"* Smoke test: chạy cả 9 bài (gọi ADS thật) - không bài nào được báo LỖI.
*"* Bài thiếu template ở client đang chạy tự bỏ qua, không tính là lỗi.
CLASS ltcl_demo DEFINITION FINAL FOR TESTING
  DURATION LONG
  RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS all_lessons_run FOR TESTING.
ENDCLASS.

CLASS ltcl_demo IMPLEMENTATION.
  METHOD all_lessons_run.
    DATA(lt_log) = NEW zcl_ads_pdf_demo( )->run_all( ).

    cl_abap_unit_assert=>assert_not_initial( lt_log ).
    LOOP AT lt_log INTO DATA(lv_line) WHERE table_line CS `LỖI bài`.
      cl_abap_unit_assert=>fail( msg  = substring( val = lv_line len = nmin( val1 = strlen( lv_line ) val2 = 240 ) )
                                 quit = if_abap_unit_constant=>quit-no ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.