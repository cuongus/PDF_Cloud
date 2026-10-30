@EndUserText.label: 'Demo FDP - file kết quả (base64)'
define abstract entity ZD_DEMO_ADS_PDF_FILE
{
  FileName    : abap.char(120);
  MimeType    : abap.char(60);
  FileContent : abap.string(0);
}
