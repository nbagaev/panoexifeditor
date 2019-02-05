unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, UTF8Process, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, ValEdit, StdCtrls, fpreadtiff, Process, StrUtils, INIFiles, Grids,
  ComCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnOpen: TButton;
    btnWriteTags: TButton;
    Button1: TButton;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    Image1: TImage;
    OpenDialog1: TOpenDialog;
    Panel1: TPanel;
    ProcessUTF8_1: TProcessUTF8;
    rbtnNorth: TRadioButton;
    rbtnView: TRadioButton;
    ValueListEditor1: TValueListEditor;
    procedure btnOpenClick(Sender: TObject);
    procedure btnWriteTagsClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure CheckBox1Change(Sender: TObject);
    procedure CheckBox2Change(Sender: TObject);
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
    procedure ValueListEditor1KeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    function ReadTags(image_file:String):Boolean;
    procedure LoadImage(image_file:String);
    procedure SaveMousePos(x,y:Integer);
    function ReadIni(): Boolean;
    procedure WriteTags();
    procedure InitTags();
    procedure Start();
    procedure SetAfterEdit();
    function AllTagsSetted():boolean;
    procedure InitPos();
    procedure UpdatePos();
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;
  north_x,
  view_x : Integer;
  mouse_down : Boolean;
  NorthDirectionTag,
  InitialViewTag,
  image_file: String;
  ini:TIniFile;
  TagsToRead,
  TagsToInitAnyway,
  TagsToInitIfNotExists,
  TagsToSetAfterEdit:Tstringlist;
  image_loaded:Boolean;
  load_image,
  modal:Boolean;
  Path:String;

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
var versatz:Integer;
begin
  //todo
  versatz := Trunc(img_width / 360 * view_deg);
  if (north_x + versatz) < img_width then
    Result:= north_x + versatz
  else
    Result:= north_x + versatz - img_width;
end;

{$R *.lfm}

{ TForm1 }

function TForm1.ReadTags(image_file:String): boolean;
var
  sl : TStringList;
  i : Integer;
begin
  Result := true;
  sl := TStringList.Create;
  ValueListEditor1.Clear;
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
  sl.Add(image_file);
  sl.SaveToFile(Path+'argfile.txt');
  try
    with ProcessUTF8_1 do
    begin
      Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];
      ShowWindow := swoHIDE;
      Executable := Path + 'exiftool/exiftool.exe';
      Parameters.Clear;
      Parameters.Add('-@');
      Parameters.Add(Path+'argfile.txt');
      Execute;
    end;
  finally
    sl.Clear;
    sl.LoadFromStream(ProcessUTF8_1.Output);
    if sl.Count=TagsToRead.Count then
    begin
      sl.NameValueSeparator:=':';
      for i := 0 to TagsToRead.Count-1 do
      begin
        ValueListEditor1.Strings.Add(TagsToRead[i] + '=' + Trim(sl.ValueFromIndex[i]));
      end;
    self.Caption := Application.Title + ' - ' + ExtractFileName(image_file);
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

function TForm1.AllTagsSetted():boolean;
var i : Integer;
begin
  Result:=true;
  for i := 0 to ValueListEditor1.Strings.Count - 1 do
  begin
    if (ValueListEditor1.Strings.ValueFromIndex[i]='-') or (ValueListEditor1.Strings.ValueFromIndex[i]='') then
      Result:=false;
  end;
end;

procedure TForm1.btnOpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    image_file:=OpenDialog1.FileName;
    Start;
  end;
 end;

procedure TForm1.Start();
begin
  if ReadTags(image_file) then
  begin
    InitTags();
    InitPos();
    if load_image then
      LoadImage(image_file);
  end;
end;

procedure TForm1.WriteTags;
var
  sl : TStringList;
  i : Integer;
begin
  sl := TStringList.Create;
  sl.Add('-charset');
  sl.Add('filename=utf8');
  sl.Add('-overwrite_original');
  sl.Add('-S');
  for i := 0 to ValueListEditor1.Strings.Count - 1 do
    sl.Add('-' + ValueListEditor1.Strings[i]);
  sl.Add(image_file);
  sl.SaveToFile(Path+'argfile.txt');
  try
    with ProcessUTF8_1 do
    begin
      Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];
      ShowWindow := swoHIDE;
      Executable := Path + 'exiftool/exiftool.exe';
      Parameters.Clear;
      Parameters.Add('-@');
      Parameters.Add(Path + 'argfile.txt');
      Execute;
    end;
  finally
    sl.Clear;
    sl.LoadFromStream(ProcessUTF8_1.Output);
    ShowMessage('exiftool: ' + sl.Text);
    sl.Free;
  end;
end;

