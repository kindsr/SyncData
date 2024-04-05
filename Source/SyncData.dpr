program SyncData;
uses
  Forms,
  uCommandsClass in 'uCommandsClass.pas',
  uCommon in 'uCommon.pas',
  uFilterClass in 'uFilterClass.pas',
  uFrmFilters in 'uFrmFilters.pas' {frmExtensions},
  Vcl.Themes,
  Vcl.Styles,
  System.SysUtils,
  uLangs in 'uLangs.pas',
  RCPopupMenu in 'RCPopupMenu.pas',
  uFrmCommandConfig in 'uFrmCommandConfig.pas' {frmCommandConfig: TFrame},
  uFrmConfig in 'uFrmConfig.pas' {frmConfig};

{$R *.res}
begin
  Application.Initialize;
  Application.CreateForm(TfrmExtensions, frmExtensions);
  Application.CreateForm(TfrmConfig, frmConfig);
  Application.ShowMainForm := False;

  GenDefaultFileLang;

  with frmConfig do
  begin
    cbLangs.ItemIndex := LangFillListAndGetCurrent(cbLangs.Items);
    cbLangsChange(cbLangs);
  end;
  Application.Run;
end.
