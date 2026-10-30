# Đào tạo: sinh PDF bằng package ZPK_ADS_PDF

Tài liệu đi kèm class demo **`ZCL_ADS_PDF_DEMO`** (9 bài, dữ liệu giả lập, dùng template có sẵn trên hệ thống).
Đã chạy thật với Adobe Document Services trên hệ DEV (client 080) và hệ dữ liệu (client 100) ngày 30/10/2026.

## 0. Chạy demo

1. Mở `ZCL_ADS_PDF_DEMO` trong Eclipse ADT, nhấn **F9** (Run As → ABAP Application (Console)).
2. Console in nhật ký từng bài: số trang, dung lượng PDF, lỗi (nếu có).
3. Bài nào cần template không có trong client đang chạy sẽ tự bỏ qua và ghi rõ lý do.
   Template mẫu nằm ở bảng cũ `ZCORE_TB_TEMPPDF`: client **100** có đủ, client 080 chỉ có `zphieuketoan`.
4. Hai cờ trong class (mặc định tắt, không ghi gì xuống hệ thống):
   - `c_write_template_table` – bài 7 ghi template vào bảng mới `ZADS_A_TEMPLATE`;
   - `c_create_print_item` – bài 8 tạo item thật trong print queue.

Kết quả chạy trên client 100:

| Bài | Template | Kết quả |
|---|---|---|
| 1 Khám phá template | FormVGMCasa | 7 field, 0 bind tường minh |
| 2 XML từ cấu trúc ABAP | FormVGMCasa | 1 trang |
| 3 Dựng XML thủ công, tiền VND | zphieuthu (2 liên) | 1 trang, 203 KB; 15000.00 nội bộ → 1.500.000 |
| 4 Nhiều chứng từ → 1 PDF | zphieuketoan ×3 | 3 trang, 448 KB |
| 5 In tem hàng loạt + field ảnh | zbarcode_bin ×4 tem | 1 lần gọi ADS, 70 KB |
| 6 Xử lý lỗi | FormVGMCasa, zbom | thiếu template, sai kiểu field số, file không phải XDP |
| 7 Upload template (EML) | FormVGMCasa → ZVGM_DEMO | chạy khi bật cờ |
| 8 Print queue | zphieuketoan | PDL cho queue DEFAULT |
| 9 FDP | ZUI_ADS_TEMPLATE | XSD 9.559 ký tự |

## 1. Bức tranh chung

```
Dữ liệu ABAP ──► XML dữ liệu ──► ZCL_ADS_PDF_RENDERER ──► ADS ──► PDF / PDL (print queue)
                  ▲                       ▲
   ZCL_ADS_PDF_XML (tự dựng)        Template XDP (LiveCycle):
   ZCL_ADS_PDF_XDP_PARSER (từ struct)   - bảng ZADS_A_TEMPLATE  -> create( )
   ZCL_ADS_PDF_FDP (service def.)       - object Form ADT       -> create_for_forms( )
                                        - nguồn tự viết         -> create( io_template_source = ... )
```

Quy tắc vàng: **tên phần tử XML phải trùng tên field / subform trong XDP** (XFA normal data binding).
Sai tên → ADS không báo lỗi, field in ra trống.

## 2. Các bài

### Bài 1 – Khám phá template trước khi viết code

```abap
DATA(lo_parser) = zcl_ads_pdf_xdp_parser=>create( lv_xdp ).
LOOP AT lo_parser->get_field_paths( ) INTO DATA(lv_path).   " Form/Main/Header/Date ...
ENDLOOP.
lo_parser->get_explicit_bindings( ).   " field bind dataRef/global – phải tự dựng XML / dùng FDP
```

Đường dẫn field chính là "bản đồ" để đặt tên cấu trúc ABAP (bài 2) hoặc thứ tự `open/add/close` (bài 3).

### Bài 2 – Sinh XML từ cấu trúc ABAP (cách nhanh nhất)

- Đặt cấu trúc ABAP lồng nhau đúng theo đường dẫn: `Form-Main-Header-Date`.
- Subform lặp (bảng) → bảng nội bộ; subform không tên trong XDP không cần cấp tương ứng.
- Tên khác nhau → `it_alias` (vd XDP `Createby` ↔ ABAP `CREATED_BY`, bài 4).

