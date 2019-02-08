unit progress;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { TProgressForm }

  TProgressForm = class(TForm)
    lbMotion: TLabel;
    lbMessage: TLabel;
    procedure FormHide(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private

  public

  end;

var
  ProgressForm: TProgressForm;

implementation
uses mainunit;
{$R *.lfm}

{ TProgressForm }

procedure TProgressForm.FormHide(Sender: TObject);
begin
  MainForm.Enabled:=true;
end;

procedure TProgressForm.FormShow(Sender: TObject);
begin
  MainForm.Enabled:=false;
end;

end.

