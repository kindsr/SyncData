﻿unit uCommandsClass;

interface

uses
  SysUtils, ShellApi, Dialogs, contnrs, ComCtrls, XMLDoc, XMLIntf, Windows,
  Variants, System.TypInfo,
  DateUtils, Types, uFilterClass, ComObj, ActiveX, System.UITypes,
  System.Classes;

type
  TCommandRunType = (crtNormalRun, crtByTimeRun, crtEdit);

  TCmdWaitForRunningThread = class;

  TCmdFolderWatchingThread = class;

  { TCommandData }

  TCommandList = TObjectList;

  // RTTI 작업 지침
  {$M+}

  TCommandData = class
  private
    FisGroup: boolean;
    FName: string;
    // 고유한 이름(스크립트 편집을 자동화하는 데 사용됨) 자동으로 생성됨
    FisVisible: boolean; // 가시성 표시
    Fcommand: String; // 실행할 명령
    FisRunning: boolean; // 이제 명령이 실행 중입니다.

    FChilds: TCommandList;

    FisRunAt: boolean;
    FRunAtDateTime: TDateTime;

    FNextRunAtDateTime: TDateTime;

    FisRepeatRun: boolean;
    FRepeatRunAtTime: TTime;

    FisRun_isWhenOnlyFolderChange: boolean;
    FisRun_WhenOnlyFolderChange: string;
    FisRun_FolderChanged: boolean;
    FCommandParameters: string;

    FWaitForRunningThread: TCmdWaitForRunningThread;
    FisRun_FolderWatchingThread: TCmdFolderWatchingThread;

    procedure SetisRun_isWhenOnlyFolderChange(const Value: boolean);

    // just RunCommand
    function InternalRun(const AHelper: string; const ADefaultOperation: PChar;
      const RunType: TCommandRunType): THandle;

  public
    constructor Create; overload;
    constructor Create(const NodeAttributes: IXMLNode;
      const FillPropertyIsVisible: boolean); overload;

    destructor Destroy; override;

    // 다음 런타임 계산(FisRunAt = true인 경우에만 호출)
    procedure CalcNextRunAtDateTime;

    // function GetEditHelper: string;
    // edit
    procedure Edit;
    // запуск
    procedure Run(const RunType: TCommandRunType);

    procedure Assign(Dest: TCommandData);
    procedure AssignTo(DestNode: IXMLNode; const ACaption: String);
    // real property
    property isRunning: boolean read FisRunning write FisRunning;
  published // all this properties saves in xmls

    property Name: string read FName write FName;
    property isVisible: boolean read FisVisible write FisVisible;
    property isGroup: boolean read FisGroup write FisGroup;
    property Childs: TCommandList read FChilds;
    property Command: string read Fcommand write Fcommand;
    property CommandParameters: string read FCommandParameters
      write FCommandParameters;

    property isRunAt: boolean read FisRunAt write FisRunAt;
    // под вопросом (может Set метод)
    property RunAtDateTime: TDateTime read FRunAtDateTime write FRunAtDateTime;

    property isRun_isWhenOnlyFolderChange: boolean
      read FisRun_isWhenOnlyFolderChange write SetisRun_isWhenOnlyFolderChange;
    property isRun_WhenOnlyFolderChange: string read FisRun_WhenOnlyFolderChange
      write FisRun_WhenOnlyFolderChange;

    property NextRunAtDateTime: TDateTime read FNextRunAtDateTime
      write FNextRunAtDateTime;

    property isRepeatRun: boolean read FisRepeatRun write FisRepeatRun;
    property RepeatRunAtTime: TTime read FRepeatRunAtTime
      write FRepeatRunAtTime;

    // real properties (but saves in xml)
    property isRun_FolderChanged: boolean read FisRun_FolderChanged
      write FisRun_FolderChanged;
  end;
{$M-}
  { TCommandWaitForRunningThread }

  TCmdWaitForRunningThread = class(TThread)
  private
    FProcessHandle: THandle;
    Fcommand: TCommandData;
  protected
    procedure Execute; override;
  public
    constructor Create(const AProcessHandle: THandle; Command: TCommandData);
  end;

  { TCommandWaitForRunningThread }

  TCmdFolderWatchingThread = class(TThread)
  private
    FWatchFolder: string;
    Fcommand: TCommandData;
  protected
    procedure Execute; override;
  public
    constructor Create(const AWatchFolder: string; ACommand: TCommandData);
  end;