```abap
mv_xml = zcl_ads_pdf_xdp_parser=>create( lv_xdp )->build_xml( ls_form ).
DATA(ls_pdf) = zcl_ads_pdf_renderer=>create( )->render_single( iv_template_id = `ZVGM_DEMO` iv_xml = mv_xml ).
```

> **Bài học thực tế (lỗi ADS 29216 `Invalid value: '24.350,5' for 'float' property`)**
> Field kiểu **số** trong LiveCycle (numericEdit, decimal) phải nhận **số RAW** (`24350.5`).
> Khai thành phần ABAP kiểu số (`p`, `i`) – parser tự xuất RAW; dấu chấm/phẩy khi in là việc của *display pattern* trong XDP.
> `format_amount_vn` / `format_currency_vn` chỉ dùng cho field **text**.

### Bài 3 – Dựng XML thủ công bằng ZCL_ADS_PDF_XML

Dùng khi cấu trúc dữ liệu khác xa cấu trúc form, hoặc form có nhiều liên giống nhau (`main`, `main_1`).

```abap
DATA(lo_xml) = zcl_ads_pdf_xml=>create( `form1` ).
lo_xml->open( `main` )->open( `HeaderSection` ).
lo_xml->add( iv_name = `CompanyName` iv_value = ls_head-company ).          " tự escape & < >
lo_xml->add( iv_name = `PostingDate` iv_value = zcl_ads_pdf_xml=>format_date_vn( ls_head-budat ) ).
lo_xml->close( ).
lo_xml->add( iv_name  = `sotien`
             iv_value = zcl_ads_pdf_xml=>format_currency_vn( iv_amount = ls_head-amount iv_currency = `VND` ) ).
DATA(lv_xml) = lo_xml->to_xstring( ).                                       " tự đóng thẻ còn mở
```

- Không còn `REPLACE ALL OCCURRENCES OF '&' ...` cho từng field như code cũ.
- Tiền CURR là **giá trị nội bộ**: VND 0 số lẻ → `15000.00` nội bộ = 1.500.000 đồng. `format_currency_vn` / `add_amount` tự dịch theo tiền tệ.

### Bài 4 – Nhiều chứng từ → 1 PDF

```abap
DATA(lo_parser) = zcl_ads_pdf_xdp_parser=>create( lv_xdp ).        " parse 1 lần
LOOP AT lt_doc INTO DATA(ls_doc).
  APPEND lo_parser->build_xml( is_data = ls_doc it_alias = lt_alias ) TO lt_documents.
ENDLOOP.
DATA(ls_pdf) = zcl_ads_pdf_renderer=>create( )->render( VALUE #( template_id = `ZPHIEUKETOAN`
                                                                 documents   = lt_documents
                                                                 skip_base64 = abap_true ) ).
```

- Một tài liệu lỗi → cả lệnh báo `ZCX_ADS_PDF` "Tài liệu n: ..." (không trả PDF thiếu trang).
- `skip_base64` khi chỉ cần xstring (lưu attachment) – đỡ ~1,33 lần bộ nhớ.

### Bài 5 – In tem hàng loạt: 1 lần gọi ADS

Mỗi tài liệu trong `documents` = 1 lần gọi ADS. Với tem/nhãn số lượng lớn, dựng **1 XML có subform lặp**:

```abap
TYPES: BEGIN OF ty_label, qrimg TYPE xstring, storagebin TYPE string, storagebin2 TYPE string, END OF ty_label,
       BEGIN OF ty_form,  main  TYPE STANDARD TABLE OF ty_label WITH EMPTY KEY, END OF ty_form.
" qrimg kiểu xstring -> parser tự chuyển base64 cho field ảnh
```

### Bài 6 – Xử lý lỗi

```abap
TRY.
    DATA(ls_pdf) = lo_renderer->render( VALUE #( template_id = `ZPHIEUTHU` documents = lt_xml trace_level = 1 ) ).
  CATCH zcx_ads_pdf INTO DATA(lx).
    lx->get_text( ).       " mô tả, có số thứ tự tài liệu lỗi
    lx->mv_template_id.    " template liên quan
    lx->mv_trace.          " trace ADS – tìm dòng chứa Exception / Error
ENDTRY.
```

