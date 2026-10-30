@EndUserText.label: 'Demo FDP - dòng phiếu nhập kho'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_DEMO_ADS_PNK_QUERY'
@UI.headerInfo: { typeName: 'Dòng hàng', typeNamePlural: 'Dòng hàng' }
define custom entity ZI_DEMO_ADS_PNKITEM
{
      @UI.hidden: true
  key DocNo        : abap.char(10);
      @UI.hidden: true
  key FiscalYear   : abap.numc(4);
      @UI.lineItem : [ { position: 10 } ]
      @EndUserText.label: 'STT'
  key ItemNo       : abap.int4;
      @UI.lineItem : [ { position: 20 } ]
      @EndUserText.label: 'Mã hàng'
      Material     : abap.char(18);
      @UI.lineItem : [ { position: 30 } ]
      @EndUserText.label: 'Tên hàng'
      MaterialName : abap.char(80);
      @UI.lineItem : [ { position: 40 } ]
      @EndUserText.label: 'ĐVT'
      Unit         : abap.char(3);
      @UI.lineItem : [ { position: 50 } ]
      @EndUserText.label: 'Chất lượng'
      Quality      : abap.char(3);
      @UI.lineItem : [ { position: 60 } ]
      @EndUserText.label: 'Quy đổi'
      Conversion   : abap.char(20);
      @UI.lineItem : [ { position: 70 } ]
      @EndUserText.label: 'SL yêu cầu'
      QtyRequested : abap.dec(13,3);
      @UI.lineItem : [ { position: 80 } ]
      @EndUserText.label: 'SL thực nhập'
      QtyReceived  : abap.dec(13,3);
      @UI.lineItem : [ { position: 90 } ]
      @EndUserText.label: 'Đơn giá'
      Price        : abap.dec(15,0);
      @UI.lineItem : [ { position: 100 } ]
      @EndUserText.label: 'Thành tiền'
      Amount       : abap.dec(17,0);
      // Cho form in: SL yêu cầu chỉ có ở dòng hiển thị của nhóm cùng mã hàng + cùng SL yêu cầu
      @UI.hidden: true
      @EndUserText.label: 'SL yêu cầu (in)'
      QtyRequestedText : abap.char(20);
      // Vị trí dòng trong nhóm gộp: ký tự 1 = S đơn / F đầu / M giữa / L cuối; ký tự 2 = B: số canh đáy ô
      @UI.hidden: true
      @EndUserText.label: 'Vị trí gộp'
      MergePos     : abap.char(2);
}