procedure TForm1.InitTags();
var i,pos,pos1:Integer;
begin
  for i := 0 to ValueListEditor1.Strings.Count - 1 do
  begin
    //TagsToInitAnyway
    pos := TagsToInitAnyway.IndexOfName(ValueListEditor1.Strings.Names[i]);
    if pos > -1 then
    begin
      if ValueListEditor1.FindRow(TagsToInitAnyway.ValueFromIndex[pos], pos1) then
      begin
        //if value is a tag
        if Not (ValueListEditor1.Strings.ValueFromIndex[pos1-1]='-') then
          //if source tag exists and filled
          ValueListEditor1.Strings.ValueFromIndex[i]:=ValueListEditor1.Strings.ValueFromIndex[pos1-1]
      end
      else
        //if value is not a tag
        ValueListEditor1.Strings.ValueFromIndex[i]:=TagsToInitAnyway.ValueFromIndex[pos];
    end;
    //TagsToInitIfNotExist
    pos := TagsToInitIfNotExists.IndexOfName(ValueListEditor1.Strings.Names[i]);
    if pos > -1 then
    begin
      if ValueListEditor1.Strings.ValueFromIndex[i]='-' then
        //if dest-tag not filled
        if ValueListEditor1.FindRow(TagsToInitIfNotExists.ValueFromIndex[pos], pos1) then
        begin
          //if value is a tag
          if Not (ValueListEditor1.Strings.ValueFromIndex[pos1-1]='-') then
            //if source-tag exists
            ValueListEditor1.Strings.ValueFromIndex[i]:=ValueListEditor1.Strings.ValueFromIndex[pos1-1]
        end
        else
          //if value is not a tag
          ValueListEditor1.Strings.ValueFromIndex[i]:=TagsToInitIfNotExists.ValueFromIndex[pos];
    end;
  end;
end;

procedure TForm1.SetAfterEdit();
var i,pos,pos1:Integer;
begin
  for i := 0 to ValueListEditor1.Strings.Count - 1 do
  begin
    pos := TagsToSetAfterEdit.IndexOfName(ValueListEditor1.Strings.Names[i]);
    if pos > -1 then
    begin
      if ValueListEditor1.FindRow(TagsToSetAfterEdit.ValueFromIndex[pos], pos1) then
      begin
        //if value is a tag
        if Not (ValueListEditor1.Strings.ValueFromIndex[pos1-1]='-') then
          //if source-tag filled
          ValueListEditor1.Strings.ValueFromIndex[i]:=ValueListEditor1.Strings.ValueFromIndex[pos1-1]
      end
      else
        //if value is not a tag
        ValueListEditor1.Strings.ValueFromIndex[i]:=TagsToSetAfterEdit.ValueFromIndex[pos];
    end;
  end;
end;

procedure TForm1.btnWriteTagsClick(Sender: TObject);
begin
  if AllTagsSetted then
    WriteTags;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  SetAfterEdit();
  //TagsToInitAnyway.NameValueSeparator:='=';
  //ShowMessage(TagsToInitIfNotExists.text);
  //ShowMessage(TagsToInitAnyway.Names[1]);
  //ShowMessage(IntTostr(TagsToInitAnyway.IndexOfName('xmp:CroppedAreaImageWidthPixels')));
end;

procedure TForm1.CheckBox1Change(Sender: TObject);
begin
  if CheckBox1.Checked then
    self.FormStyle:=fsSystemStayOnTop
  else
    self.FormStyle:=fsNormal;
end;

procedure TForm1.CheckBox2Change(Sender: TObject);
begin
  if CheckBox2.Checked then
    load_image := true
  else
    load_image := false;
end;

function TForm1.ReadIni():Boolean;
begin
  Result := false;
  if FileExists(Path + 'ini.ini') then
  begin
    try
      ini:=TIniFile.Create(Path + 'ini.ini');
      //todo read [ExifToolWriteArgs]  [ExifToolReadArgs]
      ini.ReadSection('TagsToRead', TagsToRead);
      ini.ReadSectionRaw('TagsToInitAnyway', TagsToInitAnyway);
      ini.ReadSectionRaw('TagsToInitIfNotExists', TagsToInitIfNotExists);
      ini.ReadSectionRaw('TagsToSetAfterEdit', TagsToSetAfterEdit);
      NorthDirectionTag := ini.ReadString('Settings','NorthDirectionTag','xmp:PoseHeadingDegrees');
      InitialViewTag := ini.ReadString('Settings','InitialViewTag','xmp:InitialViewHeadingDegrees');
      load_image := ini.ReadBool('Settings','LoadImage',true);
      modal := ini.ReadBool('Settings','Modal',true);
      Result := true;
    finally
      ini.Free;
    end;
  end;
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  TagsToRead.Free;
  TagsToInitAnyway.Free;
  TagsToInitIfNotExists.Free;
  TagsToSetAfterEdit.Free;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Path := ExtractFilePath(ParamStr(0));
  //check exiftool
  if not FileExists(Path + 'exiftool/exiftool.exe') then
  begin
      ShowMessage('exiftool not found');
      Application.Terminate;
  end;
  north_x := 0;
  view_x := 0;
  TagsToRead := Tstringlist.Create;
  TagsToInitAnyway := Tstringlist.Create;
  TagsToInitIfNotExists := Tstringlist.Create;
  TagsToSetAfterEdit := Tstringlist.Create;
  if not FileExists(Path + 'ini.ini') then
  begin
    //todo write default ini
  end;
  if ReadIni then
  begin
    CheckBox1.Checked := modal;
    CheckBox2.Checked := load_image;

      if ParamCount>0 then
      begin
        if (MatchStr(LowerCase(ExtractFileExt(ParamStr(1))), ['.jpg', '.jpeg', '.tif', '.tiff'])) then
        begin
          image_file:=ParamStr(1);
          Start;
        end;
      end;
    end
  else
  begin
    ShowMessage('Can''t read ini.ini');
  end;