Lỗi thường gặp (demo có cả 3): không tìm thấy template; giá trị sai kiểu cho field số/ngày (ADS 29216, xem bài 2); dùng nhầm ảnh/Excel làm layout.

### Bài 7 – Đưa template vào bảng mới

- Cách thường dùng: app Fiori service `ZUI_ADS_TEMPLATE_O4` (upload file `.xdp`, mã chữ hoa, tự tăng phiên bản).
- Bằng code (EML) – xem `lesson_07_upload`: `MODIFY ENTITIES OF zr_ads_templatetp ... CREATE` + `COMMIT ENTITIES`.
- Dữ liệu template là dữ liệu theo client → phải upload ở **từng** tenant/client.

### Bài 8 – Print queue

```abap
" Ngoài RAP:
lo_renderer->render_to_print_queue( iv_template_id = `ZPHIEUKETOAN` iv_xml = lv_xml
                                    iv_queue_name = 'DEFAULT' iv_document_name = `PKT_100001` ).
COMMIT WORK.
" Trong RAP: bước 1 ở action/determination, bước 2 ở late save
DATA(ls_pdl) = lo_renderer->render_for_print_queue( iv_template_id = ... iv_xml = ... iv_queue_name = ... ).
zcl_ads_pdf_renderer=>add_to_print_queue( is_output = ls_pdl iv_queue_name = ... iv_document_name = ...
                                          iv_item_id = cl_print_queue_utils=>create_queue_itemid( ) ).
```

### Bài 9 – FDP: XML + XSD từ service definition

```abap
DATA(lo_fdp) = zcl_ads_pdf_fdp=>create( `ZUI_MY_FORM` ).     " service definition, không cần binding
DATA(lv_xsd) = lo_fdp->get_xsd( ).                           " nạp vào LiveCycle làm data connection
DATA(lv_xml) = lo_fdp->read_xml( VALUE #( ( name = `AccountingDocument` value = lv_belnr ) ) ).
```

Thiết kế form mới nên đi theo hướng này: field kéo từ data connection → tên luôn khớp dữ liệu.

## 3. Khảo sát template hiện có (client 100, 30/10/2026)

- Bảng `ZCORE_TB_TEMPPDF`: 90 bản ghi = **67 XDP** + 21 Excel + 2 ảnh JPEG; parser đọc được cả 67 XDP.
- Phần lớn bind theo tên; `zwclabel` bind tường minh (dataRef) toàn bộ 10 field; `zpdfdemo` 1 field.
- Nhiều template đặt tên field mặc định (`TextField1`, `Cell2`, `Row1`…: ZDNTT, ZLNH, BBDCCN, ZUNC…) → khó map, nên đổi tên trong LiveCycle khi chuyển sang bộ mới.
- Một số template có 2 phiên bản khác nhau giữa client 080 và 100 (vd `zphieuketoan` 6 field / 14 field) → cần quản lý phiên bản (bảng mới có `TemplateVersion`).
- Không template nào có field `LOGO` – logo đang nằm cố định trong XDP; tính năng chèn logo của renderer dùng khi template có image field tên `LOGO`.

## 4. Checklist chuyển một chương trình in cũ sang bộ mới

1. Upload XDP vào `ZADS_A_TEMPLATE` (mã chữ hoa) ở từng client.
2. Chạy bài 1 với template đó → lấy danh sách field.
3. Thay đoạn ghép chuỗi XML + `REPLACE '&'` bằng cấu trúc ABAP + parser (bài 2) hoặc `ZCL_ADS_PDF_XML` (bài 3).
4. Field số/ngày trong XDP: truyền kiểu số / `d`, không truyền chuỗi đã định dạng.
5. `ZCL_GEN_ADOBE->call_data / print_pdf` → `zcl_ads_pdf_renderer=>create( )->render( )` + `CATCH zcx_ads_pdf`.
6. In print queue trong RAP: tách 2 bước (bài 8).
