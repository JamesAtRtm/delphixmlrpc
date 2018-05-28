
{*******************************************************}
{                                                       }
{ XML-RPC Library for Delphi, Kylix and DWPL (DXmlRpc)  }
{ XmlRpcCommon.pas                                      }
{                                                       }
{ for Delphi 6, 7                                       }
{ Release 2.0.0                                         }
{ Copyright (c) 2001-2003 by Team-DelphiXml-Rpc         }
{ e-mail: team-dxmlrpc@dwp42.org                        }
{ www: http://sourceforge.net/projects/delphixml-rpc/   }
{                                                       }
{ The initial developer of the code is                  }
{   Clifford E. Baeseman, codepunk@codepunk.com         }
{                                                       }
{ This file may be distributed and/or modified under    }
{ the terms of the GNU Lesser General Public License    }
{ (LGPL) version 2.1 as published by the Free Software  }
{ Foundation and appearing in the included file         }
{ license.txt.                                          }
{                                                       }
{*******************************************************}
{
  $Header: /cvsroot/delphixml-rpc/dxmlrpc/source/XmlRpcCommon.pas,v 1.3 2004/04/20 20:35:19 iwache Exp $
  ----------------------------------------------------------------------------

  $Log: XmlRpcCommon.pas,v $
  Revision 1.3  2004/04/20 20:35:19  iwache
  Function IsoToDateTime now handles both valid
  ISO 8601 - Date/Time Representations e.g.
  1993-02-14T13:10:30 and 19930214T131030.
  Thanks for the hint from Sascha Wojewsky.

  Revision 1.2  2004/01/25 18:15:04  iwache
  New functions FloatToRpcStr and RpcStrToFloat
  for language independent transmission of real values
  added. (Problem was: Decimal seperator in German Windows
  is different to the English one.)

  Revision 1.1.1.1  2003/12/03 22:37:48  iwache
  Initial import of release 2.0.0

  ----------------------------------------------------------------------------
}
unit XmlRpcCommon;

{$INCLUDE 'indy.inc'}

interface

uses
{$IFDEF WIN32}
  Windows,
{$ENDIF}
  SysUtils,
  Classes
{$IFDEF INDY9}
  , IdHash
{$ENDIF}
{$IFDEF ACTIVEX}
  , Variants
{$ENDIF}
  ;

type
  TRC4Data = record
    Key: array[0..255] of Byte; { current key }
    OrgKey: array[0..255] of Byte; { original key }
  end;

  TRC4 = class(TObject)
  private
    FData: TRC4Data;
    procedure RC4Init(var Data: TRC4Data; Key: Pointer; Len: Integer);
    procedure RC4Burn(var Data: TRC4Data);
    procedure RC4Crypt(var Data: TRC4Data; InData, OutData: Pointer; Len:
      Integer);
    procedure RC4Reset(var Data: TRC4Data);
  public
    constructor Create(const EncryptionKey: string);
    procedure EncryptStream(InStream, OutStream: TMemoryStream);
    function EncryptString(const Value: string): string;
    procedure DecryptStream(InStream, OutStream: TMemoryStream);
    function DecryptString(const Value: string): string;
    procedure BurnKey;
  end;

  { xml-rpc data types }
  TRPCDataType = (rpNone, rpString, rpInteger, rpBoolean, rpDouble,
    rpDate, rpBase64, rpStruct, rpArray, rpName, rpError);

function GetTempDir: string;

function FileIsExpired(const FileName: string; Elapsed: Integer): Boolean;

function EncodeEntities(const Data: string): string;

function DecodeEntities(const Data: string): string;

function Replace(const Data: string; const Find: string;
  const Replace: string): string;

function InStr(Start: Integer; const Data: string;
  const Find: string): Integer;

function Mid(const Data: string; Start: Integer): string;

function DateTimeToISO(ConvertDate: TDateTime): string;

function IsoToDateTime(const ISOStringDate: string): TDateTime;

function FloatToRpcStr(Value: Double): string;

function RpcStrToFloat(Value: string): Double;

function ParseString(const SearchString: string; Delimiter: Char;
  Substrings: TStrings; const AllowEmptyStrings: Boolean = False;
  ClearBeforeParse: Boolean = False): Integer;

function ParseStream(SearchStream: TStream; Delimiter: Char;
  Substrings: TStrings; AllowEmptyStrings: Boolean = False;
  ClearBeforeParse: Boolean = False): Integer;

function FixEmptyString(const Value: string): string;

function URLEncode(const Value: string): string;

function StreamToString(Stream: TStream): string;

procedure StringToStream(const Text: string; Stream: TStream);

{$IFDEF ACTIVEX}
function StreamToVariant(Stream: TStream): OleVariant;

procedure VariantToStream(V: OleVariant; Stream: TStream);
{$ENDIF}

{$IFDEF INDY9}
function Hash128AsHex(const Hash128Value: T4x4LongWordRecord): string;
{$ENDIF}

const
  ValidURLChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$-_@.&+-!''*"(),;/#?:';

implementation

{------------------------------------------------------------------------------}

function URLEncode(const Value: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(Value) do
  begin
    if Pos(UpperCase(Value[I]), ValidURLChars) > 0 then
      Result := Result + Value[I]
    else
    begin
      if Value[I] = ' ' then
        Result := Result + '+'
      else
      begin
        Result := Result + '%';
        Result := Result + IntToHex(Byte(Value[I]), 2);
      end;
    end;
  end;
end;

{------------------------------------------------------------------------------}

function EncodeEntities(const Data: string): string;
begin
  Result := StringReplace(Data, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, #39, '&apos;', [rfReplaceAll]);
end;

{------------------------------------------------------------------------------}

function DecodeEntities(const Data: string): string;
begin
  Result := StringReplace(Data, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&apos;', #39, [rfReplaceAll]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
end;

{------------------------------------------------------------------------------}
{ String Parsing Routine                                                       }
{------------------------------------------------------------------------------}

function ParseString(const SearchString: string; Delimiter: Char; Substrings: 
    TStrings; const AllowEmptyStrings: Boolean = False; ClearBeforeParse: 
    Boolean = False): Integer;
var
  Index: Integer;
  PrevCount: Integer;
  TempStr: string;
begin
  if (ClearBeforeParse) then
    Substrings.Clear;

  PrevCount := Substrings.Count;

  { ensure that the last substring is found }
  TempStr := SearchString + Delimiter;

  while (Length(TempStr) > 0) do
  begin
    Index := Pos(Delimiter, TempStr);
    if ((Index > 1) or AllowEmptyStrings) then
      Substrings.Add(Copy(TempStr, 1, Index - 1));
    Delete(TempStr, 1, Index);
  end;

  Result := Substrings.Count - PrevCount;
end;

{------------------------------------------------------------------------------}
{ stream parser                                                                }
{------------------------------------------------------------------------------}

function ParseStream(SearchStream: TStream; Delimiter: Char; Substrings: 
    TStrings; AllowEmptyStrings: Boolean = False; ClearBeforeParse: Boolean =
    False): Integer;
begin
  Result := ParseString(StreamToString(SearchStream), Delimiter, Substrings,
    AllowEmptyStrings, ClearBeforeParse);
end;

{------------------------------------------------------------------------------}
{ convert stream to a string                                                   }
{------------------------------------------------------------------------------}

function StreamToString(Stream: TStream): string;
begin
  Result := '';
  Stream.Seek(0, soFromBeginning);
  SetLength(Result, Stream.Size);
  Stream.Read(Result[1], Stream.Size);
end;

{------------------------------------------------------------------------------}
{  Converts a string to a stream                                               }
{------------------------------------------------------------------------------}

procedure StringToStream(const Text: string; Stream: TStream);
begin
  Stream.Write(Text[1], Length(Text));
end;

{------------------------------------------------------------------------------}
{  Converts a date time to iso 8601 format                                     }
{------------------------------------------------------------------------------}

function DateTimeToISO(ConvertDate: TDateTime): string;
begin
  Result := FormatDateTime('yyyymmdd"T"hh:mm:ss', ConvertDate);
end;

{------------------------------------------------------------------------------}
{  Converts a ISO 8601 data to TDateTime                                       }
{------------------------------------------------------------------------------}

function IsoToDateTime(const ISOStringDate: string): TDateTime;
var
  ISOString: string;
begin
  ISOString := ISOStringDate;

  { convert extended format 1993-02-14T13:10:30 into 19930214T131030 }
  { bug fix to a hint from Sascha Wojewsky }
  ISOString := StringReplace(ISOString, '-', '', [rfReplaceAll]);
  ISOString := StringReplace(ISOString, ':', '', [rfReplaceAll]);

  Result := EncodeDate(StrToInt(Copy(ISOString, 1, 4)),
      StrToInt(Copy(ISOString, 5, 2)),
      StrToInt(Copy(ISOString, 7, 2)))
      + EncodeTime(StrToInt(Copy(ISOString, 10, 2)),
      StrToInt(Copy(ISOString, 12, 2)),
      StrToInt(Copy(ISOString, 14, 2)), 0);
end;

const
  RpcDecimalSeparator = '.';

function SubstDecSep(DblValue: string; RemDecSep, AddDecSep: Char): string;
var
  DecPos: Integer;
begin
  Result := DblValue;
  DecPos := Pos(RemDecSep, Result);
  if DecPos > 0 then
    Result[DecPos] := AddDecSep;
end;

{------------------------------------------------------------------------------}
{  Converts a float value into a XML-RPC string                                }
{------------------------------------------------------------------------------}

function FloatToRpcStr(Value: Double): string;
begin
  Result := SubstDecSep(FloatToStr(Value), DecimalSeparator,
      RpcDecimalSeparator);
end;

{------------------------------------------------------------------------------}
{  Converts a XML-RPC string into a float value                                }
{------------------------------------------------------------------------------}

function RpcStrToFloat(Value: string): Double;
begin
  Result := StrToFloat(SubstDecSep(Value, RpcDecimalSeparator,
      DecimalSeparator));
end;

{------------------------------------------------------------------------------}
{  Returns part of a string                                                    }
{------------------------------------------------------------------------------}

function Mid(const Data: string; Start: Integer): string;
begin
  Result := Copy(Data, Start, Length(Data) - (Start - 1));
end;

{------------------------------------------------------------------------------}
{  Find position of string in sub string                                       }
{------------------------------------------------------------------------------}

function InStr(Start: Integer; const Data: string; const
  Find: string): Integer;
var
  C: Integer;
label
  SkipFind;
begin
  C := Start - 1;
  repeat
    if C > Length(Data) then
    begin
      C := 0;
      goto SkipFind;
    end;
    Inc(C);
  until Copy(Data, C, Length(Find)) = Find;
  SkipFind:
  Result := C;
end;

{------------------------------------------------------------------------------}
{  replace item in string                                                      }
{------------------------------------------------------------------------------}

function Replace(const Data: string; const Find: string;
  const Replace: string): string;
var
  C: Integer;
  Temp, Temp2: string;
begin
  Temp := Data;
  C := InStr(1, Temp, Find);
  while C <> 0 do
  begin
    Temp2 := Copy(Temp, 1, C - 1) + Replace + Mid(Temp, C + Length(Find));
    Temp := Temp2;
    C := InStr(C + Length(Replace), Temp, Find);
  end;
  Result := Temp;
end;

{------------------------------------------------------------------------------}
{Initialize the RC4 Engine                                                     }
{------------------------------------------------------------------------------}

procedure TRC4.RC4Init(var Data: TRC4Data; Key: Pointer; Len: Integer);
var
  XKey: array[0..255] of Byte;
  I, J: Integer;
  T: Byte;
begin
  if (Len <= 0) or (Len > 256) then
    raise Exception.Create('RC4: Invalid key length');
  for I := 0 to 255 do
  begin
    Data.Key[I] := I;
    XKey[I] := PByte(Integer(Key) + (I mod Len))^;
  end;
  J := 0;
  for I := 0 to 255 do
  begin
    J := (J + Data.Key[I] + XKey[I]) and $FF;
    T := Data.Key[I];
    Data.Key[I] := Data.Key[J];
    Data.Key[J] := T;
  end;
  Move(Data.Key, Data.OrgKey, 256);
end;

{------------------------------------------------------------------------------}
{Burn Key data from memory                                                     }
{------------------------------------------------------------------------------}

procedure TRC4.RC4Burn(var Data: TRC4Data);
begin
  FillChar(Data, Sizeof(Data), $FF);
end;

{------------------------------------------------------------------------------}
{Crypt and decrypt routine                                                     }
{------------------------------------------------------------------------------}

procedure TRC4.RC4Crypt(var Data: TRC4Data; InData, OutData: Pointer; Len:
  Integer);
var
  T, I, J: Byte;
  K: Integer;
begin
  I := 0;
  J := 0;
  for K := 0 to Len - 1 do
  begin
    I := (I + 1) and $FF;
    J := (J + Data.Key[I]) and $FF;
    T := Data.Key[I];
    Data.Key[I] := Data.Key[J];
    Data.Key[J] := T;
    T := (Data.Key[I] + Data.Key[J]) and $FF;
    PByteArray(OutData)[K] := PByteArray(InData)[K] xor Data.Key[T];
  end;
end;

{------------------------------------------------------------------------------}
{Reset the data keys                                                           }
{------------------------------------------------------------------------------}

procedure TRC4.RC4Reset(var Data: TRC4Data);
begin
  Move(Data.OrgKey, Data.Key, 256);
end;

{------------------------------------------------------------------------------}
{Remove keys from memory                                                       }
{------------------------------------------------------------------------------}

procedure TRC4.BurnKey;
begin
  RC4Burn(FData);
end;

{------------------------------------------------------------------------------}
{Decrypt a memory stream                                                       }
{------------------------------------------------------------------------------}

procedure TRC4.DecryptStream(InStream, OutStream: TMemoryStream);
begin
  OutStream.SetSize(InStream.Size);
  RC4Crypt(FData, InStream.Memory, OutStream.Memory, InStream.Size);
  RC4Reset(FData);
end;

{------------------------------------------------------------------------------}
{Secrypt a string value                                                        }
{------------------------------------------------------------------------------}

function TRC4.DecryptString(const Value: string): string;
begin
  SetLength(Result, Length(Value));
  RC4Crypt(FData, PByteArray(Value), PByteArray(Result), Length(Result));
end;

{------------------------------------------------------------------------------}
{Encrypt stream data                                                           }
{------------------------------------------------------------------------------}

procedure TRC4.EncryptStream(InStream, OutStream: TMemoryStream);
begin
  OutStream.SetSize(InStream.Size);
  RC4Crypt(FData, InStream.Memory, OutStream.Memory, InStream.Size);
  RC4Reset(FData);
end;

{------------------------------------------------------------------------------}
{Encrypt a string value                                                        }
{------------------------------------------------------------------------------}

function TRC4.EncryptString(const Value: string): string;
begin
  SetLength(Result, Length(Value));
  RC4Crypt(FData, PByteArray(Value), PByteArray(Result), Length(Result));
  Result := Result;
  RC4Reset(FData);
end;

{------------------------------------------------------------------------------}

constructor TRC4.Create(const EncryptionKey: string);
begin
  {initialize encryption engine}
  RC4Init(FData, PByteArray(EncryptionKey), Length(EncryptionKey));
end;

{------------------------------------------------------------------------------}
//check a file to see if the elapsed time is expired

function FileIsExpired(const FileName: string; Elapsed: Integer): Boolean;
var
  FHandle: Integer;
  FDate: TDateTime;
  FileTime: TTimeStamp;
  CurrentTime: TTimeStamp;
  DeltaTime: Integer;
begin
  FHandle := FileOpen(FileName, 0);
  try
    FDate := FileDateToDateTime(FileGetDate(FHandle));
    FileTime := DateTimeToTimeStamp(FDate);
    CurrentTime := DateTimeToTimeStamp(Now);
    DeltaTime := Round((CurrentTime.Time - FileTime.Time) / 60000);
    if (DeltaTime > Elapsed) then
      Result := True
    else
      Result := False;
  finally
    FileClose(FHandle);
  end;
end;

{------------------------------------------------------------------------------}

function GetTempDir: string;
{$IFDEF WIN32}
var
  Buf: array[0..MAX_PATH] of Char;
{$ENDIF}
begin
{$IFDEF WIN32}
  GetTempPath(Sizeof(Buf), Buf);
  Result := Buf;
  if Result[Length(Result)] <> '\' then
    Result := Result + '\';
{$ENDIF}
{$IFDEF LINUX}
  Result := '/var/tmp/';
{$ENDIF}
end;

{------------------------------------------------------------------------------}
{$IFDEF INDY9}

function Hash128AsHex(const Hash128Value: T4x4LongWordRecord): string;
begin
  Result := IntToHex(Hash128Value[0], 4) +
    IntToHex(Hash128Value[1], 4) +
    IntToHex(Hash128Value[2], 4) +
    IntToHex(Hash128Value[3], 4);
end;

{$ENDIF}
{------------------------------------------------------------------------------}

function FixEmptyString(const Value: string): string;
begin
  Result := StringReplace(Value, '<string></string>', '<string>[NULL]</string>',
    [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '<string></nil></string>',
    '<string>[NULL]</string>', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '<string></null></string>',
    '<string>[NULL]</string>', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '<string> </string>',
    '<string>[NULL]</string>', [rfReplaceAll, rfIgnoreCase]);

  // CLINTON 16/9/2003 - <string></string> was not compatable with XML-RPC spec.
  Result := StringReplace(Result,'<value></value>',
      '<value>[NULL]</value>', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result,'<value></nil></value>',
      '<value>[NULL]</value>', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result,'<value></null></value>',
      '<value>[NULL]</value>', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result,'<value> </value>',
      '<value>[NULL]</value>', [rfReplaceAll, rfIgnoreCase]);
end;

{$IFDEF ACTIVEX}

function StreamToVariant(Stream: TStream): OleVariant;
var
  V: OleVariant;
  P: Pointer;
begin
  V := VarArrayCreate([0, Stream.Size - 1], varByte);
  Stream.Position := 0;
  P := VarArrayLock(V);
  try
    Stream.Read(P^, Stream.Size);
  finally
    VarArrayUnlock(V);
  end;
  Result := V;
end;

procedure VariantToStream(V: OleVariant; Stream: TStream);
var
  P: Pointer;
begin
  Stream.Position := 0;
  Stream.Size := VarArrayHighBound(V, 1) - VarArrayLowBound(V, 1) + 1;
  P := VarArrayLock(V);
  Stream.Write(P^, Stream.Size);
  VarArrayUnlock(V);
  Stream.Position := 0;
end;

{$ENDIF}

end.

