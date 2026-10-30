/*=====================================================================
 Tên/Mã     : ZI_ADS_DEMO_INVOICEITEM
 Mô tả chung: Dòng hoá đơn GIẢ LẬP (hằng số) cho bài FDP của ZCL_ADS_PDF_DEMO.
              Lấy 1 dòng từ I_Language làm "nguồn" để trả về hằng số, không cần bảng.
 Tác giả    : CB9980000013 - CuongUS
 Ngày tạo   : 30/10/2026
 Package    : ZPK_ADS_PDF
=====================================================================*/
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ADS demo - invoice item (mock data)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ADS_DEMO_INVOICEITEM
  as select from I_Language
{
  key cast( 'HD0001' as abap.char(10) )                 as InvoiceNo,
  key cast( 10 as abap.int4 )                           as ItemNo,
      cast( 'Bàn làm việc (DEMO)' as abap.char(60) )    as Description,
      cast( 2 as abap.int4 )                            as Quantity,
      cast( 500000 as abap.dec(15,0) )                  as Amount
}
where
  Language = 'E'

union all select from I_Language
{
  key cast( 'HD0001' as abap.char(10) )                 as InvoiceNo,
  key cast( 20 as abap.int4 )                           as ItemNo,
      cast( 'Ghế xoay (DEMO)' as abap.char(60) )        as Description,
      cast( 4 as abap.int4 )                            as Quantity,
      cast( 600000 as abap.dec(15,0) )                  as Amount
}
where
  Language = 'E'

union all select from I_Language
{
  key cast( 'HD0001' as abap.char(10) )                 as InvoiceNo,
  key cast( 30 as abap.int4 )                           as ItemNo,
      cast( 'Phí vận chuyển & lắp đặt' as abap.char(60) ) as Description,
      cast( 1 as abap.int4 )                            as Quantity,
      cast( 50000 as abap.dec(15,0) )                   as Amount
}
where
  Language = 'E'
