library SImage;

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  View-Project Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the DELPHIMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using DELPHIMM.DLL, pass string information
  using PChar or ShortString parameters. }

uses
  Controls,
  Dialogs,
  StdCtrls,
  Buttons,
  XPMan,
  ExtCtrls,
  ExtDlgs,
  Windows,
  Graphics,
  Forms,
  ComCtrls,
  SysUtils,
  Classes,
  uBits;

var
t:string;

type pRGBArray= ^TRGBArray;
     TRGBArray= array [1..3] of Byte;

procedure ProcessEncrypt(Bitmap: TBitmap; Source: TFileStream; Destination: string; BPC: LongInt);
var SourceIndex, SourceSize: LongInt;
    BitIndex, PixelBitIndex: LongInt;
    SourceByte: Byte;
    PixelsRow: pRGBArray;
    RGBIndex: Integer;
    PixelsRowMax, PixelsRowIndex, CurrentRow: Integer;
procedure CheckNextPixel;
begin
  if (RGBIndex <= 3) and (PixelBitIndex + 1 < BPC) then //  go for the next bit
    Inc(PixelBitIndex)
  else if RGBIndex < 3 then // Switch RGB channel
    begin
    Inc(RGBIndex);
    PixelBitIndex:= 0;
    end
  else if RGBIndex = 3 then // next pixel
    begin
    PixelBitIndex:= 0;
    RGBIndex:= 1;
    if PixelsRowIndex = PixelsRowMax then // row complete
      begin
      Inc(CurrentRow);
      PixelsRow:= Bitmap.ScanLine[CurrentRow];
      PixelsRowIndex:= 1;
      end
    else  // if pixels left in this row
      begin
      Inc(PixelsRowIndex);
      Inc(PixelsRow); // increase the pointer so it points to the next
      end;
    end;
end;
begin//begine ncrypt
  PixelsRow:= Bitmap.ScanLine[0];
  SetBitAt(PixelsRow^[1], 0, GetBitAt(BPC, 0));
  SetBitAt(PixelsRow^[1], 1, GetBitAt(BPC, 1));
  SetBitAt(PixelsRow^[2], 0, GetBitAt(BPC, 2));
  SetBitAt(PixelsRow^[3], 0, GetBitAt(BPC, 3));
  PixelsRowMax:= Bitmap.Width;
  CurrentRow:= 0;
  PixelBitIndex:= 0;
  PixelsRowIndex:= 2;
  RGBIndex:= 1;
  Inc(PixelsRow);
  SourceSize:= Source.Size;
  for BitIndex:= 0 to SizeOf(SourceSize) * 8 - 1 do
    begin
    SetBitAt(PixelsRow^[RGBIndex], PixelBitIndex, GetBitAt(SourceSize, BitIndex));
    CheckNextPixel;
    end;
  //STORE DATA
  Source.Seek(0, soFromBeginning);
  for SourceIndex:= 0 to SourceSize - 1 do
    begin
    Source.Read(SourceByte, 1);
    for BitIndex:= 0 to 7 do
      begin
      SetBitAt(PixelsRow^[RGBIndex], PixelBitIndex, GetBitAt(SourceByte, BitIndex));
      CheckNextPixel;
      end;
    end;
end;

procedure Encrypt(const SourceFile, SourceBitmap, Destination: string; BitsPerChannel: LongInt);register;
var Bitmap: TBitmap;
    sSource: TFileStream;
begin
  Bitmap:= TBitmap.Create;
  sSource:= nil;
  try
    Bitmap.LoadFromFile(SourceBitmap);
    if Bitmap.PixelFormat <> pf24bit then
      raise Exception.Create('The image must be 24-bit.');
    sSource:= TFileStream.Create(SourceFile, fmOpenRead);
    if sSource.Size = 0 then
      raise Exception.Create('Invalid File: source file is 0 bytes.');
    if sSource.Size * 8 + SizeOf(LongInt) * 8  + 1 > Bitmap.Width * Bitmap.Height * 3 * BitsPerChannel then
      raise Exception.Create('The image is not big enough to accommodate the file.');
    ProcessEncrypt(Bitmap, sSource, Destination, BitsPerChannel);
    Bitmap.SaveToFile(Destination);
  finally
    Bitmap.Free;
    if Assigned(sSource) then sSource.Free;
  end;
end;

{----------------------------------------------------------------------------------------------------------------------}

procedure ProcessDecrypt(Bitmap: TBitmap; Destination: TFileStream);
var DataSize, DataIndex: LongInt;
    Data, BitIndex: Byte;
    PixelsRow: pRGBArray;
    PixelsRowMax, PixelsRowIndex, CurrentRow, MaxRows: Integer;
    PixelBitIndex: LongInt;
    RGBIndex: Integer;
    BPC: LongInt;
procedure CheckNextPixel;
begin
  if (RGBIndex <= 3) and (PixelBitIndex  + 1 < BPC) then // go for the next bit
    Inc(PixelBitIndex)
  else if RGBIndex < 3 then // Switch to next channel
    begin
    Inc(RGBIndex);
    PixelBitIndex:= 0;
    end
  else if RGBIndex = 3 then // next pixel
    begin
    PixelBitIndex:= 0;
    RGBIndex:= 1;
    if PixelsRowIndex = PixelsRowMax then // row complete
      begin
      Inc(CurrentRow);
      if CurrentRow > MaxRows then
        raise Exception.Create('The end of the image was reached while trying to read the hidden information.' + #13#10+
                               'This is probably caused by an image that doesn''t contain any hidden data.');
      PixelsRow:= Bitmap.ScanLine[CurrentRow];
      PixelsRowIndex:= 1;
      end
    else  // We still have pixels left in this row
      begin
      Inc(PixelsRowIndex);
      Inc(PixelsRow); // Increment the pointer so it points to the next pixel
      end;
    end;
