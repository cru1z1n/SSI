unit uBits;

interface

procedure SetBitAt(var Variable: LongInt; Position: Byte; Value: Boolean); overload;
procedure SetBitAt(var Variable: Byte; Position: Byte; Value: Boolean); overload;
function GetBitAt(Variable: LongInt; Position: Byte): Boolean;

implementation

procedure SetBitAt(var Variable: LongInt; Position: Byte; Value: Boolean);
begin
  if Value then
    Variable:= Variable or (1 shl Position)
  else
    Variable:= Variable and ((1 shl Position) xor $FFFFFFFF);
end;

procedure SetBitAt(var Variable: Byte; Position: Byte; Value: Boolean);
begin
  if Value then
    Variable:= Variable or (1 shl Position)
  else
    Variable:= Variable and ((1 shl Position) xor $FF);
end;

function GetBitAt(Variable: LongInt; Position: Byte): Boolean;
begin
  if Variable and (1 shl Position) <> 0 then
    Result:= True
  else
    Result:= False;
end;

end.
 