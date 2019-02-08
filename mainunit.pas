unit mainunit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, UTF8Process, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, ValEdit, StdCtrls, FPReadTiff, Process, StrUtils, INIFiles, Grids,
  ComCtrls, imgloadthread, progress;

type

  { TMainForm }

  TMainForm = class(TForm)
    btnSelectImage: TButton;
    btnWriteTags: TButton;
    cbStayOnTop: TCheckBox;
    cbLoadImage: TCheckBox;
    Image1: TImage;
    SelectImgDialog: TOpenDialog;
    Panel1: TPanel;
    RunExiftool: TProcessUTF8;
    rbtnNorth: TRadioButton;
    rbtnView: TRadioButton;
    TagEditor: TValueListEditor;
    procedure btnSelectImageClick(Sender: TObject);
    procedure btnWriteTagsClick(Sender: TObject);
    procedure cbStayOnTopChange(Sender: TObject);
    procedure cbLoadImageChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of String);
    procedure Image1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Image1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer
      );
    procedure Image1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Image1Paint(Sender: TObject);
    procedure TagEditorKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    function ReadTags(ImageFile:String):Boolean;
    procedure LoadImage(ImageFile:String);
    procedure SaveMousePos(x,y:Integer);
    function ReadIni(): Boolean;
    procedure WriteTags();
    procedure InitTags();
    procedure Start();
    procedure SetAfterEdit();
    function AllTagsSetted():boolean;
    procedure InitPos();
    procedure UpdatePos();
    procedure imgLoadThreadOnTerminate(ASender : TObject );
    { private declarations }
  public
    { public declarations }
  end;

var
  MainForm: TMainForm;
  north_x,
  view_x : Integer;
  bMouseDown : boolean;
  NorthDirectionTag,
  InitialViewTag,
  ImageFile: String;
  ini:TIniFile;
  TagsToRead,
  TagsToInitAnyway,
  TagsToInitIfNotExists,
  TagsToSetAfterEdit:Tstringlist;
  image_loaded:boolean;
  bLoadImage:boolean;
  bStayOnTop:boolean;
  ExiftoolPath,
  ArgfilePath,
  AppPath:String;
  bImageLoadThreadTerminated:boolean;

implementation

function NorthPosToDeg(x, img_width:Integer): Integer;
begin
  if (x <= img_width / 2) then
    Result := Trunc((img_width / 2 - x) * 360 / img_width)
  else
    Result := Trunc((img_width / 2 + img_width - x) * 360 / img_width);
  if Result = 360 then
    Result := 0
end;

function NorthDegToPos(deg, img_width:Integer): Integer;
begin
  if (deg <= 180) then
     Result := Trunc(img_width / 2 - deg * img_width / 360)
  else
     Result := Trunc((img_width / 2 + img_width - deg * img_width / 360));
end;

function ViewPosToDeg(view_x,north_x,img_width:Integer): Integer;
begin
if view_x > north_x then
    Result:= Trunc((view_x - north_x) * 360 / img_width)
else
    Result:= Trunc((img_width-north_x + view_x) * 360 / img_width);
if Result = 360 then
  Result := 0
end;

function ViewDegToPos(view_deg,north_x,img_width:Integer): Integer;
var offset:Integer;
begin
  //todo
  offset := Trunc(img_width / 360 * view_deg);
  if (north_x + offset) < img_width then
    Result:= north_x + offset
  else
    Result:= north_x + offset - img_width;
end;

{$R *.lfm}

{ TMainForm }

function TMainForm.ReadTags(ImageFile:String): boolean;
var
  sl : TStringList;
  i : Integer;
begin
  Result := true;
  sl := TStringList.Create;
  TagEditor.Clear;
  north_x := 0;
  view_x := 0;
  sl.Add('-charset');
  sl.Add('filename=utf8');
  sl.Add('-S');
  sl.Add('-f');
  sl.Add('-c');
  sl.Add('%+.6f');
  for i := 0 to TagsToRead.Count-1 do
    sl.Add('-' + TagsToRead[i]);
  sl.Add(ImageFile);
  sl.SaveToFile(AppPath + ArgfilePath);
  try
    with RunExiftool do
    begin
      Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];
      ShowWindow := swoHIDE;
      Executable := AppPath + ExiftoolPath;
      Parameters.Clear;
      Parameters.Add('-@');
      Parameters.Add(AppPath + ArgfilePath);
      Execute;
    end;
  finally
    sl.Clear;
    sl.LoadFromStream(RunExiftool.Output);
    if sl.Count=TagsToRead.Count then
    begin
      sl.NameValueSeparator:=':';
      for i := 0 to TagsToRead.Count-1 do
      begin
        TagEditor.Strings.Add(TagsToRead[i] + '=' + Trim(sl.ValueFromIndex[i]));
      end;
    self.Caption := Application.Title + ' - ' + ExtractFileName(ImageFile);
    end
    else
    begin
      //failed to read exif
      ShowMessage('exiftool: ' + sl.Text);
      Result := false;
    end;
    sl.Free;
  end;
