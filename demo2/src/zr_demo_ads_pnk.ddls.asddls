@EndUserText.label: 'Demo FDP - phiếu nhập kho'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_DEMO_ADS_PNK_QUERY'
@UI.headerInfo: { typeName: 'Phiếu nhập kho', typeNamePlural: 'Phiếu nhập kho',
                  title: { type: #STANDARD, value: 'DocNo' },
                  description: { type: #STANDARD, value: 'Supplier' } }
define root custom entity ZR_DEMO_ADS_PNK
{
      @UI.facet: [ { id: 'General', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                     label: 'Thông tin chung', position: 10 },
                   { id: 'Signer', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE,
                     targetQualifier: 'Signer', label: 'Người ký', position: 20 },
                   { id: 'Item', purpose: #STANDARD, type: #LINEITEM_REFERENCE,
                     targetElement: '_Item', label: 'Dòng hàng', position: 30 } ]
      @UI.lineItem: [ { position: 10 } ]
      @UI.identification: [ { position: 10 } ]
      @UI.selectionField: [ { position: 10 } ]
      @Consumption.filter: { multipleSelections: true }
      @EndUserText.label: 'Số phiếu nhập kho'
  key DocNo            : abap.char(10);
      @UI.lineItem: [ { position: 20 } ]
      @UI.identification: [ { position: 20 } ]
      @UI.selectionField: [ { position: 20 } ]
      @Consumption.filter: { multipleSelections: false }
      @EndUserText.label: 'Năm'
  key FiscalYear       : abap.numc(4);
      @UI.lineItem: [ { position: 30 } ]
      @UI.identification: [ { position: 30 } ]
      @EndUserText.label: 'Ngày nhập'
      PostingDate      : abap.dats;
      @UI.lineItem: [ { position: 40 } ]
      @UI.identification: [ { position: 40 } ]
      @EndUserText.label: 'Nhà cung cấp'
      Supplier         : abap.char(80);
      @UI.lineItem: [ { position: 50 } ]
      @UI.identification: [ { position: 50 } ]
      @EndUserText.label: 'Đơn mua hàng'
      PurchaseOrder    : abap.char(10);
      @UI.lineItem: [ { position: 60 } ]
      @UI.identification: [ { position: 60 } ]
      @EndUserText.label: 'Kho nhập'
      StorageLocation  : abap.char(40);
      @UI.identification: [ { position: 70 } ]
      @EndUserText.label: 'Diễn giải'
      HeaderText       : abap.char(80);
      @UI.lineItem: [ { position: 70 } ]
      @UI.identification: [ { position: 80 } ]
      @EndUserText.label: 'Tổng tiền'
      TotalAmount      : abap.dec(17,0);
      @UI.identification: [ { position: 82 } ]
      @EndUserText.label: 'Tổng SL yêu cầu'
      TotalQtyRequested : abap.dec(15,3);
      @UI.identification: [ { position: 84 } ]
      @EndUserText.label: 'Tổng SL thực nhập'
      TotalQtyReceived : abap.dec(15,3);
      @UI.identification: [ { position: 90 } ]
      @EndUserText.label: 'Số tiền bằng chữ'
      AmountInWords    : abap.char(255);
      @UI.hidden: true
      @EndUserText.label: 'Nội dung QR'
      QrContent        : abap.char(255);
      @UI.lineItem: [ { position: 80 } ]
      @UI.fieldGroup: [ { qualifier: 'Signer', position: 10 } ]
      @UI.selectionField: [ { position: 30 } ]
      @Consumption.filter: { multipleSelections: false }
      @EndUserText.label: 'Người giao hàng'
      Shipper          : abap.char(60);
      @UI.lineItem: [ { position: 90 } ]
      @UI.fieldGroup: [ { qualifier: 'Signer', position: 20 } ]
      @UI.selectionField: [ { position: 40 } ]
      @Consumption.filter: { multipleSelections: false }
      @EndUserText.label: 'Quản lý kho'
      WarehouseManager : abap.char(60);
      @UI.lineItem: [ { position: 100 } ]
      @UI.fieldGroup: [ { qualifier: 'Signer', position: 30 } ]
      @UI.selectionField: [ { position: 50 } ]
      @Consumption.filter: { multipleSelections: false }
      @EndUserText.label: 'Thủ kho'
      StoreKeeper      : abap.char(60);
      @UI.lineItem: [ { position: 110 } ]
      @UI.fieldGroup: [ { qualifier: 'Signer', position: 40 } ]
      @UI.selectionField: [ { position: 60 } ]
      @Consumption.filter: { multipleSelections: false }
      @EndUserText.label: 'Kế toán'
      Accountant       : abap.char(60);
      _Item            : association [0..*] to ZI_DEMO_ADS_PNKITEM
                           on  _Item.DocNo      = $projection.DocNo
                           and _Item.FiscalYear = $projection.FiscalYear;
}
