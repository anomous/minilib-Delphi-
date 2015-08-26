unit mncCSV;
{$M+}{$H+}{$IFDEF FPC}{$MODE delphi}{$ENDIF}
{**
 *  This file is part of the "Mini Connections"
 *
 * @license   modifiedLGPL (modified of http://www.gnu.org/licenses/lgpl.html)
 *            See the file COPYING.MLGPL, included in this distribution,
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *}

interface

uses
  Classes, SysUtils, Variants,
  mnUtils, mncConnections, mnStreams;

type
  {
    hdrNone: There is no header in export and import files
    hdrNormal: Header is the first line contain field names
    hdrIgnore: Header found for import files but ignored, header not exported
  }
  TmncCSVHeader = (hdrNone, hdrNormal, hdrIgnore);
  TmncEmptyLine = (elFetch, elSkip, elEOF);

  TmncCSVOptions = record
    EndOfLine: string;
    DelimiterChar: Char;
    EscapeChar: Char; //TODO take it from mncCSVExchanges
    QuoteChar: Char;
    HeaderLine: TmncCSVHeader;
    ANSIContents: Boolean; //TODO take it from mncCSVExchanges
  end;


  { TmncCSVConnection }

  TmncCSVConnection = class(TmncConnection)
  private
    FConnected: Boolean;
  protected
    procedure DoConnect; override;
    procedure DoDisconnect; override;
    function GetConnected: Boolean; override;
  public
    class function Model: TmncConnectionModel; override;
    constructor Create;
  end;

  { TmncCSVSession }

  TmncCSVSession = class(TmncSession)
  private
    FCSVOptions: TmncCSVOptions;
  protected
    procedure DoStart; override;
    procedure DoStop(How: TmncSessionAction; Retaining: Boolean); override;
  public
    constructor Create(vConnection: TmncConnection); override;
    property CSVOptions: TmncCSVOptions read FCSVOptions write FCSVOptions;
    property DelimiterChar: Char read FCSVOptions.DelimiterChar write FCSVOptions.DelimiterChar default #9;
    property QuoteChar: Char read FCSVOptions.QuoteChar write FCSVOptions.QuoteChar default '"';
    property EndOfLine: string read FCSVOptions.EndOfLine write FCSVOptions.EndOfLine;
    property HeaderLine: TmncCSVHeader read FCSVOptions.HeaderLine write FCSVOptions.HeaderLine default hdrNormal;
  end;

  TmncCSVMode = (csvmRead, csvmWrite);

  { TmncCSVCommand }

  TmncCSVCommand = class(TmncCommand)
  private
    FEmptyLine: TmncEmptyLine;

    FCSVStream: TmnWrapperStream;
    FStream: TStream;
    FMode: TmncCSVMode;
    function GetConnection: TmncCSVConnection;
    function GetSession: TmncCSVSession;
  protected
    procedure DoParse; override;
    function CreateFields(vColumns: TmncColumns): TmncFields; override;
    function CreateParams: TmncParams; override;
    procedure PrepareParams;
    procedure LoadHeader;
    procedure SaveHeader;
    procedure LoadRecord;
    procedure SaveRecord;
    function ReadLine(var Strings: TStringList): Boolean;
    procedure WriteLine(S: string); //Because i am not trust with Strings.Text
    procedure DoPrepare; override;
    procedure DoExecute; override;
    procedure DoNext; override;
    function GetEOF: Boolean; override;
    function GetActive: Boolean; override;
    procedure DoClose; override;
    property Session: TmncCSVSession read GetSession;
    property Connection: TmncCSVConnection read GetConnection;
  public
    constructor Create(vSession: TmncSession; vStream: TStream; vMode: TmncCSVMode); overload;
    destructor Destroy; override;
    property Mode: TmncCSVMode read FMode;
    //property Stream: TStream read FStream write SetStream;//TODO
    //EOFOnEmpty: when True make EOF when read empty line  
    property EmptyLine: TmncEmptyLine read FEmptyLine write FEmptyLine;
  end;

implementation

{ TmncCSVConnection }

constructor TmncCSVConnection.Create;
begin
  inherited Create;
end;

procedure TmncCSVConnection.DoConnect;
begin
  FConnected := True;
end;

function TmncCSVConnection.GetConnected: Boolean;
begin
  Result := FConnected;
end;

class function TmncCSVConnection.Model: TmncConnectionModel;
begin
  Result.Name := 'CSV';
  Result.Title := 'CSV Files';
  Result.Capabilities := [];
  Result.SchemaClass := nil;
end;

procedure TmncCSVConnection.DoDisconnect;
begin
  FConnected := False;
end;

{ TmncCSVSession }

procedure TmncCSVSession.DoStart;
begin
end;

procedure TmncCSVSession.DoStop(How: TmncSessionAction; Retaining: Boolean);
begin
end;

constructor TmncCSVSession.Create(vConnection: TmncConnection);
begin
  inherited;
  HeaderLine := hdrNormal;
  DelimiterChar := ';';
  EndOfLine := sUnixEndOfLine;
  QuoteChar := '"';
end;

{ TmncCSVCommand }

constructor TmncCSVCommand.Create(vSession: TmncSession; vStream: TStream; vMode: TmncCSVMode);
begin
  CreateBy(vSession);
  FMode := vMode;
  FStream := vStream;
end;

destructor TmncCSVCommand.Destroy;
begin
  inherited;
end;

function TmncCSVCommand.GetEOF: Boolean;
begin
  Result := (Mode = csvmWrite) or (FCSVStream = nil);// do not check (FCSVStream.EOF) last line will not loaded;
end;

procedure TmncCSVCommand.DoExecute;
begin
  if (Mode = csvmWrite) then
  begin
    SaveRecord;
  end;
end;

procedure TmncCSVCommand.DoNext;
begin
  if Mode = csvmRead then
    LoadRecord;
end;

procedure TmncCSVCommand.DoPrepare;
begin
  FCSVStream := TmnWrapperStream.Create(FStream, False);
  FCSVStream.EndOfLine := Session.EndOfLine;
  if Session.HeaderLine <> hdrNone then
  begin
    if (Mode = csvmWrite) then
      SaveHeader
    else
      LoadHeader;
  end;
  PrepareParams;
end;

procedure TmncCSVCommand.DoClose;
begin
  FreeAndNil(FCSVStream);
end;

function TmncCSVCommand.GetActive: Boolean;
begin
  Result := FCSVStream = nil;
end;

function TmncCSVCommand.GetConnection: TmncCSVConnection;
begin
  Result := Session.Connection as TmncCSVConnection;
end;

function TmncCSVCommand.GetSession: TmncCSVSession;
begin
  Result := (Inherited Session) as TmncCSVSession;
end;

procedure TmncCSVCommand.DoParse;
begin
  //Nothing to do
end;

function TmncCSVCommand.CreateFields(vColumns: TmncColumns): TmncFields;
begin
  Result := TmncVariantFields.Create(vColumns);
end;

function TmncCSVCommand.CreateParams: TmncParams;
begin
  Result := TmncVariantParams.Create;
end;

procedure TmncCSVCommand.LoadHeader;
var
  aStrings: TStringList;
  i: Integer;
begin
  Columns.Clear;
  aStrings := nil;
  if ReadLine(aStrings) then
  begin
    try
      for i := 0 to aStrings.Count - 1 do
      begin
        Columns.Add(i, trim(aStrings[i]), dtString);
      end;
    finally
      aStrings.Free;
    end;
  end
  else
    FreeAndNil(FCSVStream);//close it for make EOF
end;

procedure TmncCSVCommand.LoadRecord;
var
  aStrings: TStringList;
  aRecord: TmncFields;
  i: Integer;
begin
  aStrings := nil;
  if ReadLine(aStrings) then
  begin
    aRecord := CreateFields(Columns);
    i := 0;
    try
      while (i < aStrings.Count) {and (i < Columns.Count)} do //TODO check it
      begin
        aRecord.Add(i, aStrings[i]);
        Inc(i); 
      end;
    finally
      aStrings.Free;
    end;
    Fields := aRecord;
  end
  else
    FreeAndNil(FCSVStream);//close it for make EOF
end;

procedure TmncCSVCommand.PrepareParams;
var
  i: Integer;
  aParams: TmncParams;
begin
  aParams := CreateParams;
  for i := 0 to Columns.Count - 1 do
    aParams.Add(Columns[i].Name);
  Params := aParams;
end;

function TmncCSVCommand.ReadLine(var Strings: TStringList): Boolean;
var
  s: string;
begin
  Result := (FCSVStream <> nil) and not FCSVStream.EOF;
  if Result then
  begin
    s := '';
    Strings := TStringList.Create;

    repeat
      Result := FCSVStream.ReadLn(s, False);
      s := Trim(s);
    until not Result or not ((s = '') and (EmptyLine = elSkip));

    Result := Result and not ((s = '') and (EmptyLine = elEOF));
    if Result then
      StrToStrings(s, Strings, [Session.DelimiterChar], [#0, #13, #10], True, [Session.QuoteChar]);
  end;
end;

procedure TmncCSVCommand.SaveHeader;
var
  i: Integer;
  s: string;
begin
  s := '';
  for i := 0 to Columns.Count - 1 do
  begin
    if s <> '' then
      s := s + Session.DelimiterChar;
    s := s + Columns[i].Name;
  end;
  WriteLine(s);
end;

procedure TmncCSVCommand.SaveRecord;
var
  i: Integer;
  s: string;
  v: Variant;
  First: Boolean;
begin
  s := '';
  First := True;
  for i := 0 to Params.Count - 1 do
  begin
    if not First then
      s := s + Session.DelimiterChar
    else
      First := False;
    v := Params.Items[i].Value;
    s := s + VarToStrDef(v, '');
  end;
  WriteLine(s);
end;

procedure TmncCSVCommand.WriteLine(S: string);
begin
  FCSVStream.WriteLn(s);
end;

end.
