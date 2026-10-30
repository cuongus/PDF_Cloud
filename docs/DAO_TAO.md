# Đào tạo: in PDF bằng package ZPK_ADS_PDF

Tài liệu dành cho lập trình viên ABAP Cloud cần in chứng từ ra PDF từ template thiết kế bằng **Adobe LiveCycle Designer**.
Mọi ví dụ đều có trong class **`ZCL_ADS_PDF_DEMO`** (bài 0–9) và đã chạy thật với Adobe Document Services (ADS) ngày 30/10/2026.

**Mục lục**

1. [In PDF đầu tiên trong 5 phút](#1-in-pdf-đầu-tiên-trong-5-phút)
2. [Cơ chế hoạt động](#2-cơ-chế-hoạt-động)
3. [Quy trình in một chứng từ từ đầu đến cuối](#3-quy-trình-in-một-chứng-từ-từ-đầu-đến-cuối)
4. [Ba cách dựng XML dữ liệu](#4-ba-cách-dựng-xml-dữ-liệu)
5. [FDP – lấy dữ liệu và XSD từ service definition](#5-fdp--lấy-dữ-liệu-và-xsd-từ-service-definition)
6. [Dùng PDF sau khi sinh: trả về Fiori, lưu, in máy in](#6-dùng-pdf-sau-khi-sinh)
7. [Tra cứu API](#7-tra-cứu-api)
8. [Lỗi thường gặp và cách đọc trace ADS](#8-lỗi-thường-gặp-và-cách-đọc-trace-ads)
9. [Class demo ZCL_ADS_PDF_DEMO](#9-class-demo-zcl_ads_pdf_demo)
10. [Chuyển chương trình in cũ sang bộ mới](#10-chuyển-chương-trình-in-cũ-sang-bộ-mới)

---

## 1. In PDF đầu tiên trong 5 phút

Mở `ZCL_ADS_PDF_DEMO` trong Eclipse ADT → **F9**. Bài 0 chạy được ở mọi client vì template nằm sẵn trong code.
Rút gọn lại, toàn bộ việc in là **3 bước**:

```abap
" 1. Dữ liệu -> XML (tên thẻ = tên subform/field trong template)
DATA(lo_xml) = zcl_ads_pdf_xml=>create( `Form` ).
lo_xml->open( `Invoice` ).
lo_xml->add( iv_name = `InvoiceNo`   iv_value = `HD0000` ).
lo_xml->add( iv_name = `InvoiceDate` iv_value = `20261030` ).
lo_xml->add( iv_name = `SellerName`  iv_value = `CÔNG TY TNHH ABC (DEMO)` ).
lo_xml->open( `_Item` )->open( `InvoiceItem` ).
lo_xml->add_number( iv_name = `ItemNo`   iv_value = 10 ).
lo_xml->add( iv_name = `Description` iv_value = `Bàn làm việc` ).
lo_xml->add_number( iv_name = `Quantity` iv_value = 1 ).
lo_xml->add_number( iv_name = `Amount`   iv_value = 500000 ).
lo_xml->close( )->close( ).
lo_xml->add_number( iv_name = `TotalAmount` iv_value = 500000 ).

TRY.
    " 2. XML + template -> PDF
    DATA(ls_pdf) = zcl_ads_pdf_renderer=>create( )->render_single(
                     iv_template_id = `ZDEMO_INVOICE`
                     iv_xml         = lo_xml->to_xstring( ) ).
    " 3. Dùng kết quả
    "    ls_pdf-pdf        : PDF (xstring)  -> attachment, trả về Fiori
    "    ls_pdf-pdf_base64 : PDF (base64)   -> trả qua API / JSON
    "    ls_pdf-pages      : số trang
  CATCH zcx_ads_pdf INTO DATA(lx_pdf).
    " lx_pdf->get_text( )
ENDTRY.
```

Kết quả thật: [`docs/samples/bai0_hello.pdf`](samples/bai0_hello.pdf), template: [`docs/samples/demo_invoice.xdp`](samples/demo_invoice.xdp).

> Trong bài 0 template lấy từ nguồn "inline" (`create( io_template_source = NEW lcl_inline_source( ) )`).
> Dự án thật dùng `create( )` – template upload vào bảng `ZADS_A_TEMPLATE` qua app (mục 3, bước 1).

---

## 2. Cơ chế hoạt động

### 2.1 Ba thành phần tạo nên một PDF

```
 ┌────────────────────────┐   ┌────────────────────────┐
 │ TEMPLATE  (.xdp)       │   │ DỮ LIỆU  (XML)          │
 │ thiết kế bằng LiveCycle │   │ sinh bằng ABAP          │
 │ - bố cục, font, logo   │   │ <Form>                  │
 │ - subform, field       │   │   <Invoice>             │
 │ - cách hiển thị số/ngày │   │     <InvoiceNo>HD0001   │
 └───────────┬────────────┘   └───────────┬────────────┘
             └──────────────┬─────────────┘
                            ▼
              Adobe Document Services (ADS)
              ghép dữ liệu vào field theo TÊN
                            ▼
                   PDF  (hoặc PCL/ZPL cho máy in)
```

ADS là dịch vụ SAP chạy sẵn trong S/4HANA Cloud. ABAP gọi nó qua API đã release `CL_FP_ADS_UTIL`
(package bọc lại trong `ZCL_ADS_PDF_ENGINE`).

### 2.2 Ghép dữ liệu theo tên (data binding)

Template XDP là một cây **subform** (vùng/khối) và **field** (ô dữ liệu). ADS đi song song cây XDP và cây XML,
ghép phần tử XML vào field **cùng tên, cùng vị trí**. Ví dụ với template hoá đơn mẫu:

| Trong template (XDP) | Trong dữ liệu (XML) | Ghi chú |
|---|---|---|
| `<subform name="Form">` (gốc) | `<Form>` | thẻ gốc XML = subform gốc |
| `<subform name="Invoice">` | `<Invoice>` | |
| `<field name="InvoiceNo">` | `<InvoiceNo>HD0001</InvoiceNo>` | text |
| `<field name="InvoiceDate">` | `<InvoiceDate>20261030</InvoiceDate>` | ngày, xem 2.3 |
| `<subform name="_Item">` | `<_Item>` | |
| `<subform name="InvoiceItem">` + `<occur max="-1"/>` | nhiều `<InvoiceItem>` liên tiếp | **subform lặp**: mỗi phần tử XML sinh một dòng |
| `<draw name="Title">` | – | chữ cố định, không nhận dữ liệu |

Quy tắc cần nhớ:

- Tên **phân biệt hoa thường** và phải đúng cấp. Sai tên → ADS **không báo lỗi**, field in ra trống.
- Subform **không đặt tên** trong LiveCycle là "trong suốt" – XML không có cấp tương ứng.
- Field có *Binding = None* (`<bind match="none"/>`) không nhận dữ liệu.
- Muốn biết template cần XML thế nào: chạy `zcl_ads_pdf_xdp_parser=>create( xdp )->get_field_paths( )` (bài 1).

### 2.3 Kiểu dữ liệu: dạng dữ liệu (data pattern) và dạng hiển thị (display pattern)

Mỗi field trong LiveCycle có thể khai hai "pattern":

```xml
<field name="InvoiceDate">
  <ui><dateTimeEdit/></ui>
  <format><picture>date{DD/MM/YYYY}</picture></format>          <!-- hiển thị: 30/10/2026 -->
  <bind match="once"><picture>date{YYYYMMDD}</picture></bind>   <!-- dữ liệu nhận vào: 20261030 -->
</field>
<field name="Amount">
  <ui><numericEdit/></ui>
  <value><decimal fracDigits="0"/></value>
  <format><picture>num{zzz,zzz,zzz,zz9}</picture></format>       <!-- hiển thị: 1.650.000 -->
</field>
```

- **XML phải đúng *dạng dữ liệu*** của field. ADS tự đổi sang *dạng hiển thị*.
- Field **số** (numericEdit) chỉ nhận số thô `1650000`, `24350.5`. Gửi chuỗi đã định dạng `24.350,5` → ADS lỗi
  `29216 : Invalid value ... for 'float' property` (bài 6b).
- Dấu chấm/phẩy khi hiển thị theo **locale** truyền cho ADS (mặc định `de_DE`: `.` hàng nghìn, `,` thập phân – giống Việt Nam).
- Field **text** in nguyên chuỗi → muốn hiện `1.650.000` thì tự định dạng (`zcl_ads_pdf_xml=>format_amount_vn`).

### 2.4 Bên trong package khi gọi `render`

```
render( template_id, documents[], logos[], locale )
 │
 ├─ 1. get_template ─► nguồn template (bảng ZADS_A_TEMPLATE | object Form | nguồn tự viết)
 │                     đọc 1 lần, giữ trong instance; báo lỗi nếu không có / là ảnh
 ├─ 2. load_logos  ─► đọc mọi ảnh logo 1 lần, mã hoá base64 1 lần mỗi ảnh
 ├─ 3. với từng XML trong documents[]:
 │       chèn logo vào <LOGO/> (nếu có) ─► ZCL_ADS_PDF_ENGINE->render_pdf ─► ADS
 │       lỗi ở tài liệu n -> dừng, báo "Tài liệu n: ..." + trace ADS
 ├─ 4. ZCL_ADS_PDF_ENGINE->merge  (1 tài liệu: không gộp)
 └─ 5. trả PDF, base64 (trừ khi skip_base64), số trang, số tài liệu
```

| Class | Vai trò | Bạn có gọi trực tiếp? |
|---|---|---|
| `ZCL_ADS_PDF_RENDERER` | API chính: lấy template, chèn logo, gọi ADS, gộp, print queue | **Có** |
| `ZCL_ADS_PDF_XML` | Dựng XML từng thẻ, tự escape, định dạng ngày/số VN | **Có** (cách A) |
| `ZCL_ADS_PDF_XDP_PARSER` | Đọc field của XDP; sinh XML từ cấu trúc ABAP | **Có** (cách B) |
| `ZCL_ADS_PDF_FDP` | Sinh XML + XSD từ service definition | **Có** (cách C) |
| `ZCX_ADS_PDF` | Exception duy nhất: text, mã template, trace ADS | **Có** (CATCH) |
| `ZCL_ADS_PDF_ENGINE` | Gọi ADS / gộp PDF | Không |
| `ZCL_ADS_PDF_TEMPLATE_DB` / `_FORM` | Đọc template từ bảng / object Form | Không (renderer tự dùng) |

---

## 3. Quy trình in một chứng từ từ đầu đến cuối

### Bước 1 – Có template

| Trường hợp | Làm gì |
|---|---|
| Đã có file `.xdp` thiết kế sẵn | Upload qua app service `ZUI_ADS_TEMPLATE_O4`: mã **chữ hoa** (vd `ZPHIEUTHU`), mô tả, file. Làm ở **từng client** in |
| Thiết kế form mới | Đi theo FDP (mục 5): CDS → XSD → LiveCycle → upload |
| Muốn template đi theo transport | Tạo object *Form* trong ADT, dùng `zcl_ads_pdf_renderer=>create_for_forms( )` |

App tự kiểm tra: mã trùng, file rỗng, kiểu file (chỉ XDP/PNG/JPEG/BMP), tự tăng `TemplateVersion` mỗi lần thay file.

### Bước 2 – Xem template cần dữ liệu gì

```abap
DATA(lo_parser) = zcl_ads_pdf_xdp_parser=>create( lv_xdp ).
lo_parser->get_field_paths( ).       " Form/Invoice/InvoiceNo, Form/Invoice/_Item/InvoiceItem/Amount ...
lo_parser->get_explicit_bindings( ). " field bind tường minh (dataRef) – không ghép theo tên
```

Đồng thời mở file trong LiveCycle xem field nào là **số / ngày** và pattern của nó (mục 2.3).

### Bước 3 – Dựng XML (chọn 1 trong 3 cách, mục 4)

### Bước 4 – Gọi renderer

```abap
DATA(lo_renderer) = zcl_ads_pdf_renderer=>create( ).
" 1 chứng từ
DATA(ls_pdf) = lo_renderer->render_single( iv_template_id = `ZPHIEUTHU` iv_xml = lv_xml ).
" hoặc nhiều chứng từ -> 1 PDF
DATA(ls_pdf) = lo_renderer->render( VALUE #( template_id = `ZPHIEUTHU`
                                             documents   = lt_xml          " 1 dòng = 1 chứng từ
                                             skip_base64 = abap_true ) ).
```

### Bước 5 – Dùng PDF (mục 6) và bắt lỗi `ZCX_ADS_PDF` (mục 8)

---

## 4. Ba cách dựng XML dữ liệu

| | A. `ZCL_ADS_PDF_XML` | B. `ZCL_ADS_PDF_XDP_PARSER` | C. `ZCL_ADS_PDF_FDP` |
|---|---|---|---|
| Ý tưởng | Viết từng thẻ: `open / add / close` | Khai cấu trúc ABAP giống cây field, parser tự sinh XML | Mô tả dữ liệu bằng CDS, SAP sinh XML |
| Hợp với | Form có sẵn, dữ liệu khác xa cấu trúc form, form nhiều liên | Form có sẵn, bind theo tên, nhiều field | **Form thiết kế mới** |
| Bài demo | 0, 3 | 2, 4, 5 | 9 |

### A. Tự dựng từng thẻ

```abap
DATA(lo_xml) = zcl_ads_pdf_xml=>create( `form1` ).          " thẻ gốc = subform gốc
LOOP AT VALUE string_table( ( `main` ) ( `main_1` ) ) INTO DATA(lv_copy).   " form 2 liên giống nhau
  lo_xml->open( lv_copy )->open( `HeaderSection` ).
  lo_xml->add( iv_name = `CompanyName` iv_value = ls_head-company ).
  lo_xml->add( iv_name = `PostingDate` iv_value = zcl_ads_pdf_xml=>format_date_vn( ls_head-budat ) ).
  lo_xml->close( ).
  lo_xml->add( iv_name  = `sotien`      " field TEXT: tự định dạng, tiền tệ tự dịch thập phân
               iv_value = zcl_ads_pdf_xml=>format_currency_vn( iv_amount = ls_head-amount iv_currency = `VND` ) ).
  lo_xml->close( ).
ENDLOOP.
DATA(lv_xml) = lo_xml->to_xstring( ).                        " tự đóng mọi thẻ còn mở
```

| Method | Ghi chú |
|---|---|
| `add( name, value )` | text; `& < >` tự escape, ký tự điều khiển bị loại |
| `add_number( name, value )` | số RAW cho field số |
| `add_date( name, date )` | `YYYY-MM-DD` (khi field khai data pattern ISO) |
| `add_amount( name, amount, currency )` | số RAW đã dịch thập phân theo tiền tệ (VND/JPY: ×100) |
| `format_date_vn`, `format_amount_vn`, `format_currency_vn` | chuỗi kiểu VN cho field **text** |

### B. Từ cấu trúc ABAP

```abap
" Template: Form/Main/Header/{Date,Shipper}, Form/Main/Table/ContainerParticular(lặp)/Line/{...}
TYPES: BEGIN OF ty_line,  stt TYPE i, containerno TYPE string,
                           verifiedgweight TYPE p LENGTH 10 DECIMALS 1,   " field số -> kiểu số
       END OF ty_line,
       BEGIN OF ty_particular, line TYPE ty_line, END OF ty_particular,
       BEGIN OF ty_table, containerparticular TYPE STANDARD TABLE OF ty_particular WITH EMPTY KEY, END OF ty_table,
       BEGIN OF ty_header, date TYPE string, shipper TYPE string, END OF ty_header,
       BEGIN OF ty_main,  header TYPE ty_header, table TYPE ty_table, END OF ty_main,
       BEGIN OF ty_form,  main TYPE ty_main, END OF ty_form.

DATA(lo_parser) = zcl_ads_pdf_xdp_parser=>create( lv_xdp ).     " parse 1 lần
DATA(lv_xml) = lo_parser->build_xml( is_data  = ls_form
                                     it_alias = VALUE #( ( xdp_name = `Createby` abap_name = `CREATED_BY` ) ) ).
```

- Tên thành phần ABAP = tên field XDP (không phân biệt hoa thường); khác tên → `it_alias`.
- Bảng nội bộ → subform lặp; `xstring` → base64 (field ảnh); `d` → `YYYY-MM-DD`; số → RAW; `abap_bool` → 1/0 (checkbox).
- Thành phần không có trong cấu trúc → field để trống.

---

## 5. FDP – lấy dữ liệu và XSD từ service definition

### 5.1 FDP giải quyết vấn đề gì

Với cách A và B, lập trình viên phải **tự giữ tên khớp** giữa XML và form. FDP (Form Data Provider – SAP gọi là
*RAP Data Services for Print Forms*) đảo ngược thứ tự:

```
  ① Mô tả dữ liệu bằng CDS + service definition
        │
        ├──► ② get_xsd( )   XSD  ──►  LiveCycle: tạo Data Connection, KÉO field ra form  (thiết kế, 1 lần)
        │
        └──► ③ read_xml( khoá ) XML ──► renderer ──► PDF                                  (lúc in)
```

Form được dựng **từ** XSD nên tên luôn khớp XML; không viết dòng code dựng XML nào.

### 5.2 Ví dụ đầy đủ trong package (bài 9 – chạy được ở mọi client)

**① CDS và service definition** (dữ liệu giả lập là hằng số, không cần bảng):

```
ZI_ADS_DEMO_INVOICE   (root)            key InvoiceNo, InvoiceDate, SellerName, BuyerName, TotalAmount
   └─ association _Item [0..*]  ──►  ZI_ADS_DEMO_INVOICEITEM   key InvoiceNo, key ItemNo, Description, Quantity, Amount
```

```
define service ZUI_ADS_DEMO_FDP {
  expose ZI_ADS_DEMO_INVOICE     as Invoice;
  expose ZI_ADS_DEMO_INVOICEITEM as InvoiceItem;
}
```

Không cần service binding. FDP đi từ entity gốc theo association (tối đa 5 cấp) để lồng dữ liệu con.

**② XSD** (`lo_fdp->get_xsd( )`, rút gọn) – cấu trúc dữ liệu mà form sẽ nhận:

```xml
<element name="Form">                       <!-- gốc luôn là Form -->
  <element name="Invoice" type="Invoice"/>  <!-- tên expose của root -->
</element>
<complexType name="Invoice">
  <element name="InvoiceNo"> ... maxLength 10
  <element name="InvoiceDate"> ...          <!-- ngày: chuỗi YYYYMMDD -->
  <element name="TotalAmount"> ...
  <element name="_Item">                    <!-- tên association -->
    <element name="InvoiceItem" minOccurs="0" maxOccurs="unbounded"/>   <!-- tên expose của entity con, lặp -->
  </element>
</complexType>
```

**③ XML lúc in** (`lo_fdp->read_xml( VALUE #( ( name = `InvoiceNo` value = `HD0001` ) ) )`) – lấy thật từ hệ:

```xml
<Form version="2">
  <Invoice>
    <InvoiceNo>HD0001</InvoiceNo>
    <InvoiceDate>20261030</InvoiceDate>
    <SellerName>CÔNG TY TNHH ABC (DEMO)</SellerName>
    <BuyerName>Công ty TNHH XYZ (DEMO)</BuyerName>
    <TotalAmount>1650000 </TotalAmount>
    <_Item>
      <InvoiceItem><InvoiceNo>HD0001</InvoiceNo><ItemNo>10 </ItemNo><Description>Bàn làm việc (DEMO)</Description><Quantity>2 </Quantity><Amount>500000 </Amount></InvoiceItem>
      <InvoiceItem>... ItemNo 20 ...</InvoiceItem>
      <InvoiceItem>... <Description>Phí vận chuyển &amp; lắp đặt</Description> ...</InvoiceItem>
    </_Item>
  </Invoice>
</Form>
```

**④ Render** với template thiết kế theo XSD → [`docs/samples/bai9_fdp.pdf`](samples/bai9_fdp.pdf)
(ngày hiện `30/10/2026`, số `1.650.000`, 3 dòng hàng).

### 5.3 Quy tắc tên trong XML do FDP sinh ra

| Nguồn | Thành thẻ XML |
|---|---|
| (cố định) | `<Form>` gốc |
| Tên **expose** của entity gốc trong service definition | `<Invoice>` |
| Tên field (alias) trong CDS | `<InvoiceNo>`, `<TotalAmount>` … |
| Tên **association** | `<_Item>` (thẻ bao) |
| Tên **expose** của entity đích | `<InvoiceItem>` lặp lại, mỗi dòng một thẻ |

Định dạng dữ liệu (quan sát trên hệ): ngày `YYYYMMDD`; số dạng thô, có thể có dấu cách cuối (`1650000 `) – ADS đọc
được; `&` được escape một lần. Vì vậy trong LiveCycle khai field ngày với data pattern `date{YYYYMMDD}`.

> Console ADT (F9) hiển thị `&amp;` thành `&amp;amp;` – đó là cách console in ra, dữ liệu thật chỉ escape một lần.

### 5.4 Thiết kế form trong LiveCycle từ XSD

1. Chạy `get_xsd( )`, lưu kết quả ra file `invoice.xsd` (vd đặt breakpoint/ghi ra console rồi lưu).
2. LiveCycle: *File → New Data Connection → XML Schema* → chọn `invoice.xsd`; tick *Embed XML Schema*.
3. Tab *Data View* hiện cây `Form > Invoice > …`; **kéo** từng phần tử ra trang → field tự bind đúng đường dẫn.
4. Kéo `InvoiceItem` → LiveCycle tạo subform lặp (*Repeat Subform for Each Data Item*).
5. Field ngày: *Object → Field → Patterns → Data*: `date{YYYYMMDD}`; *Display*: `date{DD/MM/YYYY}`.
6. Field tiền: kiểu Numeric, *Display pattern* `num{zzz,zzz,zzz,zz9}`.
7. *Save As* → Adobe XML Form (`.xdp`) → upload vào app với mã, vd `ZJE_PRINT`.

### 5.5 Code lúc in

```abap
TRY.
    DATA(lo_fdp) = zcl_ads_pdf_fdp=>create( `ZUI_ADS_DEMO_FDP` ).
    DATA(lv_xml) = lo_fdp->read_xml( VALUE #( ( name = `InvoiceNo` value = lv_invoice_no ) ) ).
    DATA(ls_pdf) = zcl_ads_pdf_renderer=>create( )->render_single( iv_template_id = `ZDEMO_INVOICE`
                                                                   iv_xml         = lv_xml ).
  CATCH zcx_ads_pdf INTO DATA(lx).
    " thiếu khoá -> "Thiếu giá trị khoá INVOICENO ..."
ENDTRY.
```

- `get_key_names( )` cho biết phải truyền khoá nào (tên khoá không phân biệt hoa thường).
- Mỗi `read_xml` = **một** chứng từ; nhiều chứng từ → gọi nhiều lần rồi đưa vào `documents` của `render`.
- Dữ liệu đọc theo quyền của CDS (access control) như mọi truy cập CDS khác.

### 5.6 FDP trên custom entity – dữ liệu từ class query

Khi dữ liệu cần logic ABAP (gom nhóm, tính toán, đọc nhiều nguồn, gọi API), dùng **custom entity**:
FDP gọi class query (`if_rap_query_provider`) thay vì đọc bảng/CDS. Đã chạy thật (bài 9 phần B):

```
ZI_ADS_DEMO_ORDER_CE (root custom entity) ──_Line──► ZI_ADS_DEMO_ORDERLINE_CE (custom entity)
        @ObjectModel.query.implementedBy: 'ABAP:ZCL_ADS_DEMO_CE_QUERY'  (cả hai entity)

define service ZUI_ADS_DEMO_FDP_CE {
  expose ZI_ADS_DEMO_ORDER_CE     as SalesOrder;
  expose ZI_ADS_DEMO_ORDERLINE_CE as SalesOrderLine;
}
```

FDP gọi class query **hai lần**:

| Lần | `io_request->get_entity_id( )` | Filter nhận được | Class trả về |
|---|---|---|---|
| 1 | `ZI_ADS_DEMO_ORDER_CE` | `OrderNo = 'DH0001'` (khoá truyền vào `read_xml`) | 1 đơn hàng |
| 2 | `ZI_ADS_DEMO_ORDERLINE_CE` | `OrderNo = 'DH0001'` (khoá cha, theo điều kiện association) | các dòng của đơn đó |

XML thu được (rút gọn) – cùng quy tắc tên như CDS thường:

```xml
<Form version="2">
  <SalesOrder>
    <OrderNo>DH0001</OrderNo> <OrderDate>20261030</OrderDate> <Customer>Công ty TNHH XYZ (DEMO)</Customer>
    <QrContent>https://example.com/order/DH0001</QrContent> <TotalAmount>2350000 </TotalAmount>
    <_Line>
      <SalesOrderLine><OrderNo>DH0001</OrderNo><ItemNo>10 </ItemNo><Product>Bàn làm việc</Product>...</SalesOrderLine>
      <SalesOrderLine>... ItemNo 20 ...</SalesOrderLine>
      <SalesOrderLine>... ItemNo 30 ...</SalesOrderLine>
    </_Line>
  </SalesOrder>
</Form>
```

Class query phải (xem `ZCL_ADS_DEMO_CE_QUERY`):

1. Phân biệt entity bằng `io_request->get_entity_id( )` (một class phục vụ nhiều entity được).
2. **Áp filter** `io_request->get_filter( )->get_as_ranges( )` – bắt buộc cho entity con, nếu không FDP nhận dòng của mọi chứng từ.
3. Đọc `get_sort_elements( )`, `get_paging( )` (framework yêu cầu), trả `set_total_number_of_records` khi được hỏi và `set_data` khi `is_data_requested( )`.

Lưu ý:

- Custom entity cũng sinh XSD như CDS thường → thiết kế form trong LiveCycle y hệt mục 5.4.
- Field `QrContent` minh hoạ cho **field QR Code của LiveCycle**: field mã vạch nhận chuỗi, ADS tự vẽ QR – không cần ảnh.
  [Chưa kiểm chứng] chưa render thử template có field QR Code trên hệ này.
- Tên field CDS tránh từ khoá (vd `LineNo` không dùng được → `ItemNo`).
- Quyền: custom entity không có access control tự động – nếu cần thì kiểm tra quyền trong class query.

---

## 6. Dùng PDF sau khi sinh

### 6.1 Trả file về app Fiori (RAP action)

Mẫu theo các chương trình in đang có (action có result là abstract entity chứa file):

```abap
METHOD printpdf.                         " action printPdf result [1] <abstract entity file>
  READ ENTITIES OF zr_my_doc IN LOCAL MODE ENTITY Doc ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_doc).
  DATA(lo_renderer) = zcl_ads_pdf_renderer=>create( ).
  LOOP AT lt_doc INTO DATA(ls_doc).
    TRY.
        DATA(ls_pdf) = lo_renderer->render_single( iv_template_id = `ZMY_FORM`
                                                   iv_xml         = build_xml( ls_doc ) ).
        APPEND VALUE #( %tky   = ls_doc-%tky
                        %param = VALUE #( filecontent   = ls_pdf-pdf
                                          filename      = |{ ls_doc-DocNo }.pdf|
                                          fileextension = 'pdf'
                                          mimetype      = 'application/pdf' ) ) TO result.
      CATCH zcx_ads_pdf INTO DATA(lx).
        APPEND VALUE #( %tky = ls_doc-%tky ) TO failed-doc.
        APPEND VALUE #( %tky = ls_doc-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = lx->get_text( ) ) ) TO reported-doc.
    ENDTRY.
  ENDLOOP.
ENDMETHOD.
```

### 6.2 Trả qua HTTP service / API

Dùng `ls_pdf-pdf_base64`. Với PDF lớn mà không cần base64 → `skip_base64 = abap_true`.

### 6.3 In ra máy in (print queue)

```abap
" Ngoài RAP (report, job, HTTP service)
lo_renderer->render_to_print_queue( iv_template_id = `ZPHIEUKETOAN` iv_xml = lv_xml
                                    iv_queue_name = 'DEFAULT' iv_document_name = `PKT_100001` ).
COMMIT WORK.

" Trong RAP: tách 2 bước
"   action/determination: gọi ADS
DATA(ls_pdl) = lo_renderer->render_for_print_queue( iv_template_id = `ZPHIEUKETOAN`
                                                    iv_xml = lv_xml iv_queue_name = 'DEFAULT' ).
"   saver - save_modified (late save): tạo item, item id tạo trước
zcl_ads_pdf_renderer=>add_to_print_queue( is_output        = ls_pdl
                                          iv_queue_name    = 'DEFAULT'
                                          iv_document_name = `PKT_100001`
                                          iv_item_id       = cl_print_queue_utils=>create_queue_itemid( ) ).
```

ADS tự sinh đúng định dạng máy in của queue (PDF/PCL/ZPL…). Danh sách queue: `cl_print_queue_utils=>get_pqname_list( )`.

---

## 7. Tra cứu API

### ZCL_ADS_PDF_RENDERER

| Method | Tham số chính | Trả về |
|---|---|---|
| `create( )` (static) | `io_template_source`, `io_image_source`, `io_engine` (tuỳ chọn) | renderer, template từ bảng `ZADS_A_TEMPLATE` |
| `create_for_forms( )` (static) | – | renderer, layout từ object Form ADT |
| `render( is_request )` | `template_id`, `documents` (bảng xstring), `locale`, `logos`, `logo_tag`, `trace_level`, `skip_base64` | `pdf`, `pdf_base64`, `pages`, `documents`, `template_version` |
| `render_single( )` | `iv_template_id`, `iv_xml`, `iv_locale` | như `render` |
| `render_for_print_queue( )` | template, xml, `iv_queue_name`, locale | `data` (PDL), `pages` |
| `add_to_print_queue( )` (static) | `is_output`, queue, tên tài liệu, số bản, item id | item id |
| `render_to_print_queue( )` | template, xml, queue, tên tài liệu, số bản | item id |

### ZCX_ADS_PDF

`get_text( )` – mô tả (có "Tài liệu n:" nếu lỗi ở tài liệu thứ n) · `mv_template_id` · `mv_trace` – trace ADS đầy đủ · `previous` – exception gốc của SAP.

### ZCL_ADS_PDF_XDP_PARSER

`create( xdp )` · `get_field_paths( )` · `get_explicit_bindings( )` · `build_xml( is_data, it_alias )`.

### ZCL_ADS_PDF_FDP

`create( service_definition )` · `get_key_names( )` · `get_xsd( )` · `read_xml( it_key, iv_language )`.

---

## 8. Lỗi thường gặp và cách đọc trace ADS

| Hiện tượng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `Không tìm thấy template X` | Chưa upload ở client này / sai mã | Upload qua app (mã chữ hoa) |
| `X là ảnh (...), không phải layout XDP` | Dùng nhầm mã ảnh làm template | Kiểm tra mã |
| `ADS error` + trace có `29216 : Invalid value '...' for 'float'` | Field số nhận chuỗi đã định dạng | Truyền số RAW (mục 2.3) |
| PDF ra nhưng field trống | Tên thẻ XML không khớp / sai cấp | So với `get_field_paths( )`; xem `get_explicit_bindings( )` |
| Ngày hiện sai / trống | XML không đúng data pattern của field | Khai `date{YYYYMMDD}` hoặc gửi đúng định dạng field yêu cầu |
| Lỗi tiếng Việt / ô vuông | Font không có trên ADS | Upload font qua app *Adobe Document Services Configuration*, bật nhúng font |
| `Thiếu giá trị khoá ...` (FDP) | Thiếu khoá root khi `read_xml` | Xem `get_key_names( )` |

Đọc trace: lỗi từ ADS có `lx->mv_trace` (văn bản nhiều dòng). Tìm dòng chứa `Exception` / `Error`;
bài 6 có hàm `log_trace_errors` làm đúng việc này. Cần trace chi tiết hơn → `render( … trace_level = 1..4 )`.

---

## 9. Class demo ZCL_ADS_PDF_DEMO

Chạy: mở class trong ADT → **F9**. Bài thiếu template ở client đang chạy tự bỏ qua và ghi lý do.
Template mẫu của bài 1–8 nằm ở bảng cũ `ZCORE_TB_TEMPPDF` (client 100 có đủ). Bài 0 và 9 chạy ở **mọi** client.

| Bài | Nội dung | Template | Kết quả (client 100) |
|---|---|---|---|
| 0 | Hello PDF – dựng XML, render 1 lệnh | ZDEMO_INVOICE (inline) | 1 trang |
| 1 | Khám phá field của template | FormVGMCasa | 7 field |
| 2 | XML từ cấu trúc ABAP, field số | FormVGMCasa | 1 trang |
| 3 | Dựng XML thủ công, 2 liên, tiền VND | zphieuthu | 1 trang; 15000.00 nội bộ → 1.500.000 |
| 4 | 3 chứng từ → 1 PDF, alias, skip_base64 | zphieuketoan | 3 trang |
| 5 | 4 tem trong 1 lần gọi ADS, field ảnh | zbarcode_bin | 1 lần gọi ADS |
| 6 | Lỗi: thiếu template, sai kiểu số, file không phải XDP | – | đọc được trace |
| 7 | Upload template bằng EML rồi render từ bảng mới | FormVGMCasa → ZVGM_DEMO | khi bật `c_write_template_table` |
| 8 | Print queue: render PDL (+ tạo item khi bật `c_create_print_item`) | zphieuketoan | PDL cho queue DEFAULT |
| 9 | FDP: CDS → XSD → XML → PDF; phần B: FDP trên custom entity (class query) | ZUI_ADS_DEMO_FDP + ZDEMO_INVOICE; ZUI_ADS_DEMO_FDP_CE | 1 trang, 3 dòng hàng; XML đơn hàng từ class query |

Hai cờ `c_write_template_table`, `c_create_print_item` mặc định tắt – chạy demo không ghi gì xuống hệ thống.

Object demo đi kèm: `ZI_ADS_DEMO_INVOICE`, `ZI_ADS_DEMO_INVOICEITEM`, `ZUI_ADS_DEMO_FDP` (dữ liệu hằng số);
`ZI_ADS_DEMO_ORDER_CE`, `ZI_ADS_DEMO_ORDERLINE_CE`, `ZCL_ADS_DEMO_CE_QUERY`, `ZUI_ADS_DEMO_FDP_CE` (custom entity);
template mẫu [`docs/samples/demo_invoice.xdp`](samples/demo_invoice.xdp) mở được bằng LiveCycle Designer.

---

## 10. Chuyển chương trình in cũ sang bộ mới

1. Upload XDP vào `ZADS_A_TEMPLATE` (mã chữ hoa) ở từng client.
2. Chạy `get_field_paths( )` → danh sách field; mở XDP xem field số/ngày và pattern.
3. Thay đoạn ghép chuỗi XML + `REPLACE ALL OCCURRENCES OF '&'` bằng cách A hoặc B (mục 4).
4. Field số/ngày: truyền kiểu số / đúng data pattern – không truyền chuỗi đã định dạng.
5. `ZCL_GEN_ADOBE->call_data / print_pdf` → `zcl_ads_pdf_renderer=>create( )->render( … )` + `CATCH zcx_ads_pdf`.
6. In máy in trong RAP: tách `render_for_print_queue` / `add_to_print_queue` (mục 6.3).

### Phụ lục – template hiện có (client 100, khảo sát 30/10/2026)

- Bảng `ZCORE_TB_TEMPPDF`: 90 bản ghi = 67 XDP + 21 Excel + 2 ảnh; parser đọc được cả 67 XDP.
- Phần lớn bind theo tên; `zwclabel` bind tường minh (dataRef) toàn bộ.
- Nhiều template đặt tên field mặc định (`TextField1`, `Cell2`…) → nên đổi tên khi chuyển sang bộ mới.
- Không template nào có field `LOGO` (logo vẽ cố định trong XDP).
