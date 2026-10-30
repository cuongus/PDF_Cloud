# PDF_Cloud – ZPK_ADS_PDF

Render PDF bằng Adobe Document Services (ADS) từ template XDP thiết kế trong **Adobe LiveCycle Designer**,
trên SAP S/4HANA Cloud Public Edition (ABAP Cloud, chỉ dùng API đã release).
Mã nguồn lấy từ hệ DEV, package `ZPK_ADS_PDF`.

> `src/` chỉ chứa **source code** đặt tên theo quy ước abapGit, không có file metadata `.xml`
> (tenant chặn export zip abapGit) → không import thẳng bằng abapGit được.

## Đào tạo

Xem [docs/DAO_TAO.md](docs/DAO_TAO.md) và class demo `ZCL_ADS_PDF_DEMO` (9 bài, chạy F9 trong ADT).

## Kiến trúc

```
Chương trình in ──► ZCL_ADS_PDF_RENDERER ──► ZIF_ADS_PDF_ENGINE ──► ZCL_ADS_PDF_ENGINE ──► CL_FP_ADS_UTIL
      │                      │                                                       └► CL_RSPO_PDF_MERGER
      │                      └► ZIF_ADS_PDF_TEMPLATE_SOURCE ─┬► ZCL_ADS_PDF_TEMPLATE_DB   (bảng ZADS_A_TEMPLATE)
      │                                                      └► ZCL_ADS_PDF_TEMPLATE_FORM (object Form ADT, CL_FP_FORM_READER)
      └► dữ liệu XML: ZCL_ADS_PDF_XML (tự dựng) | ZCL_ADS_PDF_XDP_PARSER (từ cấu trúc ABAP) | ZCL_ADS_PDF_FDP (service definition)
```

| Object | Vai trò |
|---|---|
| `ZCL_ADS_PDF_RENDERER` | API chính: nhiều tài liệu → 1 PDF, chèn logo `<LOGO/>`, in vào print queue |
| `ZCL_ADS_PDF_ENGINE` / `ZIF_ADS_PDF_ENGINE` | Gọi ADS + gộp PDF; lỗi kèm trích đoạn trace ADS |
| `ZCL_ADS_PDF_TEMPLATE_DB` / `_FORM` / `ZIF_ADS_PDF_TEMPLATE_SOURCE` | Nguồn template: bảng (upload qua app) hoặc object Form (đi theo transport) |
| `ZCL_ADS_PDF_XML` | Dựng XML dữ liệu an toàn (escape, bỏ ký tự điều khiển), định dạng ngày/số kiểu Việt Nam |
| `ZCL_ADS_PDF_XDP_PARSER` | Đọc field có binding trong XDP, sinh XML từ cấu trúc ABAP theo tên (normal binding) |
| `ZCL_ADS_PDF_FDP` | XML + XSD từ service definition (RAP Data Services for Print Forms) |
| `ZCX_ADS_PDF` | Exception: text, mã template, trace ADS |
| `ZADS_A_TEMPLATE`, `ZR_/ZC_ADS_TEMPLATETP`, `ZUI_ADS_TEMPLATE(_O4)` | App quản lý template (draft, tự tăng phiên bản, kiểm tra mã / file / kiểu file) |

## Cách dùng

### 1. Tự dựng XML (thay cho ghép chuỗi + `REPLACE '&'`)

```abap
DATA(lo_xml) = zcl_ads_pdf_xml=>create( `form1` ).
lo_xml->open( `Header` ).
lo_xml->add( iv_name = `CompanyName` iv_value = ls_head-company_name ).   " tự escape
lo_xml->add_date( iv_name = `PostingDate` iv_date = ls_head-posting_date ).
lo_xml->close( ).
LOOP AT lt_item INTO DATA(ls_item).
  lo_xml->open( `Row` ).
  lo_xml->add( iv_name = `Text` iv_value = ls_item-text ).
  lo_xml->add_amount( iv_name = `Amount` iv_amount = ls_item-amount iv_currency = ls_item-currency ). " VND: dịch thập phân
  lo_xml->add( iv_name = `AmountText`
               iv_value = zcl_ads_pdf_xml=>format_currency_vn( iv_amount = ls_item-amount iv_currency = ls_item-currency ) ).
  lo_xml->close( ).
ENDLOOP.

TRY.
    DATA(ls_pdf) = zcl_ads_pdf_renderer=>create( )->render_single(
                     iv_template_id = `ZPHIEUKETOAN`
                     iv_xml         = lo_xml->to_xstring( ) ).
    " ls_pdf-pdf (xstring), ls_pdf-pdf_base64, ls_pdf-pages
  CATCH zcx_ads_pdf INTO DATA(lx_pdf).
    " lx_pdf->get_text( ), lx_pdf->mv_trace
ENDTRY.
```

### 2. Sinh XML từ cấu trúc ABAP theo XDP

```abap
DATA(lo_parser) = zcl_ads_pdf_xdp_parser=>create( lv_xdp ).        " parse 1 lần
DATA(lv_xml)    = lo_parser->build_xml( is_data  = ls_form           " = subform gốc
                                        it_alias = VALUE #( ( xdp_name = `Shipper` abap_name = `SHIPPER_NAME` ) ) ).
```

Quy tắc (XFA normal binding):
- subform không tên là "trong suốt"; subform/field có `<bind match="none">` không tạo dữ liệu;
- bảng nội bộ → subform lặp; tên khớp không phân biệt hoa thường, `it_alias` khi tên ABAP khác tên XDP;
- `d` → `YYYY-MM-DD`, `t` → `HH:MM:SS`, số → RAW (`1234.5`), `abap_bool` → `1/0` (checkbox),
  `x` → hex, `xstring` → base64 (image field), kiểu có ALPHA → bỏ số 0 đầu;
