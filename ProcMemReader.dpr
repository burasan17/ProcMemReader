program ProcMemReader;

uses
  Vcl.Forms,
  UMain in 'UMain.pas' {FormMain};

// 直接dccでビルドする場合に *.res が無くて失敗するのを避けるため
// {$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