end;

function TMainForm.AllTagsSetted():boolean;
var i : Integer;
begin
  Result:=true;
  for i := 0 to TagEditor.Strings.Count - 1 do
  begin
    if (TagEditor.Strings.ValueFromIndex[i]='-') or (TagEditor.Strings.ValueFromIndex[i]='') then
      Result:=false;
  end;
end;

procedure TMainForm.btnSelectImageClick(Sender: TObject);
begin
  if SelectImgDialog.Execute then
  begin
    ImageFile:=SelectImgDialog.FileName;
    Start;
  end;
 end;

procedure TMainForm.Start();
begin
  if ReadTags(ImageFile) then
  begin
    InitTags();
    InitPos();
    if bLoadImage then
      LoadImage(ImageFile);
  end;
end;

procedure TMainForm.WriteTags;
var
  sl : TStringList;
  i : Integer;
begin
  sl := TStringList.Create;
  sl.Add('-charset');
  sl.Add('filename=utf8');
  sl.Add('-overwrite_original');
  sl.Add('-S');
  for i := 0 to TagEditor.Strings.Count - 1 do
    sl.Add('-' + TagEditor.Strings[i]);
  sl.Add(ImageFile);
  sl.SaveToFile(AppPath + ArgfilePath);
  try
    with RunExiftool do
    begin
      Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];
      ShowWindow := swoHIDE;
      Executable := AppPath + ExiftoolPath;
      Parameters.Clear;
      Parameters.Add('-@');
      Parameters.Add(AppPath + ArgfilePath);
      Execute;
    end;
  finally
    sl.Clear;
    sl.LoadFromStream(RunExiftool.Output);
    ShowMessage('exiftool: ' + sl.Text);
    sl.Free;
  end;
end;

procedure TMainForm.InitTags();
var i,pos,pos1:Integer;
begin
  for i := 0 to TagEditor.Strings.Count - 1 do
  begin
    //TagsToInitAnyway
    pos := TagsToInitAnyway.IndexOfName(TagEditor.Strings.Names[i]);
    if pos > -1 then
    begin
      if TagEditor.FindRow(TagsToInitAnyway.ValueFromIndex[pos], pos1) then
      begin
        //if value is a tag
        if Not (TagEditor.Strings.ValueFromIndex[pos1-1]='-') then
          //if source tag exists and filled
          TagEditor.Strings.ValueFromIndex[i]:=TagEditor.Strings.ValueFromIndex[pos1-1]
      end
      else
        //if value is not a tag
        TagEditor.Strings.ValueFromIndex[i]:=TagsToInitAnyway.ValueFromIndex[pos];
    end;
    //TagsToInitIfNotExist
    pos := TagsToInitIfNotExists.IndexOfName(TagEditor.Strings.Names[i]);
    if pos > -1 then
    begin
      if TagEditor.Strings.ValueFromIndex[i]='-' then
        //if dest-tag not filled
        if TagEditor.FindRow(TagsToInitIfNotExists.ValueFromIndex[pos], pos1) then
        begin
          //if value is a tag
          if Not (TagEditor.Strings.ValueFromIndex[pos1-1]='-') then
            //if source-tag exists
            TagEditor.Strings.ValueFromIndex[i]:=TagEditor.Strings.ValueFromIndex[pos1-1]
        end
        else
          //if value is not a tag
          TagEditor.Strings.ValueFromIndex[i]:=TagsToInitIfNotExists.ValueFromIndex[pos];
    end;
  end;
end;

