@EndUserText.label: 'Demo FDP - tham số in phiếu nhập kho'
define abstract entity ZD_DEMO_ADS_PNK_PRM
{
  @EndUserText.label: 'Danh sách phiếu (Số/Năm, ...)'
  DocumentKeys     : abap.string(0);
  @EndUserText.label: 'Người giao hàng'
  Shipper          : abap.char(60);
  @EndUserText.label: 'Quản lý kho'
  WarehouseManager : abap.char(60);
  @EndUserText.label: 'Thủ kho'
  StoreKeeper      : abap.char(60);
  @EndUserText.label: 'Kế toán'
  Accountant       : abap.char(60);
}
