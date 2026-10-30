/**
 * Nút "Print preview" (list report + object page) và "Tải XSD/XDP thiết kế".
 * Gọi static action printPreview / static function getDesignFiles của BO
 * ZR_DEMO_ADS_PNK; kết quả là danh sách file base64 -> hộp thoại xem PDF
 * (chọn file, Download, Print, Close) như app Phiếu nhập kho đang chạy.
 */
sap.ui.define([
  "sap/m/Dialog",
  "sap/m/Button",
  "sap/m/Select",
  "sap/m/Label",
  "sap/m/Toolbar",
  "sap/m/ToolbarSpacer",
  "sap/m/MessageBox",
  "sap/m/MessageToast",
  "sap/ui/core/HTML",
  "sap/ui/core/Item",
  "sap/ui/core/BusyIndicator"
], function (Dialog, Button, Select, Label, Toolbar, ToolbarSpacer, MessageBox, MessageToast,
             HTML, Item, BusyIndicator) {
  "use strict";

  var ENTITY_SET = "/GoodsReceipt";

  function base64ToBlob(sBase64, sMimeType) {
    var sBinary = atob(sBase64);
    var aBytes = new Uint8Array(sBinary.length);
    for (var i = 0; i < sBinary.length; i++) {
      aBytes[i] = sBinary.charCodeAt(i);
    }
    return new Blob([aBytes], { type: sMimeType });
  }

  function download(oFile) {
    var oLink = document.createElement("a");
    oLink.href = URL.createObjectURL(base64ToBlob(oFile.FileContent, oFile.MimeType));
    oLink.download = oFile.FileName;
    document.body.appendChild(oLink);
    oLink.click();
    document.body.removeChild(oLink);
    setTimeout(function () { URL.revokeObjectURL(oLink.href); }, 10000);
  }

  // Namespace của service (com.sap.gateway.srvd.<binding>.v0001) đọc từ metadata
  function callOperation(oModel, sName, mParameters) {
    return oModel.getMetaModel().requestObject(ENTITY_SET + "/$Type").then(function (sType) {
      var sNamespace = sType.substring(0, sType.lastIndexOf("."));
      var oOperation = oModel.bindContext(ENTITY_SET + "/" + sNamespace + "." + sName + "(...)");
      Object.keys(mParameters || {}).forEach(function (sKey) {
        oOperation.setParameter(sKey, mParameters[sKey]);
      });
      return oOperation.execute().then(function () {
        var oResult = oOperation.getBoundContext().getObject();
        return (oResult && oResult.value) || [];
      });
    });
  }

  function errorText(oError) {
    var oDetail = oError && oError.error;
    return (oDetail && oDetail.message) || (oError && oError.message) || String(oError);
  }

  function openPreview(aFiles) {
    var aUrls = aFiles.map(function (oFile) {
      return URL.createObjectURL(base64ToBlob(oFile.FileContent, oFile.MimeType));
    });
    var iCurrent = 0;
    var oFrame = new HTML({
      content: "<iframe style='width:100%;height:100%;border:none' title='PDF'></iframe>",
      afterRendering: function () { showFile(iCurrent); }
    });

    function frameElement() {
      var oDom = oFrame.getDomRef();
      return oDom && (oDom.tagName === "IFRAME" ? oDom : oDom.querySelector("iframe"));
    }

    function showFile(iIndex) {
      iCurrent = iIndex;
      var oIframe = frameElement();
      if (oIframe) {
        oIframe.src = aUrls[iIndex];
      }
    }

    var oSelect = new Select({
      width: "24rem",
      items: aFiles.map(function (oFile, iIndex) {
        return new Item({ key: String(iIndex), text: oFile.FileName });
      }),
      change: function (oEvent) {
        showFile(parseInt(oEvent.getParameter("selectedItem").getKey(), 10));
      }
    });

    var oDialog = new Dialog({
      title: "Preview PDFs",
      contentWidth: "80%",
      contentHeight: "85%",
      resizable: true,
      draggable: true,
      verticalScrolling: false,
      subHeader: new Toolbar({ content: [new Label({ text: "Chọn file", labelFor: oSelect }), oSelect] }),
      content: [oFrame],
      buttons: [
        new Button({ text: "Download", icon: "sap-icon://download", press: function () { download(aFiles[iCurrent]); } }),
        new Button({
          text: "Print", icon: "sap-icon://print", press: function () {
            var oIframe = frameElement();
            try {
              oIframe.contentWindow.focus();
              oIframe.contentWindow.print();
            } catch (e) {
              window.open(aUrls[iCurrent], "_blank");     // trình duyệt chặn in trong iframe
            }
          }
        }),
        new Button({ text: "Close", press: function () { oDialog.close(); } })
      ],
      afterClose: function () {
        aUrls.forEach(function (sUrl) { URL.revokeObjectURL(sUrl); });
        oDialog.destroy();
      }
    });
    oDialog.addStyleClass("sapUiNoContentPadding");
    oDialog.open();
  }

  return {
    // List report: (oContext, aSelectedContexts); object page: (oContext của phiếu đang mở)
    onPrintPreview: function (oContext, aSelectedContexts) {
      var aContexts = (aSelectedContexts && aSelectedContexts.length) ? aSelectedContexts : (oContext ? [oContext] : []);
      if (!aContexts.length) {
        MessageToast.show("Chọn ít nhất một phiếu nhập kho");
        return;
      }
      var aRows = aContexts.map(function (oCtx) { return oCtx.getObject(); });
      var oFirst = aRows[0];
      // Người ký lấy từ dòng (đã gồm giá trị nhập ở filter bar)
      var mParameters = {
        DocumentKeys: aRows.map(function (oRow) { return oRow.DocNo + "/" + oRow.FiscalYear; }).join(","),
        Shipper: oFirst.Shipper || "",
        WarehouseManager: oFirst.WarehouseManager || "",
        StoreKeeper: oFirst.StoreKeeper || "",
        Accountant: oFirst.Accountant || ""
      };

      BusyIndicator.show(0);
      callOperation(aContexts[0].getModel(), "printPreview", mParameters).then(function (aFiles) {
        BusyIndicator.hide();
        if (!aFiles.length) {
          MessageToast.show("Không có file PDF");
          return;
        }
        openPreview(aFiles);
      }).catch(function (oError) {
        BusyIndicator.hide();
        MessageBox.error(errorText(oError));
      });
    },

    onDesignFiles: function (oContext) {
      var oModel = oContext ? oContext.getModel() : this.getModel();
      BusyIndicator.show(0);
      callOperation(oModel, "getDesignFiles").then(function (aFiles) {
        BusyIndicator.hide();
        aFiles.forEach(download);
        MessageToast.show("Đã tải " + aFiles.length + " file: XSD (data connection) + XDP mẫu");
      }).catch(function (oError) {
        BusyIndicator.hide();
        MessageBox.error(errorText(oError));
      });
    }
  };
});
