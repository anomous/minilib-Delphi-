unit mncMySQL;
{**
 *  This file is part of the "Mini Connections"
 *
 * @license   modifiedLGPL (modified of http://www.gnu.org/licenses/lgpl.html)
 *            See the file COPYING.MLGPL, included in this distribution,
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *}

{$M+}
{$H+}
{$IFDEF FPC}
{$mode delphi}
{$ENDIF}

interface

uses
  Classes, SysUtils, Variants, ctypes,
  mncCommons, mncMetas, mncMySQLdyn,
  mncConnections, mncSQL;

type
  { TmncMySQLConnection }

  TmncMySQLConnection = class(TmncSQLConnection)
  private
    FDBHandle: PMYSQL;
    FExclusive: Boolean;
    FMultiCursors: Boolean;
    FReadCommited: Boolean;
    procedure SetExclusive(const AValue: Boolean);
    procedure SetMultiCursors(AValue: Boolean);
    procedure SetReadCommited(const AValue: Boolean);
  protected
    FDatabase: string;
    procedure InitPragma; virtual;
    procedure DoConnect; override;
    procedure DoDisconnect; override;
    function GetConnected:Boolean; override;
    procedure RaiseError(Error: Integer; const Msg: string; const ExtraMsg: string = '');
    procedure CheckError(Error: Integer; const ExtraMsg: string = ''); overload;
    procedure CheckError(vMySQL: PMYSQL); overload;
    procedure DoInit; override;
  public
    constructor Create;
    class function Model: TmncConnectionModel; override;
    function CreateSession: TmncSQLSession; overload; override; 
    procedure Interrupt;
    procedure SetCharsetName(Charset: string);
    function SelectDatabase(vName: string; RaiseException: Boolean = true): Boolean;
    function IsDatabaseExists(vName: string): Boolean;
    procedure CreateDatabase(const vName: string; CheckExists: Boolean = False); overload;
    procedure Vacuum;

    function GetVersion: string;
    procedure Execute(Command: string); override;
    property Exclusive: Boolean read FExclusive write SetExclusive;
    property ReadCommited: Boolean read FReadCommited write SetReadCommited;
    property DBHandle: PMYSQL read FDBHandle;
    property MultiCursors: Boolean read FMultiCursors write SetMultiCursors;
  end;

  { TmncMySQLSession }

  TmncMySQLSession = class(TmncSQLSession)
  private
    function GetConnection: TmncMySQLConnection;
    procedure SetConnection(const AValue: TmncMySQLConnection);
  protected
    //TODO Check Setting Connection when no database selected
    procedure DoInit; override;
    procedure DoStart; override;
    procedure DoStop(How: TmncSessionAction; Retaining: Boolean); override;
    function GetActive: Boolean; override;
  public
    constructor Create(vConnection: TmncConnection); override;
    destructor Destroy; override;
    function CreateCommand: TmncSQLCommand; override;
    function CreateMeta: TmncMeta; override;
    procedure Execute(SQL: string);
    property Connection: TmncMySQLConnection read GetConnection write SetConnection;
  end;

  { TmncMySQLField }

  TmncMySQLField = class(TmncField)
  private
    FValue: Variant;
  protected
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
  end;

  { TmncMySQLParam }

  TmncMySQLParam = class(TmncParam)
  private
    FValue: Variant;
  protected
    function GetValue: Variant; override;
    procedure SetValue(const AValue: Variant); override;
  public
    constructor Create; override;
    destructor Destroy; override;
  end;

  { TmncMySQLFields }

  TmncMySQLFields = class(TmncFields)
  protected
    function CreateField(vColumn: TmncColumn): TmncField; override;
  end;

  { TmncMySQLParams }

  TmncMySQLParams = class(TmncParams)
  protected
    function CreateParam: TmncParam; override;
  end;

  TMySQLBinds = array of MYSQL_BIND;

  { TmncMySQLBind }

  TmncMySQLBind = class(TmncBind)
  private
    FBuffer: Pointer;
    FBufferSize: Integer;
    function GetBufferAllocated: Boolean;
  protected
    function AllocBuffer(var P; Size: Integer): Pointer; virtual;
    procedure FreeBuffer;
    property Buffer: Pointer read FBuffer;
    property BufferSize: Integer read FBufferSize;
    property BufferAllocated: Boolean read GetBufferAllocated;
  public
    destructor Destroy; override;
  end;

  { TmncMySQLBinds }

  TmncMySQLBinds = class(TmncBinds)
  private
    function GetItem(Index: Integer): TmncMySQLBind;
  protected
    function CreateBind: TmncBind; override;
  public
    property Items[Index: Integer]: TmncMySQLBind read GetItem; default;
  end;

  { TmncMySQLColumn }

  TmncMySQLColumn = class(TmncColumn)
  public
    FieldType: enum_field_types;
    constructor Create(vName: string; vType: TmncDataType);
  end;

  { TmncMySQLColumns }

  TmncMySQLColumns = class(TmncColumns)
  private
    function GetItem(Index: Integer): TmncMySQLColumn;
  protected
  public
    property Items[Index: Integer]: TmncMySQLColumn read GetItem; default;
  end;

  { TmncMySQLResults }

  TmncMySQLResults = class(TObject)
  public
    Binds: array of MYSQL_BIND;

    Buffers : array of record
      buf: record case byte of
        0: (AsRaw: array[0..15] of byte);
        1: (AsInteger: Integer);
        2: (AsBig: int64);
        3: (AsFloat: double);
        4: (AsDateTime: MYSQL_TIME);
        5: (AsString: array[0..15] of Char);
      end;
      length: culong;
      is_null: my_bool;
      error: my_bool;
    end;
    constructor Create(vLength: Integer);
    destructor Destroy; override;
  end;

  { TmncMySQLCommand }

  TmncMySQLCommand = class(TmncSQLCommand)
  private
    FReadOnly: Boolean;
    FStatment: PMYSQL_STMT;
    FResults :TmncMySQLResults;
    FBOF: Boolean;
    FEOF: Boolean;
    function GetBinds: TmncMySQLBinds;
    function GetColumns: TmncMySQLColumns;
    function GetConnection: TmncMySQLConnection;
    procedure FetchColumns;
    procedure FetchValues;
    procedure ApplyParams;
    function GetSession: TmncMySQLSession;
    procedure SetReadOnly(AValue: Boolean);
    procedure SetSession(const AValue: TmncMySQLSession);
  protected
    procedure CheckError(Error:longint);
    procedure DoPrepare; override;
    procedure DoExecute; override;
    procedure DoNext; override;
    function GetEOF:Boolean; override;
    function GetActive:Boolean; override;
    procedure DoClose; override;
    procedure DoCommit; override;
    procedure DoRollback; override;
    function CreateFields(vColumns: TmncColumns): TmncFields; override;
    function CreateParams: TmncParams; override;
    function CreateBinds: TmncBinds; override;
    function CreateColumns: TmncColumns; override;
    property Binds: TmncMySQLBinds read GetBinds;

  public
    property Connection: TmncMySQLConnection read GetConnection;
    property Session: TmncMySQLSession read GetSession write SetSession;
    procedure Clear; override;
    property Statment: PMYSQL_STMT read FStatment;
    property Columns: TmncMySQLColumns read GetColumns;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly;
    function GetLastInsertID: Int64; virtual;
    function GetRowsChanged: Integer;
  end;

function MySQLTypeToType(vType: enum_field_types): TmncDataType;
function MySQLTypeToString(vType: enum_field_types): String;

implementation

uses
  mncMySQLMetas, mncDB;

const
  MySQL_OK = 0;

var
  IsInitializeMySQL: Boolean = False;

{ TmncMySQLResults }

constructor TmncMySQLResults.Create(vLength: Integer);
begin
  inherited Create;
  SetLength(Binds, vLength);
  SetLength(Buffers, vLength);
end;

destructor TmncMySQLResults.Destroy;
begin
  Binds := nil;
  Buffers := nil;
  inherited Destroy;
end;

{ TmncMySQLColumn }

constructor TmncMySQLColumn.Create(vName: string; vType: TmncDataType);
begin
  inherited Create;
  Name := vName;
  SetType(vType);
end;

{ TmncMySQLColumns }

function TmncMySQLColumns.GetItem(Index: Integer): TmncMySQLColumn;
begin
  Result := inherited Items[Index] as TmncMySQLColumn;
end;

{ TmncMySQLBind }

function TmncMySQLBind.GetBufferAllocated: Boolean;
begin
  Result := Buffer <> nil;
end;

function TmncMySQLBind.AllocBuffer(var P; Size: Integer): Pointer;
begin
  FreeBuffer;
  FBufferSize := Size;
  if Size > 0 then
  begin
    FBuffer := AllocMem(FBufferSize);
    Move(P, FBuffer^, Size);
  end;
  Result := FBuffer;
end;

procedure TmncMySQLBind.FreeBuffer;
begin
  if FBuffer <> nil then
    FreeMem(FBuffer);
  FBuffer := nil;
end;

destructor TmncMySQLBind.Destroy;
begin
  FreeBuffer;
  inherited;
end;

function MySQLTypeToType(vType: enum_field_types): TmncDataType;
begin
  case vType of
    MYSQL_TYPE_DECIMAL: Result := dtCurrency;
    MYSQL_TYPE_TINY: Result := dtInteger;
    MYSQL_TYPE_SHORT: Result := dtInteger;
    MYSQL_TYPE_LONG: Result := dtInteger;
    MYSQL_TYPE_FLOAT: Result := dtFloat;
    MYSQL_TYPE_DOUBLE: Result := dtFloat;
    MYSQL_TYPE_NULL: Result := dtUnknown;
    MYSQL_TYPE_TIMESTAMP: Result := dtDateTime;
    MYSQL_TYPE_LONGLONG: Result := dtBig;
    MYSQL_TYPE_INT24: Result := dtBig;
    MYSQL_TYPE_DATE: Result := dtDate;
    MYSQL_TYPE_TIME: Result := dtTime;
    MYSQL_TYPE_DATETIME: Result := dtDateTime;
    MYSQL_TYPE_YEAR: Result := dtDate;
    MYSQL_TYPE_NEWDATE: Result := dtDate;
    MYSQL_TYPE_VARCHAR: Result := dtString;
    MYSQL_TYPE_BIT: Result := dtBoolean;
    MYSQL_TYPE_TIMESTAMP2: Result := dtDateTime;
    MYSQL_TYPE_DATETIME2: Result := dtDateTime;
    MYSQL_TYPE_TIME2: Result := dtTime;
    MYSQL_TYPE_NEWDECIMAL: Result := dtCurrency;
    MYSQL_TYPE_ENUM: Result := dtInteger; //TODO dtEnum
    MYSQL_TYPE_SET: Result := dtBig;
    MYSQL_TYPE_TINY_BLOB: Result := dtBlob;
    MYSQL_TYPE_MEDIUM_BLOB: Result := dtBlob;
    MYSQL_TYPE_LONG_BLOB: Result := dtBlob;
    MYSQL_TYPE_BLOB: Result := dtBlob;
    MYSQL_TYPE_VAR_STRING: Result := dtString;
    MYSQL_TYPE_STRING: Result := dtString;
    MYSQL_TYPE_GEOMETRY: Result := dtBig; //TODO what is that!!!
  end;
end;


function MySQLTypeToString(vType: enum_field_types): String;
begin
  case vType of
    MYSQL_TYPE_DECIMAL: Result := 'DECIMAL';
    MYSQL_TYPE_TINY: Result := 'TINY';
    MYSQL_TYPE_SHORT: Result := 'SHORT';
    MYSQL_TYPE_LONG: Result := 'LONG';
    MYSQL_TYPE_FLOAT: Result := 'FLOAT';
    MYSQL_TYPE_DOUBLE: Result := 'DOUBLE';
    MYSQL_TYPE_NULL: Result := 'NULL';
    MYSQL_TYPE_TIMESTAMP: Result := 'TIMESTAMP';
    MYSQL_TYPE_LONGLONG: Result := 'LONGLONG';
    MYSQL_TYPE_INT24: Result := 'INT24';
    MYSQL_TYPE_DATE: Result := 'DATE';
    MYSQL_TYPE_TIME: Result := 'TIME';
    MYSQL_TYPE_DATETIME: Result := 'DATETIME';
    MYSQL_TYPE_YEAR: Result := 'YEAR';
    MYSQL_TYPE_NEWDATE: Result := 'NEWDATE';
    MYSQL_TYPE_VARCHAR: Result := 'VARCHAR';
    MYSQL_TYPE_BIT: Result := 'BIT';
    MYSQL_TYPE_TIMESTAMP2: Result := 'TIMESTAMP2';
    MYSQL_TYPE_DATETIME2: Result := 'DATETIME2';
    MYSQL_TYPE_TIME2: Result := 'TIME2';
    MYSQL_TYPE_NEWDECIMAL: Result := 'NEWDECIMAL';
    MYSQL_TYPE_ENUM: Result := 'ENUM';
    MYSQL_TYPE_SET: Result := 'SET';
    MYSQL_TYPE_TINY_BLOB: Result := 'TINY_BLOB';
    MYSQL_TYPE_MEDIUM_BLOB: Result := 'MEDIUM_BLOB';
    MYSQL_TYPE_LONG_BLOB: Result := 'LONG_BLOB';
    MYSQL_TYPE_BLOB: Result := 'BLOB';
    MYSQL_TYPE_VAR_STRING: Result := 'VAR_STRING';
    MYSQL_TYPE_STRING: Result := 'STRING';
    MYSQL_TYPE_GEOMETRY: Result := 'GEOMETRY';
  end;
end;

{ TmncMySQLBinds }

function TmncMySQLBinds.GetItem(Index: Integer): TmncMySQLBind;
begin
  Result := inherited Items[Index] as TmncMySQLBind;
end;

function TmncMySQLBinds.CreateBind: TmncBind;
begin
  Result := TmncMySQLBind.Create;
end;

function TmncMySQLParam.GetValue: Variant;
begin
  Result := FValue;
end;

procedure TmncMySQLParam.SetValue(const AValue: Variant);
begin
  FValue := AValue;
end;

constructor TmncMySQLParam.Create;
begin
  inherited;
end;

destructor TmncMySQLParam.Destroy;
begin
  inherited;
end;

function TmncMySQLField.GetValue: Variant;
begin
  Result := FValue;
end;

procedure TmncMySQLField.SetValue(const AValue: Variant);
begin
  FValue := AValue;
end;

{ TmncMySQLFields }

function TmncMySQLFields.CreateField(vColumn: TmncColumn): TmncField;
begin
  Result := TmncMySQLField.Create(vColumn);
end;

{ TmncMySQLParams }

function TmncMySQLParams.CreateParam: TmncParam;
begin
  Result := TmncMySQLParam.Create;
end;

procedure TmncMySQLConnection.CheckError(Error: Integer; const ExtraMsg: string);
var
  s : Utf8String;
begin
  if (Error <> MySQL_OK) then
  begin
    s := 'MySQL: ' + IntToStr(Error) + ', ' + mysql_error(FDBHandle);
    if ExtraMsg <> '' then
      s := s + ' - ' + ExtraMsg;
    raise EmncException.Create(s) {$ifdef fpc} at get_caller_frame(get_frame) {$endif};
  end;
end;

procedure TmncMySQLConnection.CheckError(vMySQL: PMYSQL);
begin
  if vMySQL = nil then
    RaiseError(mysql_errno(FDBHandle), mysql_error(FDBHandle));
end;

{ TmncMySQLConnection }

constructor TmncMySQLConnection.Create;
begin
  inherited Create;
  FMultiCursors := True;
end;

class function TmncMySQLConnection.Model: TmncConnectionModel;
begin
  Result.Name := 'MySQL';
  Result.Title := 'MySQL Database';
  Result.Capabilities := [ccDB, ccSQL, ccTransaction];
  //Result.MetaClass := TmncMySQLMeta;//TOdo
end;

function TmncMySQLConnection.CreateSession: TmncSQLSession;
begin
  Result := TmncMySQLSession.Create(Self);
end;

procedure TmncMySQLConnection.Interrupt;
begin
  mysql_kill(DBHandle, 0); //TODO
  //https://dev.mysql.com/doc/refman/5.0/en/mysql-kill.html
end;

procedure TmncMySQLConnection.SetCharsetName(Charset: string);
begin
  mysql_options(FDBHandle, MYSQL_SET_CHARSET_NAME, PChar(Charset));
end;

function TmncMySQLConnection.SelectDatabase(vName: string; RaiseException: Boolean): Boolean;
var
  r: Integer;
begin
  CheckActive;
  if Sessions.IsAnyActive then
    RaiseError(-1, 'You cant select database if you have opened sessions');
  r :=  mysql_select_db(FDBHandle, PChar(vName));
  Result := r = 0;
  if not Result then
  begin
    if RaiseException then
      CheckError(r);
  end
  else
    FDatabase := vName;
end;

function TmncMySQLConnection.IsDatabaseExists(vName: string): Boolean;
var
  s: string;
begin
  s := 'select count(*) as aCount from information_Meta.Metata where Meta_name = '''+ vName + '''';
  CheckError(mysql_query(FDBHandle, PChar(s)));
  //TODO
end;

procedure TmncMySQLConnection.CreateDatabase(const vName: string; CheckExists: Boolean);
var
  s: string;
begin
  CheckActive;
  s := 'Create Database ';
  if CheckExists then
    s := s + 'if not exists ';
  s := s + vName + ';';
  Execute(s);
end;

procedure TmncMySQLConnection.Vacuum;
begin
  //TODO
end;

function TmncMySQLConnection.GetVersion: string;
var
  p: integer;
begin
  p := mysql_get_server_version(FDBHandle);
  Result := IntToStr(p);
end;

procedure TmncMySQLConnection.DoConnect;
begin
  //TODO AutoCreate
  //* ref: https://dev.mysql.com/doc/refman/5.0/en/mysql-real-connect.html
  FDBHandle := mysql_init(FDBHandle);
  try
    //mysql_options(&mysql,MYSQL_READ_DEFAULT_GROUP,"your_prog_name");
    CheckError(mysql_real_connect(FDBHandle, PAnsiChar(Host), PChar(UserName), PChar(Password), nil, 0, nil, CLIENT_MULTI_RESULTS));
    if MultiCursors then
      CheckError(mysql_set_server_option(FDBHandle, MYSQL_OPTION_MULTI_STATEMENTS_ON))
    else
      CheckError(mysql_set_server_option(FDBHandle, MYSQL_OPTION_MULTI_STATEMENTS_OFF));
     SetCharsetName('utf8');
    if Resource <> '' then
      SelectDatabase(Resource);
  except
    on E:Exception do
    begin
      if FDBHandle <> nil then
        mysql_close(FDBHandle);
      FDBHandle := nil;
      raise;
    end;
  end;
  InitPragma;
end;

function TmncMySQLConnection.GetConnected: Boolean;
begin
  Result := FDBHandle <> nil;
end;

procedure TmncMySQLConnection.RaiseError(Error: Integer; const Msg: string; const ExtraMsg: string = '');
var
  s : string;
begin
  if (Error <> MySQL_OK) then
  begin
    s := 'MySQL: ' + IntToStr(Error) + ', ' + mysql_error(FDBHandle);
    if ExtraMsg <> '' then
      s := s + ' - ' + ExtraMsg;
    raise EmncException.Create(s) {$ifdef fpc} at get_caller_frame(get_frame) {$endif};
  end;
end;

procedure TmncMySQLConnection.DoDisconnect;
begin
  mysql_close(FDBHandle); //TODO check error
  FDBHandle := nil;
  {$ifdef FPC}
  ReleaseMySQL;
  {$endif}
end;

{ TmncMySQLSession }

destructor TmncMySQLSession.Destroy;
begin
  inherited;
end;

function TmncMySQLSession.CreateCommand: TmncSQLCommand;
begin
  Result := TmncMySQLCommand.Create;
  Result.Session := Self;
end;

function TmncMySQLSession.CreateMeta: TmncMeta;
begin
  Result := TmncMySQLMeta.CreateBy(Self);
end;

procedure TmncMySQLSession.Execute(SQL: string);
begin
  Connection.Execute(SQL);
end;

procedure TmncMySQLSession.DoStart;
begin
  Execute('BEGIN');
end;

procedure TmncMySQLSession.DoStop(How: TmncSessionAction; Retaining: Boolean);
begin
  case How of
    sdaCommit: Execute('COMMIT');
    sdaRollback: Execute('ROLLBACK');
  end;
  if Retaining then
    Execute('BEGIN');
end;

procedure TmncMySQLConnection.Execute(Command: string);
begin
  CheckError(mysql_query(FDBHandle, PChar(Command)));
end;

function TmncMySQLSession.GetActive: Boolean;
begin
  Result:= inherited GetActive;
end;

constructor TmncMySQLSession.Create(vConnection: TmncConnection);
begin
  inherited;
end;

function TmncMySQLSession.GetConnection: TmncMySQLConnection;
begin
  Result := inherited Connection as TmncMySQLConnection;
end;

procedure TmncMySQLConnection.DoInit;
begin
  if not IsInitializeMySQL then
  begin
    InitialiseMysql(mysqllib);
    IsInitializeMySQL := True;
  end;
end;

procedure TmncMySQLSession.SetConnection(const AValue: TmncMySQLConnection);
begin
  inherited Connection := AValue;
end;

procedure TmncMySQLConnection.SetExclusive(const AValue: Boolean);
begin
  if FExclusive <> AValue then
  begin
    if Active then
      raise EmncException.Create('You can not set Exclusive when session active');
    FExclusive := AValue;
  end;
end;

procedure TmncMySQLConnection.SetMultiCursors(AValue: Boolean);
begin
  if FMultiCursors <> AValue then
  begin
    FMultiCursors :=AValue;
    if Active then
    begin
      if MultiCursors then
        CheckError(mysql_set_server_option(FDBHandle, MYSQL_OPTION_MULTI_STATEMENTS_ON))
      else
        CheckError(mysql_set_server_option(FDBHandle, MYSQL_OPTION_MULTI_STATEMENTS_OFF))
    end;
  end;
end;

procedure TmncMySQLConnection.SetReadCommited(const AValue: Boolean);
begin
  if FReadCommited <> AValue then
  begin
    if Active then
      raise EmncException.Create('You can not set ReadCommited when session active');
    FReadCommited := AValue;
  end;
end;

procedure TmncMySQLConnection.InitPragma;
begin
end;

procedure TmncMySQLSession.DoInit;
begin
end;

{ TmncMySQLCommand }

procedure TmncMySQLCommand.CheckError(Error: longint);
var
  s : Utf8String;
begin
  if (Error <> MySQL_OK) then
  begin
    s := 'MySQL: ' + IntToStr(Error) + ', ' + mysql_stmt_error(FStatment) ;
    if Active then
    begin
      DoClose;
    end;
    raise EmncException.Create(s) {$ifdef fpc} at get_caller_frame(get_frame) {$endif};
  end;
end;

function TmncMySQLCommand.GetSession: TmncMySQLSession;
begin
  Result := inherited Session as TmncMySQLSession;
end;

procedure TmncMySQLCommand.SetReadOnly(AValue: Boolean);
begin
  CheckInactive;
  if FReadOnly <> AValue then
  begin
    FReadOnly := AValue;
  end;
end;

procedure TmncMySQLCommand.SetSession(const AValue: TmncMySQLSession);
begin
  inherited Session := AValue;
end;

procedure TmncMySQLCommand.Clear;
begin
  inherited;
  FBOF := True;
end;

function TmncMySQLCommand.GetEOF: Boolean;
begin
  Result := (FStatment = nil) or FEOF; 
end;

function TmncMySQLCommand.GetRowsChanged: Integer;
begin
  CheckActive;
  Result := mysql_stmt_affected_rows(FStatment);
end;

function TmncMySQLCommand.GetLastInsertID: Int64;
begin
  CheckActive;
  Result := mysql_stmt_insert_id(FStatment);
end;

function MySQLDateTimeToDateTime(ATime: MYSQL_TIME): TDateTime;
begin
  Result := ComposeDateTime(EncodeDate(ATime.year, ATime.month, ATime.day),EncodeTime(ATime.hour, ATime.minute, ATime.second, ATime.second_part));
end ;

procedure DateTimeToMySQLDateTime(DateTime: TDateTime; out ATime: MYSQL_TIME);
var
  st: TSystemTime;
begin
  DateTimeToSystemTime(DateTime, st);
  ATime.Year := st.Year;
  ATime.Month := st.Month;
  ATime.Day := st.Day;
  ATime.Hour := st.Hour;
  ATime.Minute := st.Minute;
  ATime.Second := st.Second;
  ATime.second_part := st.Millisecond;
  ATime.neg := 0;
  ATime.time_type := MYSQL_TIMESTAMP_DATETIME;
end ;

procedure DateTimeToMySQLTime(DateTime: TDateTime; out ATime: MYSQL_TIME);
begin
  DateTimeToMySQLDateTime(DateTime, ATime);
  ATime.time_type := MYSQL_TIMESTAMP_TIME;
end ;

procedure DateTimeToMySQLDate(DateTime: TDateTime; out ATime: MYSQL_TIME);
begin
  DateTimeToMySQLDateTime(DateTime, ATime);
  ATime.time_type := MYSQL_TIMESTAMP_DATE;
end ;

procedure TmncMySQLCommand.ApplyParams;
var
  s: UTF8String;
  dt: MYSQL_TIME;
  tiny: smallint;

  i: Integer;
  d: Double;
  n: Integer;
  t64: Int64;
  Values: TMySQLBinds;
begin
  //* ref: https://dev.mysql.com/doc/refman/5.0/en/mysql-stmt-bind-param.html
  //* ref: https://dev.mysql.com/doc/refman/5.0/en/mysql-stmt-execute.html
  //* https://dev.mysql.com/doc/refman/5.0/en/c-api-prepared-statement-type-codes.html
  if Binds.Count > 0 then
  begin
    SetLength(Values, Binds.Count);
    for i := 0 to Binds.Count - 1 do
    begin
      if Binds[i].Param.IsEmpty then
      begin
        n := 1;
        Values[i].is_null := Binds[i].AllocBuffer(n, SizeOf(n));
      end
      else
      begin
        case VarType(Binds[i].Param.Value) of
          varDate:
          begin
            DateTimeToMySQLDateTime(Binds[i].Param.Value, dt);
            Values[i].buffer := Binds[i].AllocBuffer(dt, SizeOf(dt));
            Values[i].buffer_length := SizeOf(dt);
            Values[i].buffer_type := MYSQL_TYPE_DATETIME;
          end;
          varBoolean:
          begin
            tiny := Ord(Boolean(Binds[i].Param.Value));
            Values[i].buffer := Binds[i].AllocBuffer(tiny, SizeOf(tiny));
            Values[i].buffer_length := SizeOf(tiny);
            Values[i].buffer_type := MYSQL_TYPE_TINY;
          end;
          varInteger:
          begin
            n := Ord(Integer(Binds[i].Param.Value));
            Values[i].buffer := Binds[i].AllocBuffer(n, SizeOf(n));
            Values[i].buffer_length := 0;
            Values[i].buffer_type := MYSQL_TYPE_LONG;
          end;
          varint64:
          begin
            t64 := Binds[i].Param.Value;
            Values[i].buffer := Binds[i].AllocBuffer(t64, SizeOf(t64));
            Values[i].buffer_length := 0;
            Values[i].buffer_type := MYSQL_TYPE_LONGLONG;
          end;
          varCurrency:
          begin
            t64 := Binds[i].Param.Value;
            Values[i].buffer := Binds[i].AllocBuffer(t64, SizeOf(t64)); //TODO it should be not MYSQL_TYPE_NEWDECIMAL
            Values[i].buffer_length := 0;
            Values[i].buffer_type := MYSQL_TYPE_NEWDECIMAL;
          end;
          varDouble:
          begin
            d := Binds[i].Param.Value;
            Values[i].buffer := Binds[i].AllocBuffer(d, SizeOf(d));
            Values[i].buffer_length := 0;
            Values[i].buffer_type := MYSQL_TYPE_DOUBLE;
          end;
          else //String type
          begin
            s := VarToStrDef(Binds[i].Param.Value, '');
            Values[i].buffer := Binds[i].AllocBuffer(PChar(s)^, Length(s));
            Values[i].buffer_length := Length(s);
            Values[i].buffer_type := MYSQL_TYPE_VAR_STRING;
          end;
        end;
      end;
    end;
    CheckError(mysql_stmt_bind_param(FStatment, @Values[0]));
  end;
end;

procedure TmncMySQLCommand.DoExecute;
begin
  FBOF := True;
  ApplyParams;
  CheckError(mysql_stmt_execute(FStatment));
end;

procedure TmncMySQLCommand.DoNext;
var
  b: Boolean;
  state: integer;
begin
  if FBOF then
    FetchColumns;
  state := mysql_stmt_fetch(FStatment);
  b := state in [0, MYSQL_DATA_TRUNCATED];
  if (b) then
  begin
    FetchValues;
    FEOF := False;
  end
  else
  begin
    FEOF := True;
  end;
  FBOF := False;
end;

procedure TmncMySQLCommand.DoPrepare;
var
  aType: enum_cursor_type;
begin
  //* ref: https://dev.mysql.com/doc/refman/5.0/en/mysql-stmt-prepare.html
  FBOF := True;
  if FStatment <> nil then
    CheckError(mysql_stmt_reset(FStatment))
  else
    FStatment := mysql_stmt_init(Connection.DBHandle);
  try
    if ReadOnly then
    begin
      aType := CURSOR_TYPE_READ_ONLY;
      CheckError(mysql_stmt_attr_set(FStatment, STMT_ATTR_CURSOR_TYPE, @aType));
    end;
    CheckError(mysql_stmt_prepare(FStatment, PChar(SQLProcessed.SQL), Length(SQLProcessed.SQL)));
  except
    on E: Exception do
    begin
      //FStatment := nil;
      raise;
    end;
  end;
end;

procedure TmncMySQLCommand.DoRollback;
begin
  Session.Rollback;
end;

function TmncMySQLCommand.CreateFields(vColumns: TmncColumns): TmncFields;
begin
  Result := TmncMySQLFields.Create(vColumns);
end;

function TmncMySQLCommand.CreateParams: TmncParams;
begin
  Result := TmncMySQLParams.Create;
end;

function TmncMySQLCommand.CreateBinds: TmncBinds;
begin
  Result := TmncMySQLBinds.Create;
end;

function TmncMySQLCommand.CreateColumns: TmncColumns;
begin
  Result := TmncMySQLColumns.Create();
end;

procedure TmncMySQLCommand.DoClose;
begin
  FreeAndNil(FResults);
  mysql_stmt_free_result(FStatment);
  mysql_stmt_close(FStatment);
  FStatment := nil;
end;

procedure TmncMySQLCommand.DoCommit;
begin
  Session.Commit;
end;

procedure TmncMySQLCommand.FetchColumns;
var
  i: Integer;
  c: Integer;
  aName: string;
  FieldType: enum_field_types;
  MetaType: string;
  aColumn: TmncMySQLColumn;
  //aSize: Integer;
  Res : PMYSQL_RES;
  Field: PMYSQL_FIELD;
begin
  Columns.Clear;

  Res := mysql_stmt_result_metadata(FStatment); // Fetch result set meta information
  try
    c := mysql_stmt_field_count(FStatment);
    if c > 0 then
    begin
      Field := mysql_fetch_fields(Res);

      FResults := TmncMySQLResults.Create(c);

      for i := 0 to c -1 do
      begin
        aName :=  Field.name;
        FieldType := Field.ftype;
        MetaType := MySQLTypeToString(FieldType);

        aColumn := TmncMySQLColumn.Create(aName, MySQLTypeToType(FieldType));

        Columns.Add(aColumn);

        aColumn.MetaType := MetaType;
        aColumn.Size := Field.length;
        aColumn.FieldType := FieldType;

        FillByte(FResults.Binds[i], sizeof(FResults.Binds[i]), 0);

        FResults.Binds[i].buffer_type := FieldType;

        if FieldType in [MYSQL_TYPE_NEWDECIMAL] then
          FResults.Binds[i].buffer_type := MYSQL_TYPE_DOUBLE;

        FResults.Binds[i].buffer := @FResults.Buffers[i].buf;
        FResults.Binds[i].buffer_length := SizeOf(FResults.Buffers[i].buf);

        FResults.Binds[i].length := @FResults.Buffers[i].length;
        FResults.Binds[i].is_null := @FResults.Buffers[i].is_null;
        FResults.Binds[i].error := @FResults.Buffers[i].error;

        Inc(Field);
      end;
      CheckError(mysql_stmt_bind_result(FStatment, @FResults.Binds[0]));
    end;
  finally
    //CheckError(mysql_free_result(Res));
  end;
end;

procedure TmncMySQLCommand.FetchValues;
var
  i: Integer;
{$ifdef fpc}
  s: string;
{$else}
  str: utf8string;
{$endif}
  aCurrent: TmncFields;
  aType: enum_field_types;
  aColumn: TmncMySQLColumn;
  real_length: culong;
  bind: MYSQL_BIND;
begin
  if Columns.Count > 0 then
  begin
    aCurrent := CreateFields(Columns);
    for i := 0 to Columns.Count - 1 do
    begin
      aColumn := Columns[i];
      aType := aColumn.FieldType;

      case aType of
        MYSQL_TYPE_NULL: aCurrent.Add(i, NULL);
        MYSQL_TYPE_BIT: aCurrent.Add(i, FResults.Buffers[i].buf.AsInteger <> 0);
        MYSQL_TYPE_TINY: aCurrent.Add(i, FResults.Buffers[i].buf.AsInteger);
        MYSQL_TYPE_SHORT: aCurrent.Add(i, FResults.Buffers[i].buf.AsInteger);
        MYSQL_TYPE_LONG: aCurrent.Add(i, FResults.Buffers[i].buf.AsInteger);
        MYSQL_TYPE_INT24: aCurrent.Add(i, FResults.Buffers[i].buf.AsBig);
        MYSQL_TYPE_LONGLONG: aCurrent.Add(i, FResults.Buffers[i].buf.AsBig);
        MYSQL_TYPE_FLOAT: aCurrent.Add(i, FResults.Buffers[i].buf.AsFloat);
        MYSQL_TYPE_DOUBLE: aCurrent.Add(i, FResults.Buffers[i].buf.AsFloat);
        MYSQL_TYPE_YEAR : aCurrent.Add(i, FResults.Buffers[i].buf.AsInteger);
        MYSQL_TYPE_TIMESTAMP, MYSQL_TYPE_DATETIME, MYSQL_TYPE_NEWDATE,  MYSQL_TYPE_DATE,
        MYSQL_TYPE_TIME, MYSQL_TYPE_TIMESTAMP2, MYSQL_TYPE_DATETIME2, MYSQL_TYPE_TIME2:
        begin
          aCurrent.Add(i, MySQLDateTimeToDateTime(FResults.Buffers[i].buf.AsDateTime));
        end;
        MYSQL_TYPE_VARCHAR,MYSQL_TYPE_VAR_STRING, MYSQL_TYPE_STRING:
        begin
          real_length := FResults.Buffers[i].length;
          if real_length <= SizeOf(FResults.Buffers[i].buf) then
            s := FResults.Buffers[i].buf.AsString
          else
          begin
            SetLength(s, real_length);
            Finalize(bind);

            bind.buffer := @s[1];
            bind.buffer_length := real_length;
            CheckError(mysql_stmt_fetch_column(FStatment, @bind, i, 0));
          end;
          aCurrent.Add(i, s);
        end;

        MYSQL_TYPE_DECIMAL, MYSQL_TYPE_NEWDECIMAL:
        //* ref: https://dev.mysql.com/doc/refman/5.0/en/fixed-point-types.html
        //* ref: http://stackoverflow.com/questions/6831217/double-vs-decimal-in-mysql
          aCurrent.Add(i, FResults.Buffers[i].buf.AsFloat);
        MYSQL_TYPE_ENUM: aCurrent.Add(i, FResults.Buffers[i].buf.AsInteger);
        MYSQL_TYPE_SET: aCurrent.Add(i, FResults.Buffers[i].buf.AsInteger);

        MYSQL_TYPE_TINY_BLOB, MYSQL_TYPE_MEDIUM_BLOB, MYSQL_TYPE_LONG_BLOB,
        MYSQL_TYPE_BLOB, MYSQL_TYPE_GEOMETRY:
        begin
        end;
      end;
    end;
    Fields := aCurrent;
  end;
end;

function TmncMySQLCommand.GetActive: Boolean;
begin
  Result := FStatment <> nil; 
end;

function TmncMySQLCommand.GetConnection: TmncMySQLConnection;
begin
  Result := Session.Connection as TmncMySQLConnection;
end;

function TmncMySQLCommand.GetBinds: TmncMySQLBinds;
begin
  Result := inherited Binds as TmncMySQLBinds;
end;

function TmncMySQLCommand.GetColumns: TmncMySQLColumns;
begin
  Result := inherited Columns as TmncMySQLColumns;
end;

initialization
  mncDB.Engines.Add(TmncMySQLConnection);
end.