procedure TMainForm.SetAfterEdit();
var i,pos,pos1:Integer;
begin
  for i := 0 to TagEditor.Strings.Count - 1 do
  begin
    pos := TagsToSetAfterEdit.IndexOfName(TagEditor.Strings.Names[i]);
    if pos > -1 then
    begin
      if TagEditor.FindRow(TagsToSetAfterEdit.ValueFromIndex[pos], pos1) then
      begin
        //if value is a tag
        if Not (TagEditor.Strings.ValueFromIndex[pos1-1]='-') then
          //if source-tag filled
          TagEditor.Strings.ValueFromIndex[i]:=TagEditor.Strings.ValueFromIndex[pos1-1]
      end
      else
        //if value is not a tag
        TagEditor.Strings.ValueFromIndex[i]:=TagsToSetAfterEdit.ValueFromIndex[pos];
    end;
  end;
end;

procedure TMainForm.btnWriteTagsClick(Sender: TObject);
begin
  if AllTagsSetted then
    WriteTags
    else
     ShowMessage('Not all tags filled');
end;

procedure TMainForm.cbStayOnTopChange(Sender: TObject);
begin
  if cbStayOnTop.Checked then
  begin
    self.FormStyle:=fsSystemStayOnTop;
  end
  else
    self.FormStyle:=fsNormal;
end;

procedure TMainForm.cbLoadImageChange(Sender: TObject);
begin
  if cbLoadImage.Checked then
    bLoadImage := true
  else
    bLoadImage := false;
end;

function TMainForm.ReadIni():Boolean;
begin
  Result := false;
  if FileExists(AppPath + 'settings.ini') then
  begin
    try
      ini:=TIniFile.Create(AppPath + 'settings.ini');
      //todo read [ExifToolWriteArgs]  [ExifToolReadArgs]
      ini.ReadSection('TagsToRead', TagsToRead);
      ini.ReadSectionRaw('TagsToInitAnyway', TagsToInitAnyway);
      ini.ReadSectionRaw('TagsToInitIfNotExists', TagsToInitIfNotExists);
      ini.ReadSectionRaw('TagsToSetAfterEdit', TagsToSetAfterEdit);
      NorthDirectionTag := ini.ReadString('Settings','NorthDirectionTag','xmp:PoseHeadingDegrees');
      InitialViewTag := ini.ReadString('Settings','InitialViewTag','xmp:InitialViewHeadingDegrees');
      bLoadImage := ini.ReadBool('Settings','LoadImage',true);
      bStayOnTop := ini.ReadBool('Settings','StayOnTop',true);
      ExiftoolPath :=ini.ReadString('Settings','ExiftoolPath','exiftool\exiftool.exe');
      ArgfilePath :=ini.ReadString('Settings','ArgfilePath','exiftool\argfile.txt');
      Result := true;
    finally
      ini.Free;
    end;
  end;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  TagsToRead.Free;
  TagsToInitAnyway.Free;
  TagsToInitIfNotExists.Free;
  TagsToSetAfterEdit.Free;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  AppPath := ExtractFilePath(ParamStr(0));
  north_x := 0;
  view_x := 0;
  TagsToRead := Tstringlist.Create;
  TagsToInitAnyway := Tstringlist.Create;
  TagsToInitIfNotExists := Tstringlist.Create;
  TagsToSetAfterEdit := Tstringlist.Create;
  if not FileExists(AppPath + 'settings.ini') then
  begin
    //todo write default ini
  end;
  if ReadIni then
  begin
    cbStayOnTop.Checked := bStayOnTop;
    cbLoadImage.Checked := bLoadImage;
      //check exiftool
      if not FileExists(AppPath + ExiftoolPath) then
      begin
        ShowMessage('exiftool not found');
        Application.Terminate;
      end;
      if ParamCount>0 then
      begin
        if (MatchStr(LowerCase(ExtractFileExt(ParamStr(1))), ['.jpg', '.jpeg', '.tif', '.tiff'])) then
        begin
          ImageFile:=ParamStr(1);
          Start;
        end;
      end;
    end
  else
  begin
    ShowMessage('Can''t read settings.ini');
  end;
end;

procedure TMainForm.LoadImage(ImageFile:String);
var
  ImgLoadThread:TImgLoadThread;