procedure TreeToXML(ATreeNodes: TTreeNodes);

// получение значения свойства из атрибута (обход nil)
function GetPropertyFromNodeAttributes(const NodeAttributes: IXMLNode;
  const sProperty: String): string;

// var MainCommandList: TCommandList; // основной список

implementation

uses Winapi.ShlObj, Winapi.ShLwApi, uCommon;

procedure TreeToXML(ATreeNodes: TTreeNodes);
var
  tn: TTreeNode;
  XMLDoc: IXMLDocument;
  Node: IXMLNode;

  procedure ProcessTreeItem(atn: TTreeNode; aNode: IXMLNode);
  var
    cNode: IXMLNode;
    vCommonData: TCommandData;
  begin
    // такая проверка все равно есть перед заходом в рекурсию
    cNode := aNode.AddChild('item');

    vCommonData := TCommandData(atn.Data);
    // vCommonData.CalcNextRunAtDateTime;

    // showmessage(atn.Text);
    vCommonData.AssignTo(cNode, atn.Text);

    // child nodes
    atn := atn.GetFirstChild;
    while atn <> nil do
    begin
      ProcessTreeItem(atn, cNode);
      atn := atn.getNextSibling;
    end;
  end; (* ProcessTreeItem *)

var
  vFilename, vFilenameNew: string;
begin
  XMLDoc := TXMLDocument.Create(nil);
  // XMLDoc.Encoding := 'UTF-8';
  XMLDoc.Active := True;
  XMLDoc.Options := XMLDoc.Options + [doNodeAutoIndent];

  Node := XMLDoc.AddChild('tree2xml');
  Node.Attributes['name'] := 'tvItems';

  tn := ATreeNodes.GetFirstNode; // TopNode;
  while tn <> nil do
  begin
    ProcessTreeItem(tn, Node);

    tn := tn.getNextSibling;
  end;

  vFilename := ExtractFilePath(ParamStr(0)) + cItemsFileName;
  // 'SyncData_AK_tvItems.xml';
  vFilenameNew := ExtractFilePath(ParamStr(0)) + 'new-' + cItemsFileName;
  // SyncData_AK_tvItems.xml';

  XMLDoc.SaveToFile(vFilenameNew);
  if FileExists(vFilename) then
    if not DeleteFile(PChar(vFilename)) then
      RaiseLastOSError;
  if not RenameFile(vFilenameNew, vFilename) then
    RaiseLastOSError;
end; // TreeToXML

// 속성에서 속성 값 가져오기(nil 우회)
function GetPropertyFromNodeAttributes(const NodeAttributes: IXMLNode;
  const sProperty: String): string;
var
  // Node: IXMLNode;
  Res: OleVariant;
begin
  Res := (NodeAttributes.Attributes[sProperty]);

  if not VarIsNull(Res) then
    Result := Res
  else
    Result := '';
end;

{ TCommandData }

constructor TCommandData.Create;
var
  vSysTime: TSystemTime;
begin
  inherited Create;

  FName := '';
  FisVisible := True; // 가시성 표시
  FisGroup := false; // 그룹 사인
  Fcommand := ''; // 실행할 명령
  FCommandParameters := ''; // 실행할 명령 매개변수

  FWaitForRunningThread := nil;
  FisRun_FolderWatchingThread := nil;

  FisRunAt := false;

  GetLocalTime(vSysTime);
  with vSysTime do
    FRunAtDateTime := EncodeDate(wYear, wMonth, wDay) +
      EncodeTime(wHour, wMinute, 0, 0);

  FisRepeatRun := false;
  FRepeatRunAtTime := Frac(FRunAtDateTime);

  FisRun_isWhenOnlyFolderChange := false;
  FisRun_WhenOnlyFolderChange := '';

  // real properties
  FisRunning := false;
  FisRun_FolderChanged := false;
end;

constructor TCommandData.Create(const NodeAttributes: IXMLNode;
  const FillPropertyIsVisible: boolean);

var
  i, FPropCount: integer;
  TypeData: PTypeData;
  FPropList: PPropList;
  FProp: PPropInfo;
  sDataToLoad: string;
  sDataType: TSymbolName;
