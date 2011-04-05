unit PHPProcessor;
{$mode delphi}
{**
 *  Light PHP Edit project
 *
 *  This file is part of the "Mini Library"
 *
 * @url       http://www.sourceforge.net/projects/minilib
 * @license   modifiedLGPL (modified of http://www.gnu.org/licenses/lgpl.html)
 *            See the file COPYING.MLGPL, included in this distribution,
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *}
interface

uses
  SysUtils, Messages, Graphics, Registry, Controls,
  SynEdit, SynEditTextBuffer, SynHighlighterHTMLPHP, Contnrs, Classes, SynEditTypes, SynEditHighlighter, SynHighlighterHashEntries;

type
  TPHPRangeState = (rsphpUnknown, rsphpComment, rsphpStringSQ, rsphpStringDQ, rsphpVarExpansion);

//PHP Processor

  TPHPProcessor = class(TSynProcessor)
  protected
    FRange: TPHPRangeState;
    function GetIdentChars: TSynIdentChars; override;
    procedure ResetRange; override;
    function GetRange: Byte; override;
    procedure SetRange(Value: Byte); override;
    function KeyHash(ToHash: PChar): Integer; override;
  public
    procedure QuestionProc;
    procedure AndSymbolProc;
    procedure LineCommentProc;
    procedure CommentProc;
    procedure SlashProc;
    procedure StringProc;
    procedure StringSQProc;
    procedure StringDQProc;
    procedure VarExpansionProc;
    procedure EqualProc;
    procedure IdentProc;
    procedure CRProc;
    procedure LFProc;
    procedure GreaterProc;
    procedure LowerProc;
    procedure MinusProc;
    procedure NullProc;
    procedure NumberProc;
    procedure OrSymbolProc;
    procedure PlusProc;
    procedure SpaceProc;
    procedure SymbolProc;
    procedure SymbolAssignProc;
    procedure VariableProc;
    procedure UnknownProc;
    procedure Next; override;

    procedure InitIdent; override;
    procedure MakeMethodTables; override;
    procedure MakeIdentTable; override;
  end;

implementation

uses
  SynEditStrConst, VarUtils;

procedure TPHPProcessor.MakeIdentTable;
var
  c: char;
begin
  FillChar(Identifiers, SizeOf(Identifiers), 0);
  for c := 'a' to 'z' do
    Identifiers[c] := True;
  for c := 'A' to 'Z' do
    Identifiers[c] := True;
  for c := '0' to '9' do
    Identifiers[c] := True;
  Identifiers['_'] := True;

  FillChar(HashTable, SizeOf(HashTable), 0);
  HashTable['_'] := 1;
  for c := 'a' to 'z' do
    HashTable[c] := 2 + Ord(c) - Ord('a');
  for c := 'A' to 'Z' do
    HashTable[c] := 2 + Ord(c) - Ord('A');
end;

procedure TPHPProcessor.AndSymbolProc;
begin
  Parent.FTokenID := tkSymbol;
  Inc(Parent.Run);
  if Parent.FLine[Parent.Run] in ['=', '&'] then
    Inc(Parent.Run);
end;

{procedure TPHPProcessor.StringProc;
var
  iCloseChar: char;
begin
  Parent.FTokenID := tkString;
  if fRange = rsphpStringSQ then
    iCloseChar := ''''
  else
    iCloseChar := '"';
  while not (Parent.FLine[Parent.Run] in [#0, #10, #13]) do
  begin
    if (Parent.FLine[Parent.Run] = iCloseChar) then
    begin
      FRange := rsphpUnKnown;
      Inc(Parent.Run);
      break;
    end;
    Inc(Parent.Run);
  end;
end;}

procedure TPHPProcessor.StringProc;

  function IsEscaped: boolean;
  var
    iFirstSlashPos: integer;
  begin
    iFirstSlashPos := Parent.Run - 1;
    while (iFirstSlashPos > 0) and (Parent.FLine[iFirstSlashPos] = '\') do
      Dec(iFirstSlashPos);
    Result := (Parent.Run - iFirstSlashPos + 1) mod 2 <> 0;
  end;

var
  iCloseChar: char;
begin
  Parent.FTokenID := tkString;
  if fRange = rsphpStringSQ then
    iCloseChar := ''''
  else
    iCloseChar := '"';
  while not (Parent.FLine[Parent.Run] in [#0, #10, #13]) do
  begin
    if (Parent.FLine[Parent.Run] = iCloseChar) and (not IsEscaped) then
    begin
      FRange := rsphpUnKnown;
      inc(Parent.Run);
      break;
    end;
    if (iCloseChar = '"') and (Parent.FLine[Parent.Run] = '$') and
       ((Parent.FLine[Parent.Run + 1] = '{') or Identifiers[Parent.FLine[Parent.Run + 1]]) then
    begin
      if (Parent.Run > 1) and (Parent.FLine[Parent.Run - 1] = '{') then { complex syntax }
        Dec(Parent.Run);
      if not IsEscaped then
      begin
        { break the token to process the variable }
        fRange := rsphpVarExpansion;
        break;
      end
      else if Parent.FLine[Parent.Run] = '{' then
        Inc(Parent.Run); { restore Run if we previously deincremented it }
    end;
    Inc(Parent.Run);
  end;
end;

procedure TPHPProcessor.CRProc;
begin
  Parent.FTokenID := tkSpace;
  Inc(Parent.Run);
  if Parent.FLine[Parent.Run] = #10 then
    Inc(Parent.Run);
end;

procedure TPHPProcessor.EqualProc;
begin
  Parent.FTokenID := tkSymbol;
  Inc(Parent.Run);
  if Parent.FLine[Parent.Run] in ['=', '>'] then
    Inc(Parent.Run);
end;

procedure TPHPProcessor.GreaterProc;
begin
  Parent.FTokenID := tkSymbol;
  Inc(Parent.Run);
  if Parent.FLine[Parent.Run] in ['=', '>'] then
    Inc(Parent.Run);
end;

procedure TPHPProcessor.IdentProc;
begin
  Parent.FTokenID := IdentKind((Parent.FLine + Parent.Run));
  inc(Parent.Run, FStringLen);
  if Parent.FTokenID = tkComment then
  begin
    while not (Parent.FLine[Parent.Run] in [#0, #10, #13]) do
      Inc(Parent.Run);
  end
  else
    while Identifiers[Parent.FLine[Parent.Run]] do
      inc(Parent.Run);
end;

procedure TPHPProcessor.LFProc;
begin
  Parent.FTokenID := tkSpace;
  inc(Parent.Run);
end;

procedure TPHPProcessor.LowerProc;
begin
  Parent.FTokenID := tkSymbol;
  Inc(Parent.Run);
  case Parent.FLine[Parent.Run] of
    '=': Inc(Parent.Run);
    '<':
      begin
        Inc(Parent.Run);
        if Parent.FLine[Parent.Run] = '=' then
          Inc(Parent.Run);
      end;
  end;
end;

procedure TPHPProcessor.MinusProc;
begin
  Parent.FTokenID := tkSymbol;
  Inc(Parent.Run);
  if Parent.FLine[Parent.Run] in ['=', '-'] then
    Inc(Parent.Run);
end;

procedure TPHPProcessor.NullProc;
begin
  Parent.FTokenID := tkNull;
end;

procedure TPHPProcessor.NumberProc;
begin
  inc(Parent.Run);
  Parent.FTokenID := tkNumber;
  while Parent.FLine[Parent.Run] in ['0'..'9', '.', '-'] do
  begin
    case Parent.FLine[Parent.Run] of
      '.':
        if Parent.FLine[Parent.Run + 1] = '.' then
          break;
    end;
    inc(Parent.Run);
  end;
end;

procedure TPHPProcessor.OrSymbolProc;
begin
  Parent.FTokenID := tkSymbol;
  Inc(Parent.Run);
  if Parent.FLine[Parent.Run] in ['=', '|'] then
    Inc(Parent.Run);
end;

procedure TPHPProcessor.PlusProc;
begin
  Parent.FTokenID := tkSymbol;
  Inc(Parent.Run);
  if Parent.FLine[Parent.Run] in ['=', '+'] then
    Inc(Parent.Run);
end;

procedure TPHPProcessor.SlashProc;
begin
  Inc(Parent.Run);
  case Parent.FLine[Parent.Run] of
    '/':
      begin
        Parent.FTokenID := tkComment;
        repeat
          Inc(Parent.Run);
        until Parent.FLine[Parent.Run] in [#0, #10, #13];
      end;
    '*':
      begin
        Parent.FTokenID := tkComment;
        Inc(Parent.Run);
        CommentProc;
      end;
    '=':
      begin
        Inc(Parent.Run);
        Parent.FTokenID := tkSymbol;
      end;
  else
    Parent.FTokenID := tkSymbol;
  end;
end;

procedure TPHPProcessor.SpaceProc;
begin
  Parent.FTokenID := tkSpace;
  repeat
    Inc(Parent.Run);
  until (Parent.FLine[Parent.Run] > #32) or (Parent.FLine[Parent.Run] in [#0, #10, #13]);
end;

procedure TPHPProcessor.SymbolProc;
begin
  Inc(Parent.Run);
  Parent.FTokenID := tkSymbol;
end;

procedure TPHPProcessor.SymbolAssignProc;
begin
  Parent.FTokenID := tkSymbol;
  Inc(Parent.Run);
  if Parent.FLine[Parent.Run] = '=' then
    Inc(Parent.Run);
end;

procedure TPHPProcessor.VariableProc;
var
  i: integer;
begin
  Parent.FTokenID := tkVariable;
  i := Parent.Run;
  repeat
    Inc(i);
  until not (Identifiers[Parent.FLine[i]]);
  Parent.Run := i;
end;

procedure TPHPProcessor.UnknownProc;
begin
  inc(Parent.Run);
  Parent.FTokenID := tkUnknown;
end;

procedure TPHPProcessor.CommentProc;
begin
  FRange := rsphpComment;
  Parent.FTokenID := tkComment;
  while not (Parent.FLine[Parent.Run] in [#0, #10, #13]) do
  begin
    if (Parent.FLine[Parent.Run] = '*') and (Parent.FLine[Parent.Run + 1] = '/') then
    begin
      FRange := rsphpUnKnown;
      Inc(Parent.Run, 2);
      break;
    end;
    Inc(Parent.Run);
  end;
end;

procedure TPHPProcessor.MakeMethodTables;
var
  I: Char;
begin
  for I := #0 to #255 do
    case I of
      #0: ProcTable[I] := NullProc;
      #10: ProcTable[I] := LFProc;
      #13: ProcTable[I] := CRProc;
      '?': ProcTable[I] := QuestionProc;
      '''': ProcTable[I] := StringSQProc;
      '"': ProcTable[I] := StringDQProc;
      '#': ProcTable[I] := LineCommentProc;
      '/': ProcTable[I] := SlashProc;
      '=': ProcTable[I] := EqualProc;
      '>': ProcTable[I] := GreaterProc;
      '<': ProcTable[I] := LowerProc;
      '-': ProcTable[I] := MinusProc;
      '|': ProcTable[I] := OrSymbolProc;
      '+': ProcTable[I] := PlusProc;
      '&': ProcTable[I] := AndSymbolProc;
      '$': ProcTable[I] := VariableProc;
      'A'..'Z', 'a'..'z', '_':
        ProcTable[I] := IdentProc;
      '0'..'9':
        ProcTable[I] := NumberProc;
      #1..#9, #11, #12, #14..#32:
        ProcTable[I] := SpaceProc;
      '^', '%', '*', '!':
        ProcTable[I] := SymbolAssignProc;
      '{', '}', '.', ',', ';', '(', ')', '[', ']', '~':
        ProcTable[I] := SymbolProc;
    else
      ProcTable[I] := UnknownProc;
    end;
end;

procedure TPHPProcessor.QuestionProc;
begin
  Inc(Parent.Run);
  case Parent.FLine[Parent.Run] of
    '>':
      begin
        Parent.Processors.Switch(Parent.Processors.MainProcessor);
        Inc(Parent.Run);
        Parent.FTokenID := tkProcessor;
      end
  else
    Parent.FTokenID := tkSymbol;
  end;
end;

procedure TPHPProcessor.Next;
begin
  Parent.FTokenPos := Parent.Run;
  case FRange of
    rsphpComment:
    begin
      if (Parent.FLine[Parent.Run] in [#0, #10, #13]) then
        ProcTable[Parent.FLine[Parent.Run]]
      else
        CommentProc;
    end;
    rsphpStringSQ, rsphpStringDQ:
      if (Parent.FLine[Parent.Run] in [#0, #10, #13]) then
        ProcTable[Parent.FLine[Parent.Run]]
      else
        StringProc;
    rsphpVarExpansion:
      VarExpansionProc;
  else
    ProcTable[Parent.FLine[Parent.Run]];
  end;
end;

procedure TPHPProcessor.VarExpansionProc;
type
  TExpansionSyntax = (esNormal, esComplex, esBrace);
var
  iSyntax: TExpansionSyntax;
  iOpenBraces: integer;
  iOpenBrackets: integer;
  iTempRun: integer;
begin
  fRange := rsphpStringDQ; { var expansion only occurs in double quoted strings }
  Parent.FTokenID := tkVariable;
  if Parent.FLine[Parent.Run] = '{' then
  begin
    iSyntax := esComplex;
    Inc(Parent.Run, 2); { skips '{$' }
  end
  else
  begin
    Inc(Parent.Run);
    if Parent.FLine[Parent.Run] = '{' then
    begin
      iSyntax := esBrace;
      Inc(Parent.Run);
    end
    else
      iSyntax := esNormal;
  end;
  if iSyntax in [esBrace, esComplex] then
  begin
    iOpenBraces := 1;
    while Parent.FLine[Parent.Run] <> #0 do
    begin
      if Parent.FLine[Parent.Run] = '}' then
      begin
        Dec(iOpenBraces);
        if iOpenBraces = 0 then
        begin
          Inc(Parent.Run);
          break;
        end;
      end;
      if Parent.FLine[Parent.Run] = '{' then
        Inc(iOpenBraces);
      Inc(Parent.Run);
    end;
  end
  else
  begin
    while Identifiers[Parent.FLine[Parent.Run]] do
      Inc(Parent.Run);
    iOpenBrackets := 0;
    iTempRun := Parent.Run;
    { process arrays and objects }
    while Parent.FLine[iTempRun] <> #0 do
    begin
      if Parent.FLine[iTempRun] = '[' then
      begin
        Inc(iTempRun);
        if Parent.FLine[iTempRun] = '''' then
        begin
          Inc(iTempRun);
          while (Parent.FLine[iTempRun] <> '''') and (Parent.FLine[iTempRun] <> #0) do
            Inc(iTempRun);
          if (Parent.FLine[iTempRun] = '''') and (Parent.fLine[iTempRun + 1] = ']') then
          begin
            Inc(iTempRun, 2);
            Parent.Run := iTempRun;
            continue;
          end
          else
            break;
        end
        else
          Inc(iOpenBrackets);
      end
      else if (Parent.FLine[iTempRun] = '-') and (Parent.FLine[iTempRun + 1] = '>') then
        Inc(iTempRun, 2)
      else
        break;

      if not Identifiers[Parent.FLine[iTempRun]] then
        break
      else
        repeat
          Inc(iTempRun);
        until not Identifiers[Parent.FLine[iTempRun]];

      while Parent.FLine[iTempRun] = ']' do
      begin
        if iOpenBrackets = 0 then
          break;
        Dec(iOpenBrackets);
        Inc(iTempRun);
      end;
      if iOpenBrackets = 0 then
        Parent.Run := iTempRun;
    end;
  end;
end;

procedure TPHPProcessor.StringDQProc;
begin
  fRange := rsphpStringDQ;
  Inc(Parent.Run);
  StringProc;
end;

procedure TPHPProcessor.StringSQProc;
begin
  fRange := rsphpStringSQ;
  Inc(Parent.Run);
  StringProc;
end;

function TPHPProcessor.GetRange: Byte;
begin
  Result := Byte(FRange);
end;

procedure TPHPProcessor.ResetRange;
begin
  inherited;
  FRange := rsphpUnknown;
end;

procedure TPHPProcessor.SetRange(Value: Byte);
begin
  FRange := TPHPRangeState(Value);
end;

procedure TPHPProcessor.InitIdent;
begin
  inherited;
  EnumerateKeywords(Ord(tkKeyword), sPHPControls, TSynValidStringChars, DoAddKeyword);
  EnumerateKeywords(Ord(tkKeyword), sPHPKeywords, TSynValidStringChars, DoAddKeyword);
  EnumerateKeywords(Ord(tkFunction), sPHPFunctions, TSynValidStringChars, DoAddKeyword);
  EnumerateKeywords(Ord(tkValue), sPHPConstants, TSynValidStringChars, DoAddKeyword);
  EnumerateKeywords(Ord(tkVariable), sPHPVariables, TSynValidStringChars, DoAddKeyword);
  FRange := rsphpUnknown;
end;

function TPHPProcessor.KeyHash(ToHash: PChar): Integer;
begin
  Result := 0;
  while ToHash^ in ['_', '0'..'9', 'a'..'z', 'A'..'Z'] do
  begin
    inc(Result, HashTable[ToHash^]);
    inc(ToHash);
  end;
  fStringLen := ToHash - fToIdent;
end;

function TPHPProcessor.GetIdentChars: TSynIdentChars;
begin
  Result := TSynValidStringChars + ['$'];
end;

procedure TPHPProcessor.LineCommentProc;
begin
  Inc(Parent.Run);
  Parent.FTokenID := tkComment;
  repeat
    Inc(Parent.Run);
  until Parent.FLine[Parent.Run] in [#0, #10, #13];
end;

end.
