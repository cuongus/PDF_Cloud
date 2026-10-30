/*=====================================================================
 Tên/Mã     : ZI_ADS_DEMO_ORDERLINE_CE
 Mô tả chung: Dòng đơn hàng GIẢ LẬP - custom entity, dữ liệu do class query
              ZCL_ADS_DEMO_CE_QUERY trả về (minh hoạ FDP với custom entity)
 Tác giả    : CB9980000013 - CuongUS
 Ngày tạo   : 30/10/2026
 Package    : ZPK_ADS_PDF
=====================================================================*/
@EndUserText.label: 'ADS demo - order line (custom entity)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_ADS_DEMO_CE_QUERY'
define custom entity ZI_ADS_DEMO_ORDERLINE_CE
{
  key OrderNo     : abap.char(10);
  key ItemNo      : abap.int4;
      Product     : abap.char(60);
      Quantity    : abap.int4;
      Amount      : abap.dec(15,0);
}