begin
  Create;

  TypeData := GetTypeData(ClassInfo);
  FPropCount := TypeData.PropCount;
  GetMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  try
    GetPropInfos(ClassInfo, FPropList);
    for i := 0 to FPropCount - 1 do
    begin
      FProp := FPropList[i];

      sDataToLoad := GetPropertyFromNodeAttributes(NodeAttributes,
        string(FProp.Name));

      if sDataToLoad = '' then
        Continue;

      case FProp.PropType^.Kind of
        tkUString:
          SetStrProp(Self, FProp, sDataToLoad);
        tkEnumeration, tkInteger:
          SetOrdProp(Self, FProp, System.SysUtils.StrToInt(sDataToLoad));
        tkFloat:
          begin
            sDataType := FProp.PropType^.Name;
            if sDataType = 'TDateTime' then
              SetFloatProp(Self, FProp, StrToDateTime(sDataToLoad))
            else if sDataType = 'TTime' then
              SetFloatProp(Self, FProp, StrToTime(sDataToLoad))
          end;
      end; // case
    end; // for i .. FPropCount-1
  finally
    FreeMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  end;

end;

destructor TCommandData.Destroy;
begin
  if FWaitForRunningThread <> nil then
    FWaitForRunningThread.Terminate;

  if FisRun_FolderWatchingThread <> nil then
    FisRun_FolderWatchingThread.Terminate;
end;

procedure TCommandData.CalcNextRunAtDateTime;
var
  vNow: TDateTime;
  vNowDate: TDate;
begin
  // FNextRunAtDateTime := NullDate; // по умолчанию (нет запуска)

  // FisNextRunAt := False; // по умолчанию (нет запуска)

  if FisGroup or not FisRunAt then
    Exit;

  vNow := Now;
  if FRunAtDateTime > vNow then
  begin
    FNextRunAtDateTime := FRunAtDateTime;
    // FisNextRunAt := True;
  end
  else // дата-время прошло, но есть повтор
    if FisRepeatRun then
    begin
      vNowDate := Trunc(vNow);

      // время больше текущего (перенести на след.день)
      if CompareTime(vNow, FRepeatRunAtTime) = GreaterThanValue then
      // текущее время больше
        vNowDate := vNowDate + 1;

      FNextRunAtDateTime := vNowDate + Frac(FRepeatRunAtTime);
      // FisNextRunAt := True;
    end
    else // нет повтора - нет запуска
      FisRunAt := false;
end;

function TCommandData.InternalRun(const AHelper: string;
  const ADefaultOperation: PChar; const RunType: TCommandRunType): THandle;
const
  strCommandRunType: array [TCommandRunType] of string = ('Normal Run',
    'Run by time', 'Edit');
var
  vOperation, vFilename, vParameters: PChar;
  SEInfo: TShellExecuteInfo;
  vGetLastError: Cardinal;
  sTechErrorMsg: string;
begin
  Result := 0;

  CoInitializeEx(nil, COINIT_APARTMENTTHREADED or COINIT_DISABLE_OLE1DDE);

  if AHelper <> '' then
  begin
    vOperation := nil;
    vFilename := PChar('"' + AHelper + '"');
    vParameters := PChar('"' + Fcommand + '"' + FCommandParameters);
    // IfThen(FCommandParameters <> '', ' "' + FCommandParameters + '"'));
  end
  else
  begin
    vOperation := ADefaultOperation;
    vFilename := PChar(Fcommand); // PChar('"' + FCommand + '"');
    vParameters := PChar(FCommandParameters);
    // IfThen(FCommandParameters <> '', PChar('"' + FCommandParameters + '"'));
  end;

  FillChar(SEInfo, SizeOf(SEInfo), 0);
  with SEInfo do
  begin
    cbSize := SizeOf(TShellExecuteInfo);
    lpVerb := vOperation;
    lpFile := vFilename;
    lpParameters := vParameters;
    lpDirectory := PChar(ExtractFilePath(Fcommand));
    nShow := SW_SHOWNORMAL;
    if RunType <> crtEdit then
      fMask := SEE_MASK_NOCLOSEPROCESS;
  end;
  if ShellExecuteEx(@SEInfo) then
    Result := SEInfo.hProcess
  else if gDebug then
  begin
    vGetLastError := GetLastError;
    if vGetLastError <> 1155 then
    // не установлена ассоциация (чтобы не было двойного сообщения об ошибке)
    begin
      if vOperation = nil then
        sTechErrorMsg := 'nil'
      else
        sTechErrorMsg := vOperation;
      sTechErrorMsg := sTechErrorMsg + '; ' + vFilename + '; ';
      if vParameters = nil then
        sTechErrorMsg := sTechErrorMsg + 'nil'
      else
        sTechErrorMsg := sTechErrorMsg + vParameters;

      M_Error('Error with ' + strCommandRunType[RunType] + ': ' +
        SysErrorMessage(vGetLastError) + LineFeed + 'Error code: ' +
        IntToStr(vGetLastError) + LineFeed + 'TechErrorMsg: ' + sTechErrorMsg);
    end;
  end;
