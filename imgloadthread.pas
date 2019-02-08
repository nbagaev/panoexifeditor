unit imgloadthread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FPimage, FPReadJPEG, FPReadTIFF, StrUtils, resizeimage;

 type

    TImgLoadThread = class(TThread)
    private
      ResizedImage : TFPCompactImgRGB8Bit;
      procedure AssignImage;
    protected
      procedure Execute; override;
    public
      imgPath:String;
      Constructor Create(CreateSuspended : boolean);
    end;

implementation
   uses mainunit;

procedure TImgLoadThread.AssignImage;
begin
  MainForm.Image1.Picture.Assign(ResizedImage);
end;

procedure TImgLoadThread.Execute;
var
  SourceImage : TFPCompactImgRGB8Bit;
  jpegReader: TFPReaderJpeg;
  tiffReader: TFPReaderTiff;
begin
  SourceImage := TFPCompactImgRGB8Bit.Create(0,0);
  ResizedImage := TFPCompactImgRGB8Bit.Create(MainForm.Image1.Width, MainForm.Image1.Height);
  SourceImage.UsePalette := False;
  if (MatchStr(LowerCase(ExtractFileExt(imgPath)), ['.jpg', '.jpeg'])) then
  try
    //load jpg
    jpegReader := TFPReaderJPEG.Create;
    jpegReader.Scale := jsEighth;
    jpegReader.Performance := jpBestSpeed;
    jpegReader.Smoothing := false;
    SourceImage.LoadFromFile(imgPath, jpegReader);
    ResizedImage:=resizeImageFast(SourceImage, MainForm.Image1.Width, MainForm.Image1.Height);
    Synchronize(@AssignImage);
  finally
    jpegReader.Free;
    ResizedImage.Free;
    SourceImage.Free;
  end
  else
  try
    //load tiff
    tiffReader := TFPReaderTiff.Create;
    SourceImage.LoadFromFile(imgPath, tiffReader);
    ResizedImage:=resizeImageSlow(SourceImage, MainForm.Image1.Width, MainForm.Image1.Height);
    Synchronize(@AssignImage);
  finally
    SourceImage.Free;
    ResizedImage.Free;
    tiffReader.Free;
  end;
end;

Constructor TImgLoadThread.Create(CreateSuspended : boolean);
  begin
      FreeOnTerminate := True;
    inherited Create(CreateSuspended);
end;
end.


