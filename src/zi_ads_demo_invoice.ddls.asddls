/*=====================================================================
 Tên/Mã     : ZI_ADS_DEMO_INVOICE
 Mô tả chung: Header hoá đơn GIẢ LẬP (hằng số) cho bài FDP của ZCL_ADS_PDF_DEMO.
              Association _Item -> dòng hoá đơn: FDP đi theo association này để
              lồng dữ liệu dòng vào XML của header.
 Tác giả    : CB9980000013 - CuongUS
 Ngày tạo   : 30/10/2026
 Package    : ZPK_ADS_PDF
=====================================================================*/
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ADS demo - invoice header (mock data)'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_ADS_DEMO_INVOICE
  as select from I_Language
  association [0..*] to ZI_ADS_DEMO_INVOICEITEM as _Item on $projection.InvoiceNo = _Item.InvoiceNo
{
  key cast( 'HD0001' as abap.char(10) )                     as InvoiceNo,
      cast( '20261030' as abap.dats )                       as InvoiceDate,
      cast( 'CÔNG TY TNHH ABC (DEMO)' as abap.char(60) )    as SellerName,
      cast( 'Công ty TNHH XYZ (DEMO)' as abap.char(60) )    as BuyerName,
      cast( 1650000 as abap.dec(15,0) )                     as TotalAmount,
      _Item
}
where
  Language = 'E'
