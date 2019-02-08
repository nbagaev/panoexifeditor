unit resizeimage;

{$mode objfpc}{$H+}

interface


uses
  Classes, SysUtils, FPimage;

  function resizeImageFast(source:TFPCompactImgRGB8Bit; w,h:word):TFPCompactImgRGB8Bit;
  function resizeImageSlow(source:TFPCompactImgRGB8Bit; w,h:integer):TFPCompactImgRGB8Bit;

implementation

function resizeImageFast(source:TFPCompactImgRGB8Bit; w,h:word):TFPCompactImgRGB8Bit;
var
  f,hf: single;
  x, y,newh,neww: word;
begin
  Result  :=  TFPCompactImgRGB8Bit.create(w, h);
  Result.UsePalette:=false;
  f := source.Height / h;
  newh := h-1;
  neww := w-1;
  for y := 0 to newh do
    for x := 0 to neww do
      Result.Colors[X,Y] := source.Colors[Round(x * f),Round(y * f)]
end;

function resizeImageSlow(source:TFPCompactImgRGB8Bit; w,h:integer):TFPCompactImgRGB8Bit;
var
 i, j, x, y,newh,neww: word;
 newcolor:TFPColor;
 r,g,b,f,ff:single;
 istart,iend,jstart,jend,jj:Word;
 fstep,x1,x2,y1,y2:double;
begin
  Result  :=  TFPCompactImgRGB8Bit.create(w, h);
  Result.UsePalette:=false;
  //init
  f := source.Width/w;
  fstep := f * 0.9999;
  newh:=h-1;
  neww:=w-1;
  //init
  for y :=0 to newh do
  begin
    y1 := y * f;
    y2 :=y1 + fstep;
    jstart := trunc(y1);
    jend := trunc(y2);
    jj:=jend-jstart+1;
    for x :=0 to neww do
    begin
      x1:=x * f;
      x2:=x1 + fstep;
      istart := trunc(x1);
      iend := trunc(x2);
      r := 0;
      g := 0;
      b := 0;
      ff:=1/ (jj*(iend-istart+1));
      for j := jstart to jend do
      begin
        for i := istart to iend do
        begin
          r := r + source.Colors[i,j].red* ff ;
          g := g + source.Colors[i,j].green* ff ;
          b := b + source.Colors[i,j].blue* ff ;
        end;
      end;
      with newcolor do
      begin
        red := Round(r);
        green := Round(g);
        blue := Round(b);
      end;
      Result.Colors[x,y] := newcolor;
    end;
  end;
end;

end.


