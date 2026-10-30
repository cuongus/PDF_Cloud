/*=====================================================================
 Tên/Mã     : ZI_ADS_DEMO_ORDER_CE
 Mô tả chung: Đơn hàng GIẢ LẬP - custom entity gốc, dữ liệu do class query
              ZCL_ADS_DEMO_CE_QUERY trả về; association _Line -> dòng đơn hàng.
              QrContent: nội dung cho field QR Code của LiveCycle.
 Tác giả    : CB9980000013 - CuongUS
 Ngày tạo   : 30/10/2026
 Package    : ZPK_ADS_PDF
=====================================================================*/
@EndUserText.label: 'ADS demo - order header (custom entity)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_ADS_DEMO_CE_QUERY'
define root custom entity ZI_ADS_DEMO_ORDER_CE
{
  key OrderNo     : abap.char(10);
      OrderDate   : abap.dats;
      Customer    : abap.char(60);
      QrContent   : abap.char(255);
      TotalAmount : abap.dec(15,0);
      _Line       : association [0..*] to ZI_ADS_DEMO_ORDERLINE_CE on _Line.OrderNo = $projection.OrderNo;
}
