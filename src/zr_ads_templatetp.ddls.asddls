/*=====================================================================
 Tên/Mã     : ZR_ADS_TEMPLATETP
 Mô tả chung: Root view entity cho template ADS (XDP, ảnh logo)
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
define root view entity ZR_ADS_TEMPLATETP
  as select from zads_a_template
{
  key template_id           as TemplateId,
      description           as Description,
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
      file_content          as FileContent,
      @Semantics.mimeType: true
      mime_type             as MimeType,
      file_name             as FileName,
      template_version      as TemplateVersion,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt
}
