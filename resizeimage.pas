unit resizeimage;

{$mode objfpc}{$H+}

interface


uses
  Classes, SysUtils, FPimage;
  procedure resizeImageFast(var source: TFPCompactImgRGB8Bit; var dest: TFPCompactImgRGB8Bit);
  procedure resizeImageSlow(var source: TFPCompactImgRGB8Bit; var dest: TFPCompactImgRGB8Bit);

implementation

procedure resizeImageFast(var source: TFPCompactImgRGB8Bit; var dest: TFPCompactImgRGB8Bit);
var
  f: Single;
  x, y, newh, neww: Word;
begin
  f:= source.Height/dest.Height;
  newh:= dest.Height-1;
  neww:= dest.Width-1;
  for y:= 0 to newh do
    for x:= 0 to neww do
      dest.Colors[X,Y]:= source.Colors[Round(x*f),Round(y*f)]
end;

procedure resizeImageSlow(var source: TFPCompactImgRGB8Bit; var dest: TFPCompactImgRGB8Bit);
var
 i, j, x, y, newh, neww: Word;
 newcolor: TFPColor;
 r, g, b, f, ff: Single;
 istart, iend, jstart, jend, jj: Word;
 fstep, x1, x2, y1, y2: Double;
begin
  f:=source.Width/dest.Width;
  fstep:=f*0.9999;
  newh:=dest.Height-1;
  neww:=dest.Width-1;
  for y:=0 to newh do
  begin
    y1:=y*f;
    y2:=y1+fstep;
    jstart:=Trunc(y1);
    jend:=Trunc(y2);
    jj:=jend-jstart+1;
    for x:=0 to neww do
    begin
      x1:=x*f;
      x2:=x1+fstep;
      istart:=Trunc(x1);
      iend:=Trunc(x2);
      r:=0;
      g:=0;
      b:=0;
      ff:=1/(jj*(iend-istart+1));
      for j:=jstart to jend do
      begin
        for i:=istart to iend do
        begin
          r:=r+source.Colors[i,j].red*ff;
          g:=g+source.Colors[i,j].green*ff;
          b:=b+source.Colors[i,j].blue*ff;
        end;
      end;
      with newcolor do
      begin
        red:=Round(r);
        green:=Round(g);
        blue:=Round(b);
      end;
      dest.Colors[x,y]:=newcolor;
    end;
  end;
end;

end.