end;

procedure TCommandData.Edit;
  function OpenFolderAndSelectFile(const FileName: string): boolean;
  var
    IIDL: PItemIDList;
  begin
    Result := false;
    IIDL := ILCreateFromPath(PChar(FileName));
    if IIDL <> nil then
      try
        Result := SHOpenFolderAndSelectItems(IIDL, 0, nil, 0) = S_OK;
      finally
        ILFree(IIDL);
      end;
  end;
  function GetAssociatedExeForEdit(const vFilename: string): string;
  var
    pResult: PChar;
    pResultSize: DWORD;
  begin
    Result := '';
    pResultSize := 255;
    pResult := StrAlloc(MAX_PATH);
    try
      AssocQueryString(0, ASSOCSTR_EXECUTABLE, PChar(vFilename), 'edit',
        pResult, @pResultSize);
      Result := pResult;
    finally
      StrDispose(pResult);
    end;
  end;

var
  vFilterData: TFilterData;
  editHelper: string;
begin
  if Fcommand <> '' then
  begin
    vFilterData := Filters_GetFilterByFilename(Fcommand);
    if Assigned(vFilterData) then
    begin
      editHelper := vFilterData.editHelper;
    end
    else
      editHelper := '';
    if (editHelper <> '') or (GetAssociatedExeForEdit(Fcommand) <> '') then
      InternalRun(editHelper, PChar('edit'), crtEdit)
    else
      OpenFolderAndSelectFile(Fcommand);
  end;
end;

procedure TCommandData.Run(const RunType: TCommandRunType);
var
  vFilterData: TFilterData;
  runHelper: string;
  // CmdWaitForRunningThread: TCmdWaitForRunningThread;
  ProcessHandle: THandle;
