unit mnXMLRttiWriter;
{**
 *  This file is part of the "Mini Library"
 *                  
 * @license   modifiedLGPL (modified of http://www.gnu.org/licenses/lgpl.html)
 *            See the file COPYING.MLGPL, included in this distribution,
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *}
interface

uses
  Classes, SysUtils, Variants, TypInfo,
  {$IFDEF FPC} LCLProc, {$ENDIF}
  mnXMLRtti, mnXMLFPClasses;

type
  TmnXMLRttiWriter = class(TmnXMLRttiCustomWriter)
  private
    FWriteTypes: Boolean;
    FRoot: TComponent;
    FWriteRefrences: Boolean;
  protected
    procedure DoStart; override;
    procedure WriteProperty(Instance: TObject; PropInfo: PPropInfo);
    procedure WriteProperties(Name:string; Instance: TObject; WithInitTag: Boolean);
    procedure WriteComponent(Component: TComponent);
    procedure WriteValue(Value:string; ValueType: string = '');
    procedure WriteVariant(Value:Variant);
  public
    constructor Create; override;
    procedure WriteObject(Instance: TObject); override;
    procedure WriteRoot(Instance: TObject); override;
    property WriteTypes: Boolean read FWriteTypes write FWriteTypes default True;
    property WriteRefrences: Boolean read FWriteRefrences write FWriteRefrences default False;
  end;

implementation

uses
  mnXMLUtils;

type
  THackComponent = class(TComponent);

{ TmnXMLRttiWriter }

//WriteObject taked from Classes.TWriter.WriteProperties

constructor TmnXMLRttiWriter.Create;
begin
  inherited;
  FWriteTypes := True;
end;

procedure TmnXMLRttiWriter.WriteComponent(Component: TComponent);
begin
  WriteProperties('', Component, True);
end;

procedure TmnXMLRttiWriter.WriteRoot(Instance: TObject);
begin
  if not Active then
    Start;
  if Instance is TComponent then
    FRoot := Instance as TComponent;
  WriteOpenTag('rtti', 'version="' + cRttiVersion + '" author="' + cRttiAuthor + '"');
  WriteProperties('', Instance, True);
  WriteCloseTag('rtti');
  FRoot := nil;
end;

procedure TmnXMLRttiWriter.WriteValue(Value:string; ValueType: string = '');
begin
  if ValueType <> '' then
    WriteAttributes('ValueType="' +  ValueType + '"');
  WriteStopTag;
  WriteText(Value);
end;

procedure TmnXMLRttiWriter.WriteVariant(Value: Variant);
var
  s:string;
begin
//Notice that varEmpty not saved
  case VarType(Value) and varTypeMask of
    varNull:
      WriteValue('');
    varString:
      WriteValue(Value, 'String');
    varOleStr:
      WriteValue(Value, 'OleStr');
    varByte:
      WriteValue(Value, 'Byte');
    varShortInt:
      WriteValue(Value, 'ShortInt');
    varWord:
      WriteValue(Value, 'Word');
    varSmallInt:
      WriteValue(Value, 'SmallInt');
    varInteger:
      WriteValue(Value, 'Integer');
    varSingle:
      WriteValue(Value, 'Single');
    varDouble:
      WriteValue(Value, 'Double');
    varCurrency:
      WriteValue(Value, 'Currency');
    varLongWord:
      WriteValue(Value, 'LongWord');
    varInt64:
      WriteValue(Value, 'Int64');
    varDate:
    begin
      s:= FormatDateTime('yyyy-mm-dd', Value);
      if Frac(Value) <> 0 then
        s:= s + FormatDateTime(' hh:nn:ss', Value);
      WriteValue(s, 'Date');
    end;
    varBoolean:
    begin
      if Value then
        WriteValue('True', 'Boolean')
      else
        WriteValue('False', 'Boolean');
    end;
  else
    try
    finally
    end;
  end;
end;

procedure TmnXMLRttiWriter.WriteProperties(Name:string; Instance: TObject; WithInitTag: Boolean);
var
  I, Count: Integer;
  PropInfo: PPropInfo;
  PropList: PPropList;
  List: TList;
begin
  if Instance is TPersistent then //TObject not support RTTI :-(
    Count := GetTypeData(Instance.ClassInfo)^.PropCount
  else
    Count := 0;
  if Count > 0 then
  begin
    List := TList.Create;
    {$IFDEF FPC}
    PropList := nil;
    {$ENDIF}
    GetMem(PropList, Count * SizeOf(Pointer));
    try
      GetPropInfos(Instance.ClassInfo, PropList);
      for I := 0 to Count - 1 do
      begin
        PropInfo := PropList^[I];
        if PropInfo = nil then
          Break;
        if IsStoredProp(Instance, PropInfo) and (PropInfo^.GetProc <> nil) and ((PropInfo^.SetProc <> nil) or (PropInfo^.PropType^.Kind in [tkClass, tkInterface])) then
          List.Add(PropInfo);
      end;
    finally
      FreeMem(PropList, Count * SizeOf(Pointer));
    end;

    Count := List.Count;
    if Count > 0 then
    begin
      if WithInitTag then
      begin
        if (Instance is TComponent) and ((Instance as TComponent).Name <> '') then
          WriteOpenTag('Object', 'Type="' + Instance.ClassName + '" Name="' + (Instance as TComponent).Name + '"')
        else
          WriteOpenTag('Object', 'Type="' + Instance.ClassName + '"');
      end;
      for i := 0 to Count - 1 do
      begin
        WriteProperty(Instance, PPropInfo(List[i]));
      end;
    end;
    List.Free;
  end;

  PermanentRegister.WriteClassProperties(Name, Self, Instance);

  if (Instance is TComponent) then
  begin
    THackComponent(Instance).GetChildren(WriteComponent, FRoot);
  end;

  if Count > 0 then
    if WithInitTag then
      WriteCloseTag('Object');
end;

procedure TmnXMLRttiWriter.WriteProperty(Instance: TObject; PropInfo: PPropInfo);
var
  PropType: PTypeInfo;
  procedure WriteIntProp;
  var
    S: string;
    IntToIdent: TIntToIdent;
    Value: Int64; //more compatible with FPC
  begin
    Value := GetOrdProp(Instance, PropInfo);
    IntToIdent := FindIntToIdent(PropType);
    S := '';
    if not ((Assigned(IntToIdent) and IntToIdent(Value, S))) then
      S := IntToStr(Value);
    WriteValue(S);
  end;

  procedure WriteEnumeration;
  var
    Value: Int64;
    S: string;
  begin
    Value := GetOrdProp(Instance, PropInfo);
    S := GetEnumName(PropType, Value);
    WriteValue(S);
  end;

  procedure WriteSet;
  var
    S: string;
  begin
    S := GetSetProp(Instance, PropInfo, False);
    WriteValue(S);
  end;

  procedure WriteChar;
  var
    Value: Char;
  begin
    Value := Char(GetOrdProp(Instance, PropInfo));
    WriteValue(Value);
  end;

  procedure WriteInt64Prop;
  var
    Value: Int64;
  begin
    Value := GetInt64Prop(Instance, PropInfo);
    WriteValue(IntToStr(Value));
  end;

  procedure WriteFloatProp;
  var
    Value: Extended;
  begin
    Value := GetFloatProp(Instance, PropInfo);
    WriteValue(FloatToStr(Value));
  end;

  procedure WriteWideStrProp;
  var
    Value: WideString;
  begin
    Value := GetWideStrProp(Instance, PropInfo);
    WriteValue(Value);
  end;

  procedure WriteStrProp;
  var
    Value: ansistring;
  begin
    Value := GetStrProp(Instance, PropInfo);
    WriteValue(Value);
  end;

  procedure WriteVariantProp;
  var
    Value: Variant;
  begin
    Value := GetVariantProp(Instance, PropInfo);
    WriteVariant(Value);
  end;

  procedure WriteObjectProp;
  var
    Value: TObject;
  begin
    Value := TObject(GetOrdProp(Instance, PropInfo));
    if (Value is TComponent) and not (csSubComponent in (Value as TComponent).ComponentStyle) then
    begin
      if WriteRefrences then
      begin
        WriteValue((Value as TComponent).Name);
      end;
    end
    else
    begin
      if (Value is TComponent) and ((Value as TComponent).Name <> '') then
        WriteAttributes('ID="' + (Value as TComponent).Name + '"');
      WriteStopTag;
      WriteProperties(PropInfo^.Name, Value, False);
    end;
  end;

  procedure WriteInterfaceProp;
  var
    Value: Pointer;
  begin
    Value := Pointer(Longword(GetOrdProp(Instance, PropInfo)));
    WriteStopTag;
    PermanentRegister.WriteInterface(PropInfo^.Name, Self, Value);
  end;

begin
  {$IFDEF FPC}
    if PropInfo.Name = 'Name' then
       debugln;
  {$ENDIF}
  if not IsDefaultValue(Instance, PropInfo) then
  begin
    PropType := GetPropType(PropInfo);
    if PropType^.Kind in [tkInteger, tkChar, tkSet, tkEnumeration, tkInt64, tkFloat, {$IFDEF FPC} tkAString, {$ENDIF} tkString, tkLString, tkWString, tkVariant, tkClass, tkInterface] then
    begin
      WriteStartTag(PropInfo^.Name);
      if FWriteTypes then
        WriteAttributes('Type="' + PropType.Name + '"');
      case PropType^.Kind of
        tkInteger:
          WriteIntProp;
        tkChar:
          WriteChar;
        tkSet:
          WriteSet;
        tkEnumeration:
          WriteEnumeration;
        tkInt64:
          WriteInt64Prop;
        tkFloat:
          WriteFloatProp;
        tkWString:
          WriteWideStrProp;
        {$IFDEF FPC} tkAString, {$ENDIF} tkString, tkLString:
          WriteStrProp;
        tkVariant:
          WriteVariantProp;
        tkClass:
          WriteObjectProp;
        tkMethod: ; //not yet
        tkInterface:
          WriteInterfaceProp;
      end;
      if TagStarted then
        WriteStopTag;
      WriteCloseTag(PropInfo^.Name);
    end;
  end;
end;

procedure TmnXMLRttiWriter.WriteObject(Instance: TObject);
begin
  WriteProperties('', Instance, True);
end;

procedure TmnXMLRttiWriter.DoStart;
begin
  inherited;
end;

end.

