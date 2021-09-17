unit mncPGHeader;
{ postgresql 13.x }
{$IFDEF FPC}
{$MODE delphi}
{$PACKRECORDS C}
{$ENDIF}

{$M+}{$H+}

{$MINENUMSIZE 4} //All enum must be sized as Integer
{$Z4}{$A8}

{**
 *  This file is part of the "Mini Connections"
 *
 * @license   modifiedLGPL (modified of http://www.gnu.org/licenses/lgpl.html)
 *            See the file COPYING.MLGPL, included in this distribution,
 * @author    Zaher Dirkey <zaher, zaherdirkey>
 * @author    Belal Hamed <belalhamed at gmail dot com>  
 *
 *}
 {
   Initially this file ported from Lazarus just to be compatiple in both Delphi and FPC
   But we updated it from postgresql 13.x

   src/interfaces/libpq/libpq-fe.h
 }

interface

uses
  mnLibraries,
  SysUtils;


const

  OIDNAMELEN = 36;

  INV_WRITE = $00020000;
  INV_READ = $00040000;

  BLOB_SEEK_SET = 0;
  BLOB_SEEK_CUR = 1;
  BLOB_SEEK_END = 2;

  OID_BOOL     = 16;
  OID_BYTEA    = 17;
  OID_TEXT     = 25;
  OID_OID      = 26;
  OID_NAME     = 19;
  OID_INT8     = 20;
  OID_INT2     = 21;
  OID_INT4     = 23;
  OID_FLOAT4   = 700;
  OID_MONEY    = 790;
  OID_FLOAT8   = 701;
  OID_UNKNOWN  = 705;
  OID_BPCHAR   = 1042;
  OID_VARCHAR  = 1043;
  OID_TIMESTAMP = 1114;
  OID_DATE      = 1082;
  OID_TIME      = 1083;
  OID_NUMERIC   = 1700;

  {
   * Option flags for PQcopyResult
  }
  PG_COPYRES_ATTRS		     = $01;
  PG_COPYRES_TUPLES		     = $02;	{ Implies PG_COPYRES_ATTRS }
  PG_COPYRES_EVENTS		     = $04;
  PG_COPYRES_NOTICEHOOKS	 = $08;


{ ****************** Plain API Types definition ***************** }

type

  OID = Integer;

{ Application-visible enum types }

  TConnStatusType = (
    CONNECTION_OK,
    CONNECTION_BAD,

  	{ Non-blocking mode only below here }

  	{
  	 * The existence of these should never be relied upon - they should only
  	 * be used for user feedback or similar purposes.
  	 }
  	CONNECTION_STARTED,			{ Waiting for connection to be made.  }
  	CONNECTION_MADE,			{ Connection OK; waiting to send.     }
  	CONNECTION_AWAITING_RESPONSE,	{ Waiting for a response from the
  									 * postmaster.        }
  	CONNECTION_AUTH_OK,			{ Received authentication; waiting for
  								 * backend startup. }
  	CONNECTION_SETENV,			{ Negotiating environment. }
  	CONNECTION_SSL_STARTUP,		{ Negotiating SSL. }
  	CONNECTION_NEEDED,			{ Internal state: connect() needed }
  	CONNECTION_CHECK_WRITABLE,	{ Check if we could make a writable
  								 * connection. }
  	CONNECTION_CONSUME,			{ Wait for any pending message and consume
  								 * them. }
  	CONNECTION_GSS_STARTUP,		{ Negotiating GSSAPI. }
  	CONNECTION_CHECK_TARGET		{ Check if we have a proper target connection }
    );

  TPostgresPollingStatusType = (
  	PGRES_POLLING_FAILED = 0,
  	PGRES_POLLING_READING,		{ These two indicate that one may	  }
  	PGRES_POLLING_WRITING,		{ use select before polling again.   }
  	PGRES_POLLING_OK,
  	PGRES_POLLING_ACTIVE		{ unused; keep for awhile for backwards
  								 * compatibility }
  );

  TExecStatusType = (
    PGRES_EMPTY_QUERY = 0,		{ empty query string was executed }
    PGRES_COMMAND_OK,			{ a query command that doesn't return
                                 * anything was executed properly by the
                                 * backend }
    PGRES_TUPLES_OK,			{ a query command that returns tuples was
                                 * executed properly by the backend, PGresult
                                 * contains the result tuples }
    PGRES_COPY_OUT,				{ Copy Out data transfer in progress }
    PGRES_COPY_IN,				{ Copy In data transfer in progress }
    PGRES_BAD_RESPONSE,			{ an unexpected response was recv'd from the
                                 * backend }
    PGRES_NONFATAL_ERROR,		{ notice or warning message }
    PGRES_FATAL_ERROR,			{ query failed }
    PGRES_COPY_BOTH,			{ Copy In/Out data transfer in progress }
    PGRES_SINGLE_TUPLE			{ single tuple from larger resultset }
  );

  TPGTransactionStatusType = (
      PQTRANS_IDLE,				{ connection idle }
      PQTRANS_ACTIVE,				{ command in progress }
      PQTRANS_INTRANS,			{ idle, within transaction block }
      PQTRANS_INERROR,			{ idle, within failed transaction }
      PQTRANS_UNKNOWN				{ cannot determine status }
  );

  TPGVerbosity = (
      PQERRORS_TERSE,				{ single-line error messages }
      PQERRORS_DEFAULT,			{ recommended style }
      PQERRORS_VERBOSE,			{ all the facts, ma'am }
      PQERRORS_SQLSTATE			{ only error severity and SQLSTATE code }
  );

  TPGContextVisibility = (
      PQSHOW_CONTEXT_NEVER,		{ never show CONTEXT field }
      PQSHOW_CONTEXT_ERRORS,		{ show CONTEXT for errors only (default) }
      PQSHOW_CONTEXT_ALWAYS		{ always show CONTEXT field }
  );

  {
   * PGPing - The ordering of this enum should not be altered because the
   * values are exposed externally via pg_isready.
  }

  TPGPing = (
      PQPING_OK,					{ server is accepting connections }
      PQPING_REJECT,				{ server is alive but rejecting connections }
      PQPING_NO_RESPONSE,			{ could not establish connection }
      PQPING_NO_ATTEMPT			{ connection not attempted (bad params) }
  );

{
  PGconn encapsulates a connection to the backend.
  The contents of this struct are not supposed to be known to applications.
}
  TPGconn = type Pointer;
  PPGconn = ^TPGconn;

{
   PGresult encapsulates the result of a query (or more precisely, of a single
   SQL command --- a query string given to PQsendQuery can contain multiple
   commands and thus return multiple PGresult objects).
   The contents of this struct are not supposed to be known to applications.
}
  TPGresult = type Pointer;
  PPGresult = ^TPGresult;

{
  PGcancel encapsulates the information needed to cancel a running
  query on an existing connection.
  The contents of this struct are not supposed to be known to applications.
}
  TPGcancel = type Pointer;
  PPGcancel= ^TPGcancel;

{
  PGnotify represents the occurrence of a NOTIFY message.
  Ideally this would be an opaque typedef, but it's so simple that it's
  unlikely to change.
  NOTE: in Postgres 6.4 and later, the be_pid is the notifying backend's,
  whereas in earlier versions it was always your own backend's PID.
}
  PPGnotify = ^TPGnotify;
  TPGnotify = packed record
    relname: PAnsiChar; { notification condition name }
    be_pid: Integer;  { process ID of notifying server process }
    extra: PAnsiChar; { notification parameter }
    { Fields below here are private to libpq; apps should not use 'em }
    next: PPGnotify;		{ list link }
  end;

{ PQnoticeProcessor is the function type for the notice-message callback. }

  PQnoticeProcessor = procedure(arg: Pointer; message: PAnsiChar); cdecl;

{ Print options for PQprint() }

{
  We can't use the conventional "bool", because we are designed to be
  included in a user's program, and user may already have that type
  defined.  Pqbool, on the other hand, is unlikely to be used.
}

  PPChar = array[00..$FF] of PAnsiChar;

  PQprintOpt = packed record
    header: Byte; { print output field headings and row count }
    align: Byte; { fill align the fields }
    standard: Byte; { old brain dead format }
    html3: Byte; { output html tables }
    expanded: Byte; { expand tables }
    pager: Byte; { use pager for output if needed }
    fieldSep: PAnsiChar; { field separator }
    tableOpt: PAnsiChar; { insert to HTML <table ...> }
    caption: PAnsiChar; { HTML <caption> }
    fieldName: PPChar; { null terminated array of repalcement field names }
  end;

  PPQprintOpt = ^PQprintOpt;

{ ----------------
  Structure for the conninfo parameter definitions returned by PQconndefaults
  ----------------
}
  PQconninfoOption = packed record
    keyword: PAnsiChar; { The keyword of the option }
    envvar: PAnsiChar; { Fallback environment variable name }
    compiled: PAnsiChar; { Fallback compiled in default value  }
    val: PAnsiChar; { Options value	}
    lab: PAnsiChar; { Label for field in connect dialog }
    dispchar: PAnsiChar; { Character to display for this field
     in a connect dialog. Values are:
     ""	Display entered value as is
     "*"	Password field - hide value
     "D"	Debug options - don't
     create a field by default }
    dispsize: Integer; { Field size in characters for dialog }
  end;

  PPQConninfoOption = ^PQconninfoOption;

{ ----------------
  PQArgBlock -- structure for PQfn() arguments
  ----------------
}
  PQArgBlock = packed record
    len: Integer;
    isint: Integer;
    case u: Boolean of
      True: (ptr: PInteger); { can't use void (dec compiler barfs)	 }
      False: (_int: Integer);
  end;

  PPQArgBlock = ^PQArgBlock;

  {* ----------------
   * Exported functions of libpq
   * ----------------
   *}

  { ===	in fe-connect.c === }

  { make a new client connection to the backend }
  { Asynchronous (non-blocking) }

  TPQconnectStart = function(ConnInfo: PAnsiChar): PPGconn; cdecl;
  TPQconnectStartParams = function(Keywords: Pointer; Values: Pointer; expand_dbname: Integer): PPGconn; cdecl;
  TPQconnectPoll = function(conn: PPGconn): TPostgresPollingStatusType; cdecl;

  TPQconnectdb = function(ConnInfo: PAnsiChar): PPGconn; cdecl;
  TPQconnectdbParams = function(Keywords: Pointer; Values: Pointer; expand_dbname: Integer): PPGconn; cdecl;
  TPQsetdbLogin = function(Host, Port, Options, Tty, Db, User, Passwd: PAnsiChar): PPGconn; cdecl;

  TPQfinish = procedure(conn: PPGconn); cdecl;
  TPQconndefaults = function: PPQconninfoOption; cdecl;

  TPQreset = procedure(conn: PPGconn); cdecl;

//15022006 FirmOS: omitting PQresetStart
//15022006 FirmOS: omitting PQresetPoll

  TPQrequestCancel = function(Handle: PPGconn): Integer; cdecl;

  TPQdb = function(Handle: PPGconn): PAnsiChar; cdecl;
  TPQuser = function(Handle: PPGconn): PAnsiChar; cdecl;
  TPQpass = function(Handle: PPGconn): PAnsiChar; cdecl;
  TPQhost = function(Handle: PPGconn): PAnsiChar; cdecl;
  TPQport = function(Handle: PPGconn): PAnsiChar; cdecl;
  TPQtty = function(Handle: PPGconn): PAnsiChar; cdecl;
  TPQoptions = function(Handle: PPGconn): PAnsiChar; cdecl;
  TPQstatus = function(Handle: PPGconn): TConnStatusType; cdecl;

//TBD  PGTransactionStatusType PQtransactionStatus(const PGconn *conn);

//15022006 FirmOS: omitting const char *PQparameterStatus(const PGconn *conn, const char *paramName);

//15022006 FirmOS: omitting  PQprotocolVersion
//15022006 FirmOS: omitting  PQserverVersion

  TPQerrorMessage = function(Handle: PPGconn): PAnsiChar; cdecl;
  TPQsocket = function(Handle: PPGconn): Integer; cdecl;
  TPQbackendPID = function(Handle: PPGconn): Integer; cdecl;

//15022006 FirmOS: omitting  SSL *PQgetssl(const PGconn *conn);


  TPQtrace = procedure(Handle: PPGconn; DebugPort: Pointer); cdecl;
  TPQuntrace = procedure(Handle: PPGconn); cdecl;
  TPQsetNoticeProcessor = procedure(Handle: PPGconn; Proc: PQnoticeProcessor; Arg: Pointer); cdecl;

{ === in fe-exec.c === }

  TPQexec = function(Handle: PPGconn; Query: PAnsiChar): PPGresult; cdecl;
  TPQnotifies = function(Handle: PPGconn): PPGnotify; cdecl;
  TPQfreeNotify = procedure(Handle: PPGnotify); cdecl;
  TPQsendQuery = function(Handle: PPGconn; Query: PAnsiChar): Integer; cdecl;
  TPQgetResult = function(Handle: PPGconn): PPGresult; cdecl;
  TPQisBusy = function(Handle: PPGconn): Integer; cdecl;
  TPQconsumeInput = function(Handle: PPGconn): Integer; cdecl;
  TPQgetline = function(Handle: PPGconn; Str: PAnsiChar; length: Integer): Integer; cdecl;
  TPQputline = function(Handle: PPGconn; Str: PAnsiChar): Integer; cdecl;
  TPQgetlineAsync = function(Handle: PPGconn; Buffer: PAnsiChar; BufSize: Integer): Integer; cdecl;
  TPQputnbytes = function(Handle: PPGconn; Buffer: PAnsiChar; NBytes: Integer): Integer; cdecl;
  TPQendcopy = function(Handle: PPGconn): Integer; cdecl;

  //* Set blocking/nonblocking connection to the backend */
  TPQsetnonblocking = function(conn: PPGconn; arg: Integer): Integer; cdecl;
  TPQisnonblocking = function(conn: PPGconn): Integer; cdecl;
  TPQisthreadsafe = function(): Integer; cdecl;
  TPQping = function(ConnInfo: PAnsiChar): TPGPing; cdecl;
  TPQpingParams = function(Keywords: Pointer; Values: Pointer; expand_dbname: Integer): TPGPing; cdecl;

  TPQfn = function(Handle: PPGconn; fnid: Integer; result_buf, result_len: PInteger; result_is_int: Integer; args: PPQArgBlock; nargs: Integer): PPGresult; cdecl;
  TPQresultStatus = function(Result: PPGresult): TExecStatusType; cdecl;
  TPQresultErrorMessage = function(Result: PPGresult): PAnsiChar; cdecl;

  //PAnsiChar = PUtf8Char
  TPQPrepare = function(Handle: PPGconn; Name, Query: PAnsiChar; nParams: Integer; pTypes: Pointer): PPGresult; cdecl;
  TPQExecPrepared = function(Handle: PPGconn; Name: PAnsiChar; nParams: Integer; pValues, pLength, pFormats: Pointer; rFormat: Integer): PPGresult; cdecl;
  TPQdescribePrepared = function(Handle: PPGconn; Name: PAnsiChar): PPGresult; cdecl;
  TPQnparams  = function(Result: PPGresult): Integer; cdecl;
  TPQparamtype = function(Result: PPGresult; param_num: Integer): Integer; cdecl;
  TPQsendQueryPrepared = function(Handle: PPGconn; Name: PAnsiChar; nParams: Integer; pValues, pLength, pFormats: Pointer; rFormat: Integer): Integer; cdecl;
  TPQsetSingleRowMode = function(Handle: PPGconn): Integer; cdecl;

  //p = params
  //r = result

//new  char *PQresultErrorField(const PGresult *res, int fieldcode);
  TPQresultErrorField = function(result: PPGResult; fieldcode: integer): PAnsiChar; cdecl;

  TPQntuples = function(Result: PPGresult): Integer; cdecl;
  TPQnfields = function(Result: PPGresult): Integer; cdecl;
  TPQbinaryTuples = function(Result: PPGresult): Integer; cdecl;
  TPQfname = function(Result: PPGresult; field_num: Integer): PAnsiChar; cdecl;
  TPQfnumber = function(Result: PPGresult; field_name: PAnsiChar): Integer; cdecl;
  TPQftype = function(Result: PPGresult; field_num: Integer): OID; cdecl;
  TPQfsize = function(Result: PPGresult; field_num: Integer): Integer; cdecl;
  TPQfmod = function(Result: PPGresult; field_num: Integer): Integer; cdecl;
  TPQcmdStatus = function(Result: PPGresult): PAnsiChar; cdecl;
  TPQoidValue = function(Result: PPGresult): OID; cdecl;
  TPQoidStatus = function(Result: PPGresult): PAnsiChar; cdecl;
  TPQcmdTuples = function(Result: PPGresult): PAnsiChar; cdecl;
  TPQgetvalue = function(Result: PPGresult; tup_num, field_num: Integer): PAnsiChar; cdecl;
  TPQgetlength = function(Result: PPGresult; tup_num, field_num: Integer): Integer; cdecl;
  TPQgetisnull = function(Result: PPGresult; tup_num, field_num: Integer): Integer; cdecl;
  TPQclear = procedure(Result: PPGresult); cdecl;
  TPQmakeEmptyPGresult = function(Handle: PPGconn; status: TExecStatusType): PPGresult; cdecl;

//FirmOS: New defines

  TPQescapeByteaConn = function(Handle: PPGconn; const from: PAnsiChar; from_length: longword; to_lenght: PLongword): PAnsiChar; cdecl;
  TPQescapeBytea = function(const from: PByte; from_length: longword; to_lenght: PLongword): PByte; cdecl;

//TODO  TPQescapeString    =function(const from:PAnsiChar;from_length:longword;to_lenght:PLongword):PAnsiChar;cdecl;

//unsigned char *PQescapeByteaConn(PGconn *conn,
//                                 const unsigned char *from,
//                                 size_t from_length,
//                                 size_t *to_length);
  TPQunescapeBytea = function(const from: PByte; to_lenght: PLongword): PByte; cdecl;
//unsigned char *PQunescapeBytea(const unsigned char *from, size_t *to_length);

  TPQFreemem = procedure(ptr: Pointer); cdecl;

{ === in fe-lobj.c === }
  Tlo_open = function(Handle: PPGconn; lobjId: OID; mode: Integer): Integer; cdecl;
  Tlo_close = function(Handle: PPGconn; fd: Integer): Integer; cdecl;
  Tlo_read = function(Handle: PPGconn; fd: Integer; buf: PAnsiChar; len: Integer): Integer; cdecl;
  Tlo_write = function(Handle: PPGconn; fd: Integer; buf: PAnsiChar; len: Integer): Integer; cdecl;
  Tlo_lseek = function(Handle: PPGconn; fd, offset, whence: Integer): Integer; cdecl;
  Tlo_creat = function(Handle: PPGconn; mode: Integer): OID; cdecl;
  Tlo_tell = function(Handle: PPGconn; fd: Integer): Integer; cdecl;
  Tlo_unlink = function(Handle: PPGconn; lobjId: OID): Integer; cdecl;
  Tlo_import = function(Handle: PPGconn; filename: PAnsiChar): OID; cdecl;
  Tlo_export = function(Handle: PPGconn; lobjId: OID; filename: PAnsiChar): Integer; cdecl;
  Tlo_truncate = function(Handle: PPGconn; fd, len: Integer): Integer; cdecl;

var

  PQconnectStart: TPQconnectStart;
  PQconnectStartParams: TPQconnectStartParams;
  PQconnectPoll: TPQconnectPoll;

  PQconnectdb: TPQconnectdb;
  PQsetdbLogin: TPQsetdbLogin;
  PQfinish: TPQfinish;
  PQconndefaults: TPQconndefaults;

  PQreset: TPQreset;
  PQrequestCancel: TPQrequestCancel;
  PQdb: TPQdb;
  PQuser: TPQuser;
  PQpass: TPQpass;
  PQhost: TPQhost;
  PQport: TPQport;
  PQtty: TPQtty;
  PQoptions: TPQoptions;
  PQstatus: TPQstatus;
  PQerrorMessage: TPQerrorMessage;
  PQsocket: TPQsocket;
  PQbackendPID: TPQbackendPID;
  PQtrace: TPQtrace;
  PQuntrace: TPQuntrace;
  PQsetNoticeProcessor: TPQsetNoticeProcessor;

{ === in fe-exec.c === }
  PQexec: TPQexec;
  PQnotifies: TPQnotifies;
  PQfreeNotify: TPQfreeNotify;
  PQsendQuery: TPQsendQuery;
  PQgetResult: TPQgetResult;
  PQisBusy: TPQisBusy;
  PQconsumeInput: TPQconsumeInput;
  PQgetline: TPQgetline;
  PQputline: TPQputline;
  PQgetlineAsync: TPQgetlineAsync;
  PQputnbytes: TPQputnbytes;
  PQendcopy: TPQendcopy;

  PQsetnonblocking: TPQsetnonblocking;
  PQisnonblocking: TPQisnonblocking;
  PQisthreadsafe: TPQisthreadsafe;
  PQping: TPQping;
  PQpingParams: TPQpingParams;

  PQfn: TPQfn;
  PQresultStatus: TPQresultStatus;
  PQresultErrorMessage: TPQresultErrorMessage;
  PQresultErrorField: TPQresultErrorField; //Firmos
  PQntuples: TPQntuples;
  PQnfields: TPQnfields;
  PQbinaryTuples: TPQbinaryTuples;
  PQfname: TPQfname;
  PQfnumber: TPQfnumber;
  PQftype: TPQftype;
  PQfsize: TPQfsize;
  PQfmod: TPQfmod;
  PQcmdStatus: TPQcmdStatus;
  PQoidValue: TPQoidValue;
  PQoidStatus: TPQoidStatus;
  PQcmdTuples: TPQcmdTuples;
  PQgetvalue: TPQgetvalue;
  PQgetlength: TPQgetlength;
  PQgetisnull: TPQgetisnull;
  PQclear: TPQclear;
  PQmakeEmptyPGresult: TPQmakeEmptyPGresult;
  //belal
  PQPrepare: TPQPrepare;
  PQExecPrepared: TPQExecPrepared;
  PQdescribePrepared: TPQdescribePrepared;
  PQnparams: TPQnparams;
  PQparamtype: TPQparamtype;
  PQsendQueryPrepared: TPQsendQueryPrepared;
  PQsetSingleRowMode: TPQsetSingleRowMode;

//FirmOS: New defines
  PQescapeByteaConn: TPQescapeByteaConn;
  PQescapeBytea: TPQescapeBytea;
  PQunescapeBytea: TPQunescapeBytea;

  PQFreemem: TPQFreemem;

{ === in fe-lobj.c === }
  lo_open: Tlo_open;
  lo_close: Tlo_close;
  lo_read: Tlo_read;
  lo_write: Tlo_write;
  lo_lseek: Tlo_lseek;
  lo_creat: Tlo_creat;
  lo_tell: Tlo_tell;
  lo_unlink: Tlo_unlink;
  lo_import: Tlo_import;
  lo_export: Tlo_export;
  lo_truncate: Tlo_truncate;

type

  { TmncPGLib }

  TmncPGLib = class(TmnLibrary)
  protected
    procedure Link; override;
  end;

var
  PGLib: TmncPGLib = nil;

function PQsetdb(Host, Port, Options, Tty, Db: PAnsiChar): PPGconn;

implementation

function PQsetdb(Host, Port, Options, Tty, Db: PAnsiChar): PPGconn;
begin
  Result := PQsetdbLogin(Host, Port, Options, Tty, Db, nil, nil);
end;

procedure TmncPGLib.Link;
begin

  PQfreemem := GetAddress('PQfreemem');
  PQescapeByteaConn := GetAddress('PQescapeByteaConn');
  PQescapeBytea := GetAddress('PQescapeBytea');
  PQunescapeBytea := GetAddress('PQunescapeBytea');

  PQconnectStart := GetAddress('PQconnectStart');
  PQconnectStartParams := GetAddress('PQconnectStartParams');
  PQconnectPoll := GetAddress('PQconnectPoll');

  PQconnectdb := GetAddress('PQconnectdb');
  PQsetdbLogin := GetAddress('PQsetdbLogin');
  PQfinish := GetAddress('PQfinish');
  PQconndefaults := GetAddress('PQconndefaults');

  PQreset := GetAddress('PQreset');
  PQrequestCancel := GetAddress('PQrequestCancel');
  PQdb := GetAddress('PQdb');
  PQuser := GetAddress('PQuser');
  PQpass := GetAddress('PQpass');
  PQhost := GetAddress('PQhost');
  PQport := GetAddress('PQport');
  PQtty := GetAddress('PQtty');
  PQoptions := GetAddress('PQoptions');
  PQstatus := GetAddress('PQstatus');
  PQerrorMessage := GetAddress('PQerrorMessage');
  PQsocket := GetAddress('PQsocket');
  PQbackendPID := GetAddress('PQbackendPID');
  PQtrace := GetAddress('PQtrace');
  PQuntrace := GetAddress('PQuntrace');
  PQsetNoticeProcessor := GetAddress('PQsetNoticeProcessor');

{ === in fe-exec.c === }
  PQexec := GetAddress('PQexec');
  PQnotifies := GetAddress('PQnotifies');
  PQfreeNotify := GetAddress('PQfreeNotify');
  PQsendQuery := GetAddress('PQsendQuery');
  PQgetResult := GetAddress('PQgetResult');
  PQisBusy := GetAddress('PQisBusy');
  PQconsumeInput := GetAddress('PQconsumeInput');
  PQgetline := GetAddress('PQgetline');
  PQputline := GetAddress('PQputline');
  PQgetlineAsync := GetAddress('PQgetlineAsync');
  PQputnbytes := GetAddress('PQputnbytes');
  PQendcopy := GetAddress('PQendcopy');

  PQsetnonblocking := GetAddress('PQsetnonblocking');
  PQisnonblocking := GetAddress('PQisnonblocking');
  PQisthreadsafe := GetAddress('PQisthreadsafe');
  PQping := GetAddress('PQping');
  PQpingParams := GetAddress('PQpingParams');

  PQfn := GetAddress('PQfn');
  PQresultStatus := GetAddress('PQresultStatus');
  PQresultErrorMessage := GetAddress('PQresultErrorMessage');
  PQresultErrorField := GetAddress('PQresultErrorField');
  PQntuples := GetAddress('PQntuples');
  PQnfields := GetAddress('PQnfields');
  PQbinaryTuples := GetAddress('PQbinaryTuples');
  PQfname := GetAddress('PQfname');
  PQfnumber := GetAddress('PQfnumber');
  PQftype := GetAddress('PQftype');
  PQfsize := GetAddress('PQfsize');
  PQfmod := GetAddress('PQfmod');
  PQcmdStatus := GetAddress('PQcmdStatus');
  PQoidValue := GetAddress('PQoidValue');
  PQoidStatus := GetAddress('PQoidStatus');
  PQcmdTuples := GetAddress('PQcmdTuples');
  PQgetvalue := GetAddress('PQgetvalue');
  PQgetlength := GetAddress('PQgetlength');
  PQgetisnull := GetAddress('PQgetisnull');
  PQclear := GetAddress('PQclear');
  PQmakeEmptyPGresult := GetAddress('PQmakeEmptyPGresult');
  PQPrepare := GetAddress('PQprepare');
  PQExecPrepared := GetAddress('PQexecPrepared');
  PQdescribePrepared := GetAddress('PQdescribePrepared');
  PQnparams := GetAddress('PQnparams');
  PQparamtype := GetAddress('PQparamtype');
  PQsendQueryPrepared := GetAddress('PQsendQueryPrepared');
  PQsetSingleRowMode := GetAddress('PQsetSingleRowMode');

{ === in fe-lobj.c === }
  lo_open := GetAddress('lo_open');
  lo_close := GetAddress('lo_close');
  lo_read := GetAddress('lo_read');
  lo_write := GetAddress('lo_write');
  lo_lseek := GetAddress('lo_lseek');
  lo_creat := GetAddress('lo_creat');
  lo_tell := GetAddress('lo_tell');
  lo_unlink := GetAddress('lo_unlink');
  lo_import := GetAddress('lo_import');
  lo_export := GetAddress('lo_export');
  lo_truncate := GetAddress('lo_truncate');
end;

initialization
  PGLib := TmncPGLib.Create('libpq');
finalization
  FreeAndNil(PGLib);
end.