- field `bind match="dataRef"/"global"` không sinh theo tên → xem `get_explicit_bindings( )`;
- số tiền CURR xuất giá trị nội bộ: dịch thập phân theo tiền tệ trước (CDS `decimal_shift`)
  hoặc dựng bằng `zcl_ads_pdf_xml->add_amount( )`;
- subform gốc phải có tên (nếu không, `create` báo lỗi).

### 3. Dữ liệu từ service definition (FDP)

```abap
DATA(lo_fdp) = zcl_ads_pdf_fdp=>create( `ZUI_MY_FORM_DATA` ).
DATA(lv_xsd) = lo_fdp->get_xsd( ).      " nạp vào LiveCycle Designer làm data connection
DATA(lv_xml) = lo_fdp->read_xml( VALUE #( ( name = `AccountingDocument` value = lv_belnr ) ) ).
```

### 4. Nhiều chứng từ + logo, in print queue

```abap
DATA(ls_pdf) = zcl_ads_pdf_renderer=>create( )->render( VALUE #(
  template_id = `ZPHIEUTHU`
  documents   = lt_xml                                         " 1 dòng = 1 chứng từ
  logos       = VALUE #( ( document_index = 1 template_id = `ZLOGO_DEMO` ) ) ) ).

" Ngoài RAP (report, job, HTTP service): 1 lệnh, bên gọi COMMIT WORK sau đó
DATA(lv_item) = zcl_ads_pdf_renderer=>create( )->render_to_print_queue(
  iv_template_id = `ZPHIEUKETOAN` iv_xml = lv_xml
  iv_queue_name  = 'PRINT_USER'   iv_document_name = |PKT_{ lv_belnr }| ).

" Trong RAP: tách 2 bước
"  - action/determination (interaction phase): gọi ADS
DATA(ls_pdl) = zcl_ads_pdf_renderer=>create( )->render_for_print_queue(
  iv_template_id = `ZPHIEUKETOAN` iv_xml = lv_xml iv_queue_name = 'PRINT_USER' ).
"  - save_modified (late save): tạo queue item với item id tạo trước
zcl_ads_pdf_renderer=>add_to_print_queue( is_output = ls_pdl iv_queue_name = 'PRINT_USER'
  iv_document_name = |PKT_{ lv_belnr }| iv_item_id = cl_print_queue_utils=>create_queue_itemid( ) ).
```

Tuỳ chọn khác của `render`: `trace_level` (1-4, lấy trace ADS khi chẩn đoán lỗi → `zcx_ads_pdf->mv_trace`),
`skip_base64` (không tạo `pdf_base64` với PDF lớn), `logo_tag` (mặc định `LOGO`; nhận `<LOGO/>`, `<LOGO />`, `<LOGO></LOGO>`).
`create_for_forms( )` lấy layout từ object Form, ảnh logo vẫn từ bảng `ZADS_A_TEMPLATE`.

## So với bộ cũ (ZPK_ADOBE_PDF)

| Vấn đề bộ cũ | Bộ mới |
|---|---|
| Template trong bảng chung, không phiên bản | Bảng riêng + app draft, tự tăng `TemplateVersion`, mã chữ hoa; hoặc object Form đi theo transport |
| Chương trình gọi tự ghép XML, chỉ escape `&` | `ZCL_ADS_PDF_XML` / `ZCL_ADS_PDF_XDP_PARSER` / `ZCL_ADS_PDF_FDP` escape đầy đủ, bỏ ký tự điều khiển |
| Lỗi render bị bỏ qua, PDF thiếu trang | Lỗi bất kỳ tài liệu → `ZCX_ADS_PDF` kèm số thứ tự tài liệu và trace ADS |
| Singleton giữ dữ liệu cũ | Không có trạng thái dùng chung giữa các lần gọi (chỉ cache template trong 1 instance) |
| Gọi merger kể cả 1 tài liệu, đổi base64 qua lại | Bỏ merger khi 1 tài liệu, chuyển UTF-8 trực tiếp, đọc logo 1 lần/ảnh |
| Upload template không kiểm tra | Chặn trùng mã ngay khi tạo, suy ra kiểu file từ đuôi `.xdp/.png/.jpg/.bmp`, chỉ nhận XDP/ảnh |
| Số tiền VND sai thập phân | `add_amount` / `format_currency_vn` dịch thập phân theo tiền tệ |
| Không unit test | 27 unit test (test double cho ADS và nguồn template); ATC 0 finding |

## Lưu ý vận hành

- Font tự thêm: upload qua app *Adobe Document Services Configuration*, bật nhúng font.
- App quản lý template cần IAM app + business catalog cho service `ZUI_ADS_TEMPLATE_O4`.
- Locale mặc định `de_DE` (`.` hàng nghìn, `,` thập phân); tên tháng / mẫu ngày cũng theo `de_DE` →
  truyền `locale` nếu template cần khác.
- Mỗi tài liệu = 1 lần gọi ADS; in số lượng lớn (tem) nên dựng 1 XML có subform lặp.
- `TemplateVersion` đếm riêng ở từng tenant/client (dữ liệu template không đi theo transport).

## Tham khảo

- SAP Help – Runtime API for ADS Rendering Calls (`CL_FP_ADS_UTIL`)
- SAP-samples/abap-partner-reference-application – Forms feature (`CL_FP_FORM_READER`, `CL_FP_FDP_SERVICES`)
- SAP KBA 3126161 – upload custom fonts (*Adobe Document Services Configuration*)
