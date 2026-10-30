/*=====================================================================
 Tên/Mã     : ZC_ADS_TEMPLATETP
 Mô tả chung: Projection (UI) quản lý template ADS: upload XDP / ảnh logo
 Tác giả    : CB9980000013 - CuongUS
 Ngày tạo   : 30/10/2026
 Package    : ZPK_ADS_PDF
=====================================================================
 Version  Ngày        Người sửa              Transport   Mô tả
 1.0      30/10/2026  CB9980000013 - CuongUS AK3K908751  Tạo mới
=====================================================================*/
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ADS PDF template'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: { typeName: 'Template',
                  typeNamePlural: 'Templates',
                  title: { type: #STANDARD, value: 'TemplateId' },
                  description: { type: #STANDARD, value: 'Description' } }
@UI.presentationVariant: [{ sortOrder: [{ by: 'TemplateId', direction: #ASC }] }]
define root view entity ZC_ADS_TEMPLATETP
  provider contract transactional_query
  as projection on ZR_ADS_TEMPLATETP
{
      @UI.facet: [{ id: 'General', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                    label: 'Thông tin chung', position: 10 }]
      @UI.selectionField: [{ position: 10 }]
      @UI.lineItem: [{ position: 10 }]
      @UI.identification: [{ position: 10 }]
      @EndUserText.label: 'Mã template'
  key TemplateId,
      @UI.selectionField: [{ position: 20 }]
      @UI.lineItem: [{ position: 20 }]
      @UI.identification: [{ position: 20 }]
      @EndUserText.label: 'Mô tả'
      Description,
      @UI.identification: [{ position: 30 }]
      @EndUserText.label: 'File template'
      //ignorePropagatedAnnotations: khai lại large object để có nút upload/tải
      @Semantics.largeObject: { mimeType: 'MimeType',
                                fileName: 'FileName',
                                acceptableMimeTypes: [ 'application/vnd.adobe.xdp+xml',
                                                       'application/vnd.xdp',
                                                       'application/xml',
                                                       'text/xml',
                                                       'application/octet-stream',
                                                       'image/png',
                                                       'image/jpeg',
                                                       'image/bmp' ],
                                contentDispositionPreference: #ATTACHMENT }
      FileContent,
      @UI.lineItem: [{ position: 30 }]
      @UI.identification: [{ position: 40 }]
      @EndUserText.label: 'Kiểu file'
      @Semantics.mimeType: true
      MimeType,
      @UI.lineItem: [{ position: 40 }]
      @UI.identification: [{ position: 50 }]
      @EndUserText.label: 'Tên file'
      FileName,
      @UI.lineItem: [{ position: 50 }]
      @UI.identification: [{ position: 60 }]
      @EndUserText.label: 'Phiên bản'
      TemplateVersion,
      @UI.identification: [{ position: 70 }]
      CreatedBy,
      @UI.identification: [{ position: 80 }]
      CreatedAt,
      @UI.lineItem: [{ position: 60 }]
      @UI.identification: [{ position: 90 }]
      LastChangedBy,
      @UI.lineItem: [{ position: 70 }]
      @UI.identification: [{ position: 100 }]
      LastChangedAt,
      LocalLastChangedAt
}
