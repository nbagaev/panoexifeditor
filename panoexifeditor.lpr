program panoexifeditor;

{$mode objfpc}{$H+}
{$define UseCThreads}
uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, mainunit, resizeimage, progress, imgloadthread, _FPReadTiff
  { you can add units after this };

{$R *.res}

begin
  Application.Title:='Pano Exif Editor';
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TProgressForm, ProgressForm);
  Application.Run;
end.