end;

procedure TForm1.LoadImage(image_file:String);
var
  //TicksBefore:integer;
  p:TPicture;
begin
  try
    //TicksBefore:=GetTickCount64;
    p:=TPicture.Create;
    p.LoadFromFile(image_file);
    //ShowMessage('Picture loaded in '+FloatToStrF((GetTickCount64 - TicksBefore)/1000,ffFixed,2,3)+' sec');
    //Image1.Canvas.Draw(0,0,p.Graphic);
    Image1.Canvas.StretchDraw(Rect(0,0,Image1.Width, Image1.Height), p.Graphic);
  finally
    p.Free;
    image_loaded:=true;
  end;
end;

procedure TForm1.FormDropFiles(Sender: TObject; const FileNames: array of String
  );
begin
  if (MatchStr(LowerCase(ExtractFileExt(FileNames[0])), ['.jpg', '.jpeg', '.tif', '.tiff'])) then
  begin
    image_file:=FileNames[0];
    Start;
  end;
end;

procedure TForm1.Image1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  ValueListEditor1.EditorMode:=false;
  mouse_down:=true;
  SaveMousePos(x,y);
end;

procedure TForm1.SaveMousePos(x,y:Integer);
begin
  if image_loaded=true and mouse_down and (x>=0) and (x<=Image1.Width) and (y>=0) and (y<=Image1.Height) then
  begin
    if rbtnNorth.Checked then
      north_x:=x
    else
      view_x:=x;
    ValueListEditor1.Values[NorthDirectionTag]:=IntToStr(NorthPosToDeg(north_x, Image1.Width));
    ValueListEditor1.Values[InitialViewTag]:=IntToStr(ViewPosToDeg(view_x,north_x,Image1.Width));
    SetAfterEdit();
    Image1.Invalidate;
  end;
end;

procedure TForm1.Image1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  //SaveMousePos(x,y);
end;

procedure TForm1.Image1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  SaveMousePos(x,y);
  mouse_down:=false;
end;

procedure TForm1.Image1Paint(Sender: TObject);
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

procedure TForm1.ValueListEditor1KeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  UpdatePos();
  SetAfterEdit();
end;

procedure TForm1.InitPos();
begin
  if (ValueListEditor1.Values[NorthDirectionTag] <> '') and (ValueListEditor1.Values[NorthDirectionTag] <> '-') then
    north_x:=NorthDegToPos(StrToInt(ValueListEditor1.Values[NorthDirectionTag]), Image1.Width);
  if (ValueListEditor1.Values[InitialViewTag] <> '') and (ValueListEditor1.Values[InitialViewTag] <> '-') then
    view_x := ViewDegToPos(StrToInt(ValueListEditor1.Values[InitialViewTag]),north_x,Image1.Width);
  Image1.Invalidate;
end;

procedure TForm1.UpdatePos();
begin
  if (ValueListEditor1.Values[NorthDirectionTag] <> '') and (ValueListEditor1.Values[NorthDirectionTag] <> '-') then
    north_x:=NorthDegToPos(StrToInt(ValueListEditor1.Values[NorthDirectionTag]), Image1.Width);
  if (ValueListEditor1.Values[InitialViewTag] <> '') and (ValueListEditor1.Values[InitialViewTag] <> '-') then
  begin
    ValueListEditor1.Values[InitialViewTag]:=IntToStr(ViewPosToDeg(view_x,north_x,Image1.Width));
    view_x := ViewDegToPos(StrToInt(ValueListEditor1.Values[InitialViewTag]),north_x,Image1.Width);
  end;
  Image1.Invalidate;
end;

end.

