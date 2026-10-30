# Demo FDP – app Fiori "Phiếu nhập kho" (package ZPK_DEMO_2)

App Fiori Elements V4 minh hoạ in PDF bằng **FDP + ADS** với dữ liệu giả lập, dùng bộ `ZPK_ADS_PDF`.

| Object | Vai trò |
|---|---|
| `ZR_DEMO_ADS_PNK` / `ZI_DEMO_ADS_PNKITEM` | Custom entity phiếu + dòng hàng (query `ZCL_DEMO_ADS_PNK_QUERY`, dữ liệu giả lập) |
| `ZCL_DEMO_ADS_PNK_QUERY` | Filter / sort / paging; người ký nhập ở filter bar ghi đè giá trị; số tiền bằng chữ; thông tin gộp ô SL yêu cầu (`MergePos`) |
| `ZR_DEMO_ADS_PNK` (BDEF) + `ZBP_R_DEMO_ADS_PNK` | static action `printPreview` (PDF base64), static function `getDesignFiles` (XSD + XDP) |
| `ZCL_DEMO_ADS_PNK_PRINT` | `ZCL_ADS_PDF_FDP` đọc XML từ `ZUI_DEMO_ADS_PNK_FDP` → `ZCL_ADS_PDF_RENDERER` render template `ZDEMO_PNK`; nhiều phiếu = file gộp + file lẻ. F9 để chạy thử |
| `ZUI_DEMO_ADS_PNK` / `ZUI_DEMO_ADS_PNK_O4` | Service OData V4 cho app |
| `ZUI_DEMO_ADS_PNK_FDP` | Service definition chỉ dùng cho FDP (dữ liệu in) |
| `app/` (BSP `ZDEMO_PNK_FDP`) | List report + object page; nút **Print preview** mở hộp thoại *Preview PDFs* (Chọn file / Download / Print / Close) — `webapp/ext/PrintPreview.js` |
| `zdemo_pnk.xdp` | Template mẫu (QR code, bảng 2 tầng tiêu đề, gộp ô SL yêu cầu bằng script, số tiền bằng chữ, 4 chữ ký). Nhúng vào class bằng `gen_print_class.py` |

Template: nếu bảng `ZADS_A_TEMPLATE` có `ZDEMO_PNK` (upload qua app quản lý template) thì dùng bản đó, không thì dùng XDP nhúng trong class.

Build app: `cd app && npm install && npm run build`; deploy BSP: skill deploy-frontend (`deploy_bsp.cjs`), package local nên không có TR.