begin
  if (Fcommand <> '') and not FisRunning then
  begin
    vFilterData := Filters_GetFilterByFilename(Fcommand);
    if Assigned(vFilterData) then
      runHelper := vFilterData.runHelper
    else
      runHelper := '';

    ProcessHandle := InternalRun(runHelper, nil, RunType);
    if ProcessHandle <> 0 then
    begin
      isRunning := True;
      FWaitForRunningThread := TCmdWaitForRunningThread.Create
        (ProcessHandle, Self);
    end;

    // try

    { except //todo: заменить на локализованную версию
      MessageDlg('Cannot Run command "' +
      FCommand + '"', mtError, [mbOK], 0);
      end;//try..end }
  end;
end;

procedure TCommandData.SetisRun_isWhenOnlyFolderChange(const Value: boolean);
begin
  if FisRun_isWhenOnlyFolderChange <> Value then
  begin
    if Value then
      FisRun_FolderWatchingThread := TCmdFolderWatchingThread.Create
        (FisRun_WhenOnlyFolderChange, Self)
    else
      FreeAndNil(FisRun_FolderWatchingThread);

    FisRun_isWhenOnlyFolderChange := Value;
  end;
end;

procedure TCommandData.Assign(Dest: TCommandData);
var
  i, FPropCount: integer;
  TypeData: PTypeData;
  FPropList: PPropList;
  FProp: PPropInfo;
begin
  TypeData := GetTypeData(ClassInfo);
  FPropCount := TypeData.PropCount;

  GetMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  try
    GetPropInfos(ClassInfo, FPropList);
    for i := 0 to FPropCount - 1 do
    begin
      FProp := FPropList[i];

      case FProp.PropType^.Kind of
        tkUString:
          SetStrProp(Dest, FProp, GetStrProp(Self, FProp));
        tkEnumeration, tkInteger:
          SetOrdProp(Dest, FProp, GetOrdProp(Self, FProp));
        tkFloat:
          SetFloatProp(Dest, FProp, GetFloatProp(Self, FProp));
        { else
          begin
          Raise EInvalidCast.Create('TCommandData.Assign: неожиданный тип ' + FProp.PropType^.Name + ' для свойства: ' + FProp.Name);
          end; }
      end; // case
    end; // for i .. FPropCount-1
  finally
    FreeMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  end;
end;

procedure TCommandData.AssignTo(DestNode: IXMLNode; const ACaption: String);
var
  i, FPropCount: integer;
  TypeData: PTypeData;
  FPropList: PPropList;
  FProp: PPropInfo;
  sDataToSave: string;
  sDataType: TSymbolName;
begin
  DestNode.SetAttribute('Caption', ACaption);

  TypeData := GetTypeData(ClassInfo);
  FPropCount := TypeData.PropCount;

  GetMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  try
    GetPropInfos(ClassInfo, FPropList);
    for i := 0 to FPropCount - 1 do
    begin
      FProp := FPropList[i];

      sDataToSave := '';
      case FProp.PropType^.Kind of
        tkUString:
          sDataToSave := GetStrProp(Self, FProp);
        tkEnumeration, tkInteger:
          sDataToSave := IntToStr(GetOrdProp(Self, FProp));
        tkFloat:
          begin
            sDataType := FProp.PropType^.Name;
            if sDataType = 'TDateTime' then
              sDataToSave := FormatDateTime('c', GetFloatProp(Self, FProp))
            else if sDataType = 'TTime' then
              sDataToSave := TimeToStr(GetFloatProp(Self, FProp))
          end;
      end; // case
      if sDataToSave <> '' then
        DestNode.SetAttribute(string(FProp.Name), sDataToSave);
    end; // for i .. FPropCount-1
  finally
    FreeMem(FPropList, SizeOf(PPropInfo) * FPropCount);
  end;
end;

{ TCmdWaitForRunningThread }

constructor TCmdWaitForRunningThread.Create(const AProcessHandle: THandle;
  Command: TCommandData);
begin
  FProcessHandle := AProcessHandle;
  Fcommand := Command;

  inherited Create(false);

  Priority := tpLower;
  FreeOnTerminate := True;
end;

procedure TCmdWaitForRunningThread.Execute;
var
  Res: Cardinal;
begin
  while not Terminated do
  begin
    Res := WaitForSingleObject(FProcessHandle, 1000);
    if Res <> WAIT_TIMEOUT then
    begin
      if (Res = WAIT_OBJECT_0) and not Terminated then
        Fcommand.FisRunning := false;
      Break;
    end;
  end;
  Fcommand.FWaitForRunningThread := nil;
end;

{ TCmdFolderWatchingThread }

constructor TCmdFolderWatchingThread.Create(const AWatchFolder: string;
  ACommand: TCommandData);
begin
  FWatchFolder := AWatchFolder;
  Fcommand := ACommand;
  inherited Create(false);
end;

procedure TCmdFolderWatchingThread.Execute;
var
  ChangeHandle: THandle;
begin
  { получаем хэндл события }
  ChangeHandle := FindFirstChangeNotification(PChar(FWatchFolder), True,
    FILE_NOTIFY_CHANGE_FILE_NAME + FILE_NOTIFY_CHANGE_DIR_NAME +
    FILE_NOTIFY_CHANGE_ATTRIBUTES + FILE_NOTIFY_CHANGE_LAST_WRITE +
    FILE_NOTIFY_CHANGE_SIZE); // FILE_NOTIFY_CHANGE_CREATION
  { Если не удалось получить хэндл - выводим ошибку и прерываем выполнение }
  Win32Check(ChangeHandle <> INVALID_HANDLE_VALUE);
  try
    { выполняем цикл пока }
    while not Terminated do
    begin
      case WaitForSingleObject(ChangeHandle, 1000) of
        WAIT_FAILED:
          Terminate; { Ошибка, завершаем поток }
        WAIT_OBJECT_0: // жождались
          Fcommand.FisRun_FolderChanged := True;
        WAIT_TIMEOUT:
          ; // время вышло - ничего не делаем
      end;
      FindNextChangeNotification(ChangeHandle);
    end;
  finally
    FindCloseChangeNotification(ChangeHandle);
    Fcommand.FisRun_FolderWatchingThread := nil;
  end;
end;

end.