begin
  ImgLoadThread := TImgLoadThread.Create(True);
  imgLoadThread.imgPath := ImageFile;
  ImgLoadThread.OnTerminate:= @ImgLoadThreadOnTerminate;
  bImageLoadThreadTerminated:=false;
  ProgressForm.Caption:=MainForm.Caption;
  ProgressForm.FormStyle:=self.FormStyle;
  ImgLoadThread.Start;ProgressForm.Show;
  while not bImageLoadThreadTerminated do
  begin
    ProgressForm.lbMotion.Caption:='|';
    sleep(100);
    Application.ProcessMessages;
    ProgressForm.lbMotion.Caption:='/';
    sleep(100);
    Application.ProcessMessages;
    ProgressForm.lbMotion.Caption:='-';
    sleep(100);
    Application.ProcessMessages;
    ProgressForm.lbMotion.Caption:='\';
    sleep(100);
    Application.ProcessMessages;
    ProgressForm.lbMotion.Caption:='|';
    sleep(100);
    Application.ProcessMessages;
    ProgressForm.lbMotion.Caption:='/';
    sleep(100);
    Application.ProcessMessages;
    ProgressForm.lbMotion.Caption:='-';
    sleep(100);
    Application.ProcessMessages;
    ProgressForm.lbMotion.Caption:='\';
    sleep(100);
    Application.ProcessMessages;
  end;
end;

procedure TMainForm.imgLoadThreadOnTerminate(ASender : TObject );
begin
 bImageLoadThreadTerminated:=true;
 ProgressForm.Hide;
 image_loaded:=true;
end;

procedure TMainForm.FormDropFiles(Sender: TObject; const FileNames: array of String
  );
begin
  if (MatchStr(LowerCase(ExtractFileExt(FileNames[0])), ['.jpg', '.jpeg', '.tif', '.tiff'])) then
  begin
    ImageFile:=FileNames[0];
    Start;
  end;
end;

procedure TMainForm.Image1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  TagEditor.EditorMode:=false;
  bMouseDown:=true;
  SaveMousePos(x,y);
end;

procedure TMainForm.SaveMousePos(x,y:Integer);
begin
  if image_loaded and bMouseDown and (x>=0) and (x<=Image1.Width) and (y>=0) and (y<=Image1.Height) then
  begin
    if rbtnNorth.Checked then
      north_x:=x
    else
      view_x:=x;
    TagEditor.Values[NorthDirectionTag]:=IntToStr(NorthPosToDeg(north_x, Image1.Width));
    TagEditor.Values[InitialViewTag]:=IntToStr(ViewPosToDeg(view_x,north_x,Image1.Width));
    SetAfterEdit();
    Image1.Invalidate;
  end;
end;

procedure TMainForm.Image1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  //SaveMousePos(x,y);
end;

procedure TMainForm.Image1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  SaveMousePos(x,y);
  bMouseDown:=false;
end;

procedure TMainForm.Image1Paint(Sender: TObject);
begin
  with Image1.Canvas do
  begin
    Pen.Width:=2;
    Pen.Color:=clRed;
    Line(north_x,0,north_x,Image1.Height);
    Pen.Color:=clLime;
    Line(view_x,0,view_x,Image1.Height);
  end;
end;

procedure TMainForm.TagEditorKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  UpdatePos();
  SetAfterEdit();
end;

procedure TMainForm.InitPos();
begin
  if (TagEditor.Values[NorthDirectionTag] <> '') and (TagEditor.Values[NorthDirectionTag] <> '-') then
    north_x:=NorthDegToPos(StrToInt(TagEditor.Values[NorthDirectionTag]), Image1.Width);
  if (TagEditor.Values[InitialViewTag] <> '') and (TagEditor.Values[InitialViewTag] <> '-') then
    view_x := ViewDegToPos(StrToInt(TagEditor.Values[InitialViewTag]),north_x,Image1.Width);
  Image1.Invalidate;
end;

procedure TMainForm.UpdatePos();
begin
  if (TagEditor.Values[NorthDirectionTag] <> '') and (TagEditor.Values[NorthDirectionTag] <> '-') then
    north_x:=NorthDegToPos(StrToInt(TagEditor.Values[NorthDirectionTag]), Image1.Width);
  if (TagEditor.Values[InitialViewTag] <> '') and (TagEditor.Values[InitialViewTag] <> '-') then
  begin
    TagEditor.Values[InitialViewTag]:=IntToStr(ViewPosToDeg(view_x,north_x,Image1.Width));
    view_x := ViewDegToPos(StrToInt(TagEditor.Values[InitialViewTag]),north_x,Image1.Width);
  end;
  Image1.Invalidate;
end;

end.

