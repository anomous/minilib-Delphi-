unit mnHttpClient;
{ **
  *  This file is part of the "Mini Library"
  *
  * @license   modifiedLGPL (modified of http://www.gnu.org/licenses/lgpl.html)
  *            See the file COPYING.MLGPL, included in this distribution,
  * @author    Jihad Khlaifa <jkhalifa at gmail dot com>
  * @author    Zaher Dirkey zaherdirkey
  * }

{
  https://en.wikipedia.org/wiki/Uniform_Resource_Identifier
}

{$H+}{$M+}
{$ifdef fpc}
{$mode delphi}
{$endif}

interface

uses
  SysUtils, Classes, StrUtils,
  mnClasses, mnFields, mnConfigs, mnModules, mnSockets, mnClients, mnStreams, mnUtils;

type

  TmnHttpClient = class;

  { TmnCustomHttpHeader }

  TmnCustomHttpHeader = class(TmnObject)
  private
    FAccept: UTF8String;
    FAcceptCharSet: UTF8String;
    FAcceptEncoding: UTF8String;
    FAcceptLanguage: UTF8String;
    FClient: TmnHttpClient;
    FConnection: UTF8String;
    FContentLength: Integer;
    FContentType: UTF8String;

    FDate: TDateTime;
    FKeepAlive: Boolean;
    FLastModified: TDateTime;
    FExpires: TDateTime;

    FHeaders: TmnHeader;

  protected
    procedure SetHeader(Name, Value: string);
  public
    constructor Create(AClient: TmnHttpClient); virtual;
    destructor Destroy; override;
    procedure Clear; virtual;
    property Headers: TmnHeader read FHeaders write FHeaders;
    property Date: TDateTime read FDate write FDate;
    property Expires: TDateTime read FExpires write FExpires;
    property LastModified: TDateTime read FLastModified write FLastModified;
    property Accept: UTF8String read FAccept write FAccept;
    property AcceptCharSet: UTF8String read FAcceptCharSet write FAcceptCharSet;
    property AcceptEncoding: UTF8String read FAcceptEncoding write FAcceptEncoding;
    property AcceptLanguage: UTF8String read FAcceptLanguage write FAcceptLanguage;
    property ContentType: UTF8String read FContentType write FContentType;
    property ContentLength: Integer read FContentLength write FContentLength;
    property Connection: UTF8String read FConnection write FConnection;
    property KeepAlive: Boolean read FKeepAlive write FKeepAlive;
    property Client: TmnHttpClient read FClient;
  end;

  { TmnHttpRequest }

  TmnHttpRequest = class(TmnCustomHttpHeader)
  private
    FAccept: UTF8String;
    FReferer: UTF8String;
    FUserAgent: UTF8String;
  protected
    procedure CollectHeaders; virtual;
  public
    procedure Created; override;
    procedure Send;

    property UserAgent: UTF8String read FUserAgent write FUserAgent;
    property Referer: UTF8String read FReferer write FReferer;
  end;

  { TmnHttpResponse }

  TmnHttpResponse = class(TmnCustomHttpHeader)
  private
    FLocation: UTF8String;
    FServer: UTF8String;
  protected
    procedure ReceiveHeaders; virtual;
  public
    procedure Receive;
    property Location: UTF8String read FLocation write FLocation;
    property Server: UTF8String read FServer write FServer;
  end;

  { TmnCustomHttpStream }

  TmnHttpStream = class(TmnClientSocket)
  private
  protected
  public
    function Seek(Offset: Integer; Origin: Word): Integer; override;
  end;

  { TmnHttpClient }

  TmnHttpClient = class(TObject)
  private
    FCookies: TmnParams;
    FAddress: UTF8String;
    FPort: UTF8String;
    FPath: UTF8String;
    FProtocol: UTF8String;
    FCompressing: Boolean;
    FKeepAlive: Boolean;

    FRequest: TmnHttpRequest;
    FResponse: TmnHttpResponse;

    FStream: TmnHttpStream;
  protected
    procedure Open(const vURL: UTF8String);
    function CreateStream: TmnHttpStream; virtual;
    function FreeStream: TmnHttpStream; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    function Connected: Boolean;

    //Use it to open connection and keep it connected
    function Connect(const vURL: UTF8String; SendAndReceive: Boolean = True): Boolean;
    procedure ReceiveStream(AStream: TStream); overload;
    procedure ReceiveStream(AStream: TStream; Count: Integer); overload;
    procedure ReceiveMemoryStream(AStream: TStream);
    procedure Disconnect;
    //This will download the content into a stream and disconnect
    procedure GetStream(const vURL: UTF8String; OutStream: TStream);
    procedure GetFile(const vURL: UTF8String; OutFileName: UTF8String);
    //Just add seek to 0 after getting
    procedure GetMemoryStream(const vURL: UTF8String; OutStream: TMemoryStream);
    procedure SendFile(const vURL: UTF8String; AFileName: UTF8String);

    property Request: TmnHttpRequest read FRequest;
    property Response: TmnHttpResponse read FResponse;
    property Cookies: TmnParams read FCookies write FCookies;

    property Address: UTF8String read FAddress write FAddress;
    property Port: UTF8String read FPort write FPort;
    property Protocol: UTF8String read FProtocol write FProtocol;
    property Path: UTF8String read FPath write FPath;
    property Compressing: Boolean read FCompressing write FCompressing; //TODO
    property KeepAlive: Boolean read FKeepAlive write FKeepAlive;
    property Stream: TmnHttpStream read FStream;
  end;

implementation

const
  ProtocolVersion = 'HTTP/1.0';

threadvar
  FCachedStream: TmnHttpStream;

function GetUrlPart(var vPos: PUtf8Char; var vCount: Integer; const vTo: UTF8String; const vStops: TSysCharSet = []): UTF8String;

  function _IsMatch(vSrc, vDst: PUtf8Char; ACount: Integer): Boolean;
  var
    I: Integer;
  begin
    Result := True;
    for I := 0 to ACount - 1 do
    begin
      if vSrc^ <> vDst^ then
      begin
        Result := False;
        Break;
      end;
      Inc(vSrc);
      Inc(vDst);
    end;
  end;

var
  l: Integer;
  p, e, d: PUtf8Char;
  aFound: Boolean;
begin
  l := Length(vTo);
  d := PUtf8Char(vTo);
  p := vPos;
  e := vPos;
  Inc(e, vCount - l);
  aFound := False;
  while p < e do
  begin
    if (p^ in vStops) then
      Break;
    if (p^ = d^) and _IsMatch(p, d, l) then
    begin
      aFound := True;
      Break;
    end;
    Inc(p);
  end;

  if aFound then
  begin
    SetString(Result, vPos, p - vPos);
    Dec(vCount, l + (p - vPos));
    Inc(vPos, l + (p - vPos));
  end
  else
    Result := '';
end;

procedure ParseURL(const vURL: UTF8String; out vProtocol, vAddress, vPort, vParams: UTF8String);
var
  p: PUTF8Char;
  l: Integer;
begin
  vProtocol := '';
  vAddress := '';
  vPort := '';
  vParams := '';

  p := PUtf8Char(vURL);
  l := Length(vURL);
  if l > 0 then
    vProtocol := GetUrlPart(p, l, '://', ['.']);

  if l > 0 then
  begin
    vAddress := GetUrlPart(p, l, ':', ['/']);
    if vAddress <> '' then
    begin
      vPort := GetUrlPart(p, l, '/', []);
      if vPort = '' then
      begin
        SetString(vPort, p, l);
        l := 0;
      end;
    end
    else
    begin
      vAddress := GetUrlPart(p, l, '/', []);
      if vAddress = '' then
      begin
        SetString(vAddress, p, l);
        l := 0;
      end;
    end;
  end;

  if l > 0 then
    SetString(vParams, p, l);

  if LeftStr(vParams, 1) <> '/' then
    vParams := '/' + vParams;

  if vPort = '' then
  begin
    if SameText(vProtocol, 'https') then
      vPort := '443'
    else
      vPort := '80';
  end;
end;

{ TmnCustomHttpHeader }

procedure TmnCustomHttpHeader.SetHeader(Name, Value: string);
begin
  if Value <> '' then
    Headers.Require[Name].Value := Value
  else
    Headers.RemoveByName(Name);
end;

constructor TmnCustomHttpHeader.Create(AClient: TmnHttpClient);
begin
  inherited Create;
  FClient := AClient;
  FHeaders := TmnHeader.Create;
end;

destructor TmnCustomHttpHeader.Destroy;
begin
  FHeaders.Free;
  inherited;
end;

procedure TmnCustomHttpHeader.Clear;
begin
  FHeaders.Clear;
end;

{ TmnHttpRequest }

procedure TmnHttpRequest.CollectHeaders;
begin
  inherited;
  with FHeaders do
  begin
    Values['Host'] := Client.Address;
    Values['User-Agent'] := FUserAgent;
    Values['Connection'] := FConnection;

    Values['Accept'] := FAccept;
    Values['Accept-CharSet'] := FAcceptCharSet;
    Values['Accept-Encoding'] := FAcceptEncoding;
    Values['Accept-Language'] := FAcceptLanguage;
    Values['Referer'] := FReferer;
  end;
end;

procedure TmnHttpRequest.Created;
begin
  inherited;
  UserAgent := 'Mozilla/5.0';
end;

procedure TmnHttpRequest.Send;
var
  s: UTF8String;
  f: TmnField;
begin
  CollectHeaders;
  Client.Stream.WriteLineUTF8('GET ' + Client.Path + ' ' + ProtocolVersion);
  for f in Headers do
    if f.AsString <> '' then
      Client.Stream.WriteLineUTF8(f.FullString);
  for f in Client.Cookies do
    s := f.Value + ';';
  if s <> '' then
    Client.Stream.WriteLineUTF8('Cookie: ' + s);
  Client.Stream.WriteLineUTF8(Client.Stream.EndOfLine);
end;

{ TmnHttpResponse }

procedure TmnHttpResponse.ReceiveHeaders;
begin
  inherited;
  with FHeaders do
  begin
    FLocation := Field['Location'].AsString;
    FServer := Field['Server'].AsString;
    FContentType:= Field['Content-Type'].AsString;
    FContentLength := StrToIntDef(Trim(Field['Content-Length'].AsString), 0);
    FAccept := Field['Accept'].AsString;
    FAcceptCharSet := Field['Accept-CharSet'].AsString;
    FAcceptEncoding := Field['Accept-Encoding'].AsString;
    FAcceptLanguage := Field['Accept-Language'].AsString;
    FConnection := Field['Connection'].AsString;
  end;
end;

procedure TmnHttpResponse.Receive;
var
  s: UTF8String;
begin
  FHeaders.Clear;
  // if FStream.Connected then
  begin
    Client.Stream.ReadLine(s, True);
    s := Trim(s);
    repeat
      Headers.AddItem(s, ':', True);
      Client.Stream.ReadLine(s, True);
      s := Trim(s);
    until { FStream.Connected or } (s = '');
  end;
  ReceiveHeaders;
  s := Headers.Field['Set-Cookie'].AsString;
  Client.Cookies.Delimiter := ';';
  Client.Cookies.AsString := s;
end;

{ TmnHttpStream }

function TmnHttpStream.Seek(Offset: Integer; Origin: Word): Integer;
begin
  Result := 0; // for loading from this stream like Image.loadfrom stream
end;

{ TmnHttpClient }

function TmnHttpClient.Connected: Boolean;
begin
  Result := FStream.Connected;
end;

procedure TmnHttpClient.Open(const vURL: UTF8String);
begin
  if FStream = nil then
    FStream := CreateStream;

  ParseURL(vURL, FProtocol, FAddress, FPort, FPath);
  Stream.Address := Address;
  Stream.Port := Port;

  if SameText(Protocol, 'https') then
    Stream.Options := Stream.Options + [soSSL, soWaitBeforeRead]
  else
    Stream.Options := Stream.Options - [soSSL];

  if KeepAlive then
  begin
    FRequest.Connection := 'Keep-Alive';
    //Keep-Alive: timeout=1200
  end
  else
    FRequest.Connection := 'close';
  Stream.Connect;
end;

function TmnHttpClient.CreateStream: TmnHttpStream;
begin
  Result := TmnHttpStream.Create;
  Result.EndOfLine := sWinEndOfLine;
end;

function TmnHttpClient.FreeStream: TmnHttpStream;
begin
  FreeAndNil(FStream);
end;

constructor TmnHttpClient.Create;
begin
  inherited;
  FRequest := TmnHttpRequest.Create(Self);
  FResponse := TmnHttpResponse.Create(Self);
  FCookies := TmnParams.Create;
end;

destructor TmnHttpClient.Destroy;
begin
  FreeAndNil(FRequest);
  FreeAndNil(FResponse);
  FreeAndNil(FCookies);
  inherited;
end;

{ TmnHttpClient }

function TmnHttpClient.Connect(const vURL: UTF8String; SendAndReceive: Boolean): Boolean;
begin
  Open(vUrl);
  if SendAndReceive then
  begin
    Request.Send;
    if Stream.Connected then
      Response.Receive;
  end;
  Result := Stream.Connected;
end;

procedure TmnHttpClient.ReceiveStream(AStream: TStream);
begin
  if KeepAlive then
    FStream.ReadStream(AStream, Response.ContentLength)
  else
    FStream.ReadStream(AStream);
end;

procedure TmnHttpClient.ReceiveStream(AStream: TStream; Count: Integer);
begin
  FStream.ReadStream(AStream, Count);
end;

procedure TmnHttpClient.ReceiveMemoryStream(AStream: TStream);
begin
  ReceiveStream(AStream);
  AStream.Seek(0, soFromBeginning);
end;

procedure TmnHttpClient.Disconnect;
begin
  if FStream <> nil then
    FStream.Disconnect;
  FreeStream;
end;

procedure TmnHttpClient.GetStream(const vURL: UTF8String; OutStream: TStream);
begin
  if Connect(vURL) then
  begin
    FStream.ReadStream(OutStream);
  end;
end;

procedure TmnHttpClient.GetFile(const vURL: UTF8String; OutFileName: UTF8String);
var
  f: TFileStream;
begin
  f := TFileStream.Create(OutFileName, fmCreate or fmShareDenyWrite);
  try
    GetStream(vURL, f);
  finally
    f.Free;
  end;
end;

procedure TmnHttpClient.GetMemoryStream(const vURL: UTF8String; OutStream: TMemoryStream);
begin
  GetStream(vURL, OutStream);
  OutStream.Seek(0, soFromBeginning);
end;

procedure TmnHttpClient.SendFile(const vURL: UTF8String; AFileName: UTF8String);
begin
  //TODO
end;

end.