end;
begin //ProcessDecrypt
  PixelsRow:= Bitmap.ScanLine[0];
  BPC:= 0;
  SetBitAt(BPC, 0, GetBitAt(PixelsRow^[1], 0));
  SetBitAt(BPC, 1, GetBitAt(PixelsRow^[1], 1));
  SetBitAt(BPC, 2, GetBitAt(PixelsRow^[2], 0));
  SetBitAt(BPC, 3, GetBitAt(PixelsRow^[3], 0));
  if (BPC < 1 ) or (BPC > 8) then
    raise Exception.Create('The BitsChannel is not in the range 1-8.' + #13#10 +
                           'This is probably caused by an image that doesn''t contain any hidden data.');
  PixelsRowMax:= Bitmap.Width;
  MaxRows:= Bitmap.Height - 1;
  CurrentRow:= 0;
  PixelBitIndex:= 0;
  PixelsRowIndex:= 2;
  RGBIndex:= 1;
  Inc(PixelsRow);
  for BitIndex:= 0 to SizeOf(DataSize) * 8 - 1 do
    begin
    SetBitAt(DataSize, BitIndex, GetBitAt(PixelsRow^[RGBIndex], PixelBitIndex));
    CheckNextPixel;
    end;
  if DataSize <= 0 then
    raise Exception.Create('The stored size of the hidden data is not correct.' + #13#10 +
                           'This is probably caused by an image that doesn''t contain any hidden data.');
  for DataIndex:= 1 to DataSize do
    begin
    for BitIndex:= 0 to 7 do
      begin
      SetBitAt(Data, BitIndex, GetBitAt(PixelsRow^[RGBIndex], PixelBitIndex));
      CheckNextPixel;
      end;
    Destination.Write(Data, 1);
    end;
end;

procedure Decrypt(const SourceFile, DestFile: string);register;
var Bitmap: TBitmap;
    Destination: TFileStream;
begin
  Bitmap:= TBitmap.Create;
  Destination:= nil;
  try
    try
      if FileExists(DestFile) then DeleteFile(PAnsiChar(DestFile));
      Destination:= TFileStream.Create(DestFile, fmCreate);
      Bitmap.LoadFromFile(SourceFile);
      if Bitmap.PixelFormat <> pf24bit then
        raise Exception.Create('The image doesn''t have a 24-bit depth. It surely hasn''t been created by this program.');
      ProcessDecrypt(Bitmap, Destination);
    finally
      Bitmap.Free;
      if Assigned(Destination) then Destination.Free;
    end;
  except
    if FileExists(DestFile) then
      DeleteFile(PChar(DestFile));
    raise;
  end;
end;

{function ShowDllFormModal:integer;register;
begin
  frmDllForm :=TfrmDllForm.Create(nil);
  Result := frmDllForm.ShowModal;
end; }

procedure ChangeCap;register;
begin
   { DllForm.frmDllForm.score.Caption:='lol';
    frmDllForm.Repaint;    }
end;

procedure Test(TT:integer);register;
begin
{T:=inttostr(TT);
DllForm.frmDllForm.score.Caption:=T;
frmDllForm.Repaint;  }
end;

function GetPluginABIVersion: Integer; Cdecl;export;
begin
  Result := 2;
end;

procedure SetPluginMemManager(MemMgr : TMemoryManager); Cdecl;export;
begin
{  if memisset then
    exit;
  GetMemoryManager(OldMemoryManager);
  SetMemoryManager(MemMgr);
  memisset := true;    }
end;

procedure OnDetach; Cdecl; export;
begin
  //SetMemoryManager(OldMemoryManager);
end;

function GetTypeCount(): Integer; Cdecl; export;
begin
 // Result := 1;
end;

function GetTypeInfo(x: Integer; var sType, sTypeDef: PAnsiChar): integer; Cdecl;export;
begin
  {case x of
    0: begin
        StrPCopy(sType, 'T3DIntegerArray');
        StrPCopy(sTypeDef, 'array of array of array of integer;');
       end;

    else
      x := -1;
  end;

  Result := x;   }
end;

function GetFunctionCount(): Integer;stdcall export;
begin
  Result := 4;
end;

function GetFunctionCallingConv(x : Integer) : Integer; stdcall; export;
begin
     Result := 0;
  case x of
     0..5 : Result := 1;
  end;
end;

function GetFunctionInfo(x: Integer; var ProcAddr: Pointer; var ProcDef: PChar): Integer; stdcall; export;
begin
  case x of
    0:
      begin
        ProcAddr := @Test;
        StrPCopy(ProcDef, 'procedure Test(TT:integer);');
      end;
     1:
      begin
        ProcAddr := @ChangeCap;
        StrPCopy(ProcDef, 'procedure ChangeCap;');
      end;
     2:
      begin
        ProcAddr := @Encrypt;
        StrPCopy(ProcDef, 'procedure Encrypt(const SourceFile, SourceBitmap, Destination: string; BitsPerChannel: LongInt);');
      end;
     3:
      begin
        ProcAddr := @Decrypt;
        StrPCopy(ProcDef, 'procedure Decrypt(const SourceFile, DestFile: string);');
      end;
  else
    x := -1;
  end;
  Result := x;
end; 

exports GetFunctionCount;    //old pascal exports
exports GetFunctionInfo;
exports GetFunctionCallingConv;

{exports GetPluginABIVersion;   //lape exports
exports SetPluginMemManager;
exports GetTypeCount;
exports GetTypeInfo;
exports GetFunctionCount;
exports GetFunctionInfo;
exports OnDetach; }


end.
