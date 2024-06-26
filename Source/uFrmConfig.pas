﻿unit uFrmConfig;

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ComCtrls, ExtCtrls, Menus, StdCtrls, ActnList, registry,
  uCommandsClass, windows, {RunAtTimeClasses_U,} Messages,
  TypInfo, System.Actions, Vcl.ImgList, uFrmCommandConfig, RCPopupMenu,
  Winapi.CommCtrl, System.Math, System.ImageList;

type

  { TfrmConfig }

  TfrmConfig = class(TForm)
    actAdd: TAction;
    actAddSub: TAction;
    actCopy: TAction;
    actDel: TAction;
    actClose: TAction;
    actApply: TAction;
    actItemDown: TAction;
    actItemUp: TAction;
    actOK: TAction;
    ActionList: TActionList;
    btnAdd: TButton;
    btnApply: TButton;
    btnClose: TButton;
    btnDel: TButton;
    btnCopy: TButton;
    btnOK: TButton;
    btnSubAdd: TButton;
    btnExtensions: TButton;
    btnUp: TButton;
    btnDown: TButton;
    cbRunOnWindowsStart: TCheckBox;
    gbItems: TGroupBox;
    gbProperties: TGroupBox;
    gbButtons: TGroupBox;
    gbMainButtons: TGroupBox;
    Label1: TLabel;
    MenuItem1: TMenuItem;
    ppCMExit: TMenuItem;
    ppCMConfig: TMenuItem;
    ppConfigMenu: TPopupMenu;
    TrayIcon: TTrayIcon;
    tvItems: TTreeView;
    TreeImageList: TImageList;
    frmCommandConfig: TfrmCommandConfig;
    cbLangs: TComboBox;
    lbLangs: TLabel;
    procedure actAddExecute(Sender: TObject);
    procedure actAddSubExecute(Sender: TObject);
    procedure actApplyExecute(Sender: TObject);
    procedure actApplyUpdate(Sender: TObject);
    procedure actCloseExecute(Sender: TObject);
    procedure actCloseUpdate(Sender: TObject);
    procedure actDelExecute(Sender: TObject);
    procedure actCopyUpdate(Sender: TObject);
    procedure actItemDownExecute(Sender: TObject);
    procedure actItemDownUpdate(Sender: TObject);
    procedure actItemUpExecute(Sender: TObject);
    procedure actItemUpUpdate(Sender: TObject);
    procedure actOKExecute(Sender: TObject);
    procedure btnDelClick(Sender: TObject);
    procedure btnExtensionsClick(Sender: TObject);
    procedure cbRunOnWindowsStartChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ppCMConfigClick(Sender: TObject);
    procedure ppCMExitClick(Sender: TObject);
    procedure tvItemsChange(Sender: TObject; Node: TTreeNode);
    procedure tvItemsChanging(Sender: TObject; Node: TTreeNode;
      var AllowChange: Boolean);
    procedure tvItemsDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure tvItemsEdited(Sender: TObject; Node: TTreeNode; var S: string);
    procedure TrayIconMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure tvItemsDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure ppTrayMenuMenuRightClick(Sender: TObject; Item: TMenuItem);
    procedure actCopyExecute(Sender: TObject);
    procedure tvItemsCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure cbLangsChange(Sender: TObject);
    procedure FormHide(Sender: TObject);
  private
    { private declarations }
    IsModified: Boolean;
    // IsTreeViewItemChanging: Boolean; // true if list changing

    MouseButtonSwapped: Boolean;

    ppTrayMenu: TRCPopupMenu;

    procedure UpdateTreeNodeIcon(const ATreeNode: TTreeNode);
    procedure CorrectTreeViewItemHeight;

    procedure DisposeTreeViewData;
    procedure DisposeTreeNodeData(TreeNode: TTreeNode);
    procedure ppTrayMenuItemOnClick(Sender: TObject);
    // procedure XMLToMenu(MenuItems: TMenuItem; const NotifyEvent: TNotifyEvent);
    procedure XMLToTree(TreeNodes: TTreeNodes);
    procedure TreeToMenu(ATreeNodes: TTreeNodes; AMenuItems: TMenuItem;
      const NotifyEvent: TNotifyEvent; AOldCommonDataList: TList);
    // due to don't terminate the App after close main window
    procedure WMClose(var Message: TMessage); message WM_CLOSE;
  protected
    procedure WndProc(var Message: TMessage); override;
  public
    { public declarations }
  end;

var
  frmConfig: TfrmConfig;

  WM_TASKBARCREATED: UINT = 0;

implementation

uses uCommon, uFrmFilters, uFilterClass, uLangs, XMLDoc, XMLIntf,
  Winapi.ShellAPI, System.UITypes;

{$R *.dfm}
{ TfrmConfig }

procedure TfrmConfig.actApplyExecute(Sender: TObject);
var
  oldCommonData: TList;
  procedure AddToOldCommonDataRecurse(AMenuItems: TMenuItem);
  var
    i: Integer;
    vmi: TMenuItem;
  begin
    for i := 0 to AMenuItems.Count - 1 do
    begin
      vmi := AMenuItems[i];
      oldCommonData.Add(Pointer(vmi.Tag));

      if vmi.Count > 0 then
        AddToOldCommonDataRecurse(vmi);
    end;
  end;

begin
  // if not IsModified then Exit;

  // 편집된 데이터를 저장하세요
  frmCommandConfig.SaveAssigned;

  TreeToXML(tvItems.Items); // 여기에 RunAtTime을 채우세요.

  // RunAtTime.LoadDataFromTreeNodes(tvItems.Items); // 예약된 시간 로드

  oldCommonData := TList.Create; // oldCommonData - 이전 작업 목록
  try
    AddToOldCommonDataRecurse(ppTrayMenu.Items);

    ppTrayMenu.Items.Clear;

    TreeToMenu(tvItems.Items, ppTrayMenu.Items, ppTrayMenuItemOnClick,
      oldCommonData);

  finally
    oldCommonData.Free;
  end;

  with TRegistry.Create(KEY_READ or KEY_WRITE or KEY_SET_VALUE) do
    try
      RootKey := HKEY_CURRENT_USER;
      if OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', True) then
        if cbRunOnWindowsStart.Checked then
          WriteString('SyncData', ParamStr(0))
        else
          DeleteValue('SyncData');
    finally
      Free;
    end;
  IsModified := False;
end;

procedure TfrmConfig.actAddExecute(Sender: TObject);
begin
  tvItems.Selected := tvItems.Items.AddObject(tvItems.Selected, '',
    TCommandData.Create);

  tvItems.Selected.ImageIndex := -1;
  tvItems.Selected.SelectedIndex := -1;

  if tvItems.Items.Count = 1 then // first adding
    CorrectTreeViewItemHeight;

  tvItems.Repaint;

  IsModified := True;
end;

procedure TfrmConfig.actAddSubExecute(Sender: TObject);
begin
  if tvItems.Selected <> nil then
  begin
    tvItems.Selected.Expanded := True;
    tvItems.Selected.ImageIndex := 0;
    tvItems.Selected.SelectedIndex := 0;

    tvItems.Selected := tvItems.Items.AddChildObject(tvItems.Selected, '',
      TCommandData.Create);

    tvItems.Selected.ImageIndex := -1;
    tvItems.Selected.SelectedIndex := -1;

    tvItems.Repaint;
    // tvItems.Selected.Data := TCommandData.Create;

    // gbProperties.Enabled := True;

    IsModified := True;

  end;
end;

procedure TfrmConfig.actApplyUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := IsModified or frmCommandConfig.IsModified;
end;

procedure TfrmConfig.actCloseExecute(Sender: TObject);
begin
  if (IsModified or frmCommandConfig.IsModified) then
  begin
    if AskForConfirmation(Self, GetLangString('LangStrings', 'CancelConfirm'))
    then
    begin
      Hide;

      ppTrayMenu.Items.Clear; // Data will be cleared below

      DisposeTreeViewData;
      frmCommandConfig.Assign(nil);
      tvItems.Items.Clear;
      frmCommandConfig.Assign(nil);
      TreeImageList.Clear;
      IsModified := False;

      // 파일에서 다시 읽기
      XMLToTree(tvItems.Items);

      TreeToMenu(tvItems.Items, ppTrayMenu.Items, ppTrayMenuItemOnClick, nil);

      // 첫 번째 요소가 있으면 에뮬레이션합니다.
      { if tvItems.Items.Count > 1 then
        tvItemsChange(tvItems, tvItems.Items[0]); }
    end
  end
  else
  begin
    Hide;
  end;
  { else
    begin
    Hide;
    Application.Title := TrayIcon.Hint; //'Quick run from Tray';
    end; }
end;

procedure TfrmConfig.actCloseUpdate(Sender: TObject);
begin
  if IsModified or frmCommandConfig.IsModified then
    actClose.Caption := GetLangString('LangStrings', 'Cancel') // 'Cancel'
  else
    actClose.Caption := GetLangString('LangStrings', 'Close'); // 'Close';
end;

procedure TfrmConfig.actDelExecute(Sender: TObject);
var
  futureSelNode: TTreeNode;
  needToUpdateIsGroup: Boolean;
begin
  if Assigned(tvItems.Selected) and AskForDeletion(Self, tvItems.Selected.Text)
  then
  begin
    needToUpdateIsGroup := False;

    DisposeTreeNodeData(tvItems.Selected);

    // 무엇을 선택해 둘지 결정하자
    futureSelNode := tvItems.Selected.GetNextSibling;
    // 같은 레벨의 다음 요소를 선택해 보겠습니다.
    if futureSelNode = nil then
    begin
      futureSelNode := tvItems.Selected.GetPrevSibling;
      // 같은 레벨의 이전 요소를 선택해 보겠습니다.
      if futureSelNode = nil then
      begin
        futureSelNode := tvItems.Selected.Parent;
        // 그런 다음 부모를 선택하려고 합니다.
        if futureSelNode = nil then
          futureSelNode := tvItems.TopItem // 맨 위에 있는 것을 선택해 보세요
        else // 상위 항목이 있는 경우 해당 그룹 속성을 확인해야 합니다.
          needToUpdateIsGroup := True;
        // TCommandData(futureSelNode).isGroup := futureSelNode.HasChildren;
      end;
    end;
    frmCommandConfig.Assign(nil);
    // avoid possible bug and better empty view for properties
    tvItems.Selected.Delete;

    tvItems.Selected := futureSelNode;

    if needToUpdateIsGroup and (tvItems.Selected <> nil) then
    begin
      TCommandData(tvItems.Selected.Data).isGroup :=
        tvItems.Selected.HasChildren;
      UpdateTreeNodeIcon(tvItems.Selected);
    end;

    IsModified := True;
  end;
end;

procedure TfrmConfig.actCopyExecute(Sender: TObject);
var
  vSelected: TTreeNode;
  vDest: TCommandData;
  vOldImageIndex: Integer;
begin
  vSelected := tvItems.Selected;
  if not Assigned(vSelected) then
    Exit;

  vDest := TCommandData.Create;
  TCommandData(vSelected.Data).Assign(vDest);
  vOldImageIndex := vSelected.ImageIndex;

  tvItems.Selected := tvItems.Items.AddObject(tvItems.Selected,
    tvItems.Selected.Text, vDest);

  // frmCommandConfig.edtCommandChange Extract an icon and set valid ImageIndex
  if vOldImageIndex <> 0 then
    tvItems.Selected.ImageIndex := -1; // 0 is default value
  frmCommandConfig.edtCommandChange(nil);

  // tvItems.Selected.ImageIndex := -1;
  // tvItems.Selected.SelectedIndex := -1;

  tvItems.Repaint;

  IsModified := True;
end;

procedure TfrmConfig.actCopyUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := tvItems.Selected <> nil;
  // gbProperties.Enabled := (tvItems.Selected <> nil);
  frmCommandConfig.Enabled := (tvItems.Selected <> nil);
end;

procedure TfrmConfig.actItemDownExecute(Sender: TObject);
begin
  if (tvItems.Selected = nil) or (tvItems.Selected.GetNextSibling = nil) then
    Exit;

  tvItems.Selected.GetNextSibling.MoveTo(tvItems.Selected, naInsert);
  IsModified := True;
end;

procedure TfrmConfig.actItemDownUpdate(Sender: TObject);
begin
  actItemDown.Enabled := (tvItems.Selected <> nil) and
    (tvItems.Selected.GetNextSibling <> nil);
end;

procedure TfrmConfig.actItemUpExecute(Sender: TObject);
begin
  if (tvItems.Selected = nil) or (tvItems.Selected.GetPrevSibling = nil) then
    Exit;

  tvItems.Selected.MoveTo(tvItems.Selected.GetPrevSibling, naInsert);
  IsModified := True;
end;

procedure TfrmConfig.actItemUpUpdate(Sender: TObject);
begin
  actItemUp.Enabled := (tvItems.Selected <> nil) and
    (tvItems.Selected.GetPrevSibling <> nil);
end;

procedure TfrmConfig.actOKExecute(Sender: TObject);
begin
  actApplyExecute(actApply);
  Hide;
end;

procedure TfrmConfig.btnDelClick(Sender: TObject);
begin
  if tvItems.Selected <> nil then
    tvItems.Items.Delete(tvItems.Selected);
end;

procedure TfrmConfig.btnExtensionsClick(Sender: TObject);
begin
  with frmExtensions do
  begin
    AssignFilters(Filters);
    if ShowModal = mrOk then
    begin
      MoveToFilters(Filters);
      Filters_SaveToFile;
    end
    else
      ClearAllIfCancel;
  end;
end;

procedure TfrmConfig.cbLangsChange(Sender: TObject);
begin
  SetLang(StrPas(PChar(cbLangs.Items.Objects[cbLangs.ItemIndex])));
end;

procedure TfrmConfig.cbRunOnWindowsStartChange(Sender: TObject);
begin
  IsModified := True;
end;

procedure TfrmConfig.CorrectTreeViewItemHeight;
begin
  TreeView_SetItemHeight(tvItems.Items[0].Handle, gMenuItemBmpHeight +
    IfThen(Odd(gMenuItemBmpHeight), 3, 2));
end;

procedure TfrmConfig.FormCreate(Sender: TObject);
begin
  // ShowMessage('Test');
  MouseButtonSwapped := GetSystemMetrics(SM_SWAPBUTTON) <> 0;

  ShowMsgIfDebug('MouseButtonSwapped', BoolToStr(MouseButtonSwapped, True));

  ppTrayMenu := TRCPopupMenu.Create(Self);
  with ppTrayMenu do
  begin
    Images := TreeImageList;
    OwnerDraw := True;
    OnMenuRightClick := ppTrayMenuMenuRightClick;
  end;

  // if not Swapped then tbRightButton else tbLeftButton
  // ppTrayMenu.TrackButton := TTrackButton(MouseButtonSwapped);
  ppConfigMenu.TrackButton := TTrackButton(MouseButtonSwapped);

  TrayIcon.Icon := Application.Icon;

  TreeImageList.Width := gMenuItemBmpWidth;
  TreeImageList.Height := gMenuItemBmpHeight;

  frmCommandConfig.TreeImageList := TreeImageList;

  XMLToTree(tvItems.Items);

  TreeToMenu(tvItems.Items, ppTrayMenu.Items, ppTrayMenuItemOnClick, nil);

  if tvItems.Items.Count > 0 then
  begin
    CorrectTreeViewItemHeight;
  end
  else
    frmCommandConfig.Assign(nil);

  with TRegistry.Create(KEY_READ) do
    try
      RootKey := HKEY_CURRENT_USER;
      cbRunOnWindowsStart.Checked :=
        OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Run') and
        ValueExists('SyncData');
      IsModified := False;
    finally
      Free;
    end;

  // tvItems.FullExpand;

  { RunAtTime := TRunAtTime.Create;
    RunAtTime.LoadDataFromTreeNodes(tvItems.Items); // загрузить запланированное время }

  IsModified := False;

  WM_TASKBARCREATED := RegisterWindowMessage('TaskbarCreated');
end;

procedure TfrmConfig.FormDestroy(Sender: TObject);
begin
  // FreeAndNil(RunAtTime);
end;

procedure TfrmConfig.FormHide(Sender: TObject);
begin
  Application.Title := TrayIcon.Hint;
end;

procedure TfrmConfig.FormShow(Sender: TObject);
begin
  Application.Title := TrayIcon.Hint + ' - ' + Caption;
  // LangStrings['frmConfig.Caption']; // 'Quick run from Tray - Options';
  tvItems.SetFocus;
end;

procedure TfrmConfig.ppCMConfigClick(Sender: TObject);
begin
  Show;
end;

procedure TfrmConfig.ppCMExitClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TfrmConfig.TrayIconMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  SetForegroundWindow(Handle);
  PostMessage(Handle, WM_NULL, 0, 0);

  ppTrayMenu.CloseMenu;
  // all right with button swap (so mbLeft may be sometimes as mbRight :) )
  if Button = mbLeft then
  begin
    ppTrayMenu.Popup(X, Y);
  end
  else if Button = mbMiddle then
    Show;
end;

// AOldCommonDataList - 제거할 이전 명령 목록에 대한 링크입니다. 처음에는 nil을 전달합니다.
procedure TfrmConfig.TreeToMenu(ATreeNodes: TTreeNodes; AMenuItems: TMenuItem;
  const NotifyEvent: TNotifyEvent; AOldCommonDataList: TList);
var
  tn: TTreeNode;

  procedure ProcessTreeItem(atn: TTreeNode; ami: TMenuItem);
  var
    newMenuItem: TMyMenuItem;
    vtn: TTreeNode;
    vCommonData: TCommandData;
    i: Integer;
  begin

    if AOldCommonDataList <> nil then
    begin
      i := AOldCommonDataList.IndexOf(atn.Data);
      if i >= 0 then
        AOldCommonDataList.Delete(i);
    end;

    vCommonData := TCommandData(atn.Data);
    if not vCommonData.isVisible then
      Exit;

    newMenuItem := TMyMenuItem.Create(AMenuItems);

    with newMenuItem do
    begin
      Caption := atn.Text;
      ImageIndex := atn.ImageIndex;
      // Font.Color := IfThen(MyExtendFileNameToFull(vCommonData.Command) <> '',
      // TColors.SysWindowText, TColors.Red);
      Tag := LongInt(atn.Data);
      OnClick := NotifyEvent;
      // OnDrawItem := ppTrayMenuItemOnDrawItem;
    end;

    ami.Add(newMenuItem);

    // child nodes
    vtn := atn.GetFirstChild;
    while vtn <> nil do
    begin
      ProcessTreeItem(vtn, newMenuItem);
      vtn := vtn.GetNextSibling;
    end;
  end; (* ProcessTreeItem *)

begin
  tn := ATreeNodes.GetFirstNode; // TopNode;
  while tn <> nil do
  begin
    ProcessTreeItem(tn, AMenuItems);

    tn := tn.GetNextSibling;
  end;
end;

procedure TfrmConfig.tvItemsChange(Sender: TObject; Node: TTreeNode);
begin
  // gbProperties.Enabled := True;
  // frmCommandConfig.edtCaption.SetFocus;

  // if (Node <> nil) and (Node.Data <> nil) then
  begin
    // IsTreeViewItemChanging := True;
    // if Showing then
    // if Visible then
    // нет смысла в оптимизации - вызывается один раз и для корня - так и надо!
    frmCommandConfig.Assign(Node);

    // IsTreeViewItemChanging := False;
  end
  { else // скорей всего, первый элемент создается
    begin
    gbProperties.Enabled := True;
    frmCommandConfig.edtCaption.SetFocus;
    end; }

end;

procedure TfrmConfig.tvItemsChanging(Sender: TObject; Node: TTreeNode;
  var AllowChange: Boolean);
begin
  // AllowChange := (tvItems.Selected <> nil) and not Node.Deleting;
  if (tvItems.Selected <> nil) and not Node.Deleting then
  begin
    if frmCommandConfig.IsModified then
      IsModified := True;
    frmCommandConfig.SaveAssigned;
  end;
  // Label1.Caption := Node.Text + '; ' + BoolToStr(TCommandData(frmDateTimeToRun1.ItemData).isRunAt, true);

  // Node.Data := frmDateTimeToRun1.ItemData;
end;

procedure TfrmConfig.tvItemsCustomDrawItem(Sender: TCustomTreeView;
  Node: TTreeNode; State: TCustomDrawState; var DefaultDraw: Boolean);
begin
  // if not Assigned(Node.Data) or (MyExtendFileNameToFull(TCommandData(Node.Data).Command) <> '') then
  if Node.HasChildren or not Assigned(Node.Data) or
    ((Node = frmCommandConfig.AssignedTreeNode) and
    frmCommandConfig.CheckFileCommandExists) or
    ((Node <> frmCommandConfig.AssignedTreeNode) and
    (MyExtendFileNameToFull(TCommandData(Node.Data).Command) <> '')) then
    Sender.Canvas.Font.Style := [] // .Color := TColors.SysWindowText
  else
  begin
    Sender.Canvas.Font.Style := [fsStrikeOut]; // .Color := TColors.Red;
    // Sender.Canvas.Font.Color := clWindowText; // непонятно, почему белый по умолчанию
  end;
end;

procedure TfrmConfig.tvItemsDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  vTreeNode, vOldParentNode: TTreeNode;
  vMode: TNodeAttachMode; // vOldParentImageIndex: Integer;
begin
  if Source <> Sender then
    Exit;

  vTreeNode := tvItems.GetNodeAt(X, Y); // element under mouse

  if vTreeNode = tvItems.Selected then
    Exit; // the same element

  if vTreeNode = nil then
    // если переносим в пустое место, то добавить
    if Y > 0 then
      vMode := naAdd // at the end
    else
      vMode := naAddFirst // at the begin
  else
  begin
    vMode := naAddChild; // .. иначе добавить родственником
    TCommandData(vTreeNode.Data).isGroup := True;
    UpdateTreeNodeIcon(vTreeNode);
    { vTreeNode.ImageIndex := 0;
      vTreeNode.SelectedIndex := 0; }
  end;

  // if it was last children in Parent tree, so it's not a parent anymore
  vOldParentNode := tvItems.Selected.Parent;
  // vTreeNode is current parent
  if (vOldParentNode <> nil) and (vOldParentNode.Count <= 1) and
    (vOldParentNode <> vTreeNode) then
  begin
    TCommandData(vOldParentNode.Data).isGroup := False;
    UpdateTreeNodeIcon(vOldParentNode);
    { vOldParentImageIndex := ImageList_ReplaceIcon(TreeImageList.Handle, vOldParentNode.ImageIndex,
      MyExtractIcon(TCommandData(vOldParentNode.Data).Command));

      vOldParentNode.ImageIndex := vOldParentImageIndex;
      vOldParentNode.SelectedIndex := vOldParentImageIndex; }
  end;

  tvItems.Selected.MoveTo(vTreeNode, vMode);
  IsModified := True;
end;

procedure TfrmConfig.tvItemsDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  Accept := (Sender = Source) and (Sender = tvItems);
end;

procedure TfrmConfig.tvItemsEdited(Sender: TObject; Node: TTreeNode;
  var S: string);
begin
  if Node.Text <> S then
    frmCommandConfig.Caption := S;
end;

procedure TfrmConfig.UpdateTreeNodeIcon(const ATreeNode: TTreeNode);
var
  vCommandData: TCommandData;
  vNewImageIndex: Integer;
  vIcon: THandle;
begin
  vCommandData := TCommandData(ATreeNode.Data);
  if vCommandData.isGroup then
    vNewImageIndex := 0
  else
  begin
    vIcon := MyExtractIcon(vCommandData.Command);
    if vIcon > 0 then
    begin
      if ATreeNode.ImageIndex <= 0 then
        vNewImageIndex := -1 // add
      else
        vNewImageIndex := ATreeNode.ImageIndex;
      vNewImageIndex := ImageList_ReplaceIcon(TTreeView(ATreeNode.TreeView)
        .Images.Handle, vNewImageIndex, vIcon)
    end
    else
      vNewImageIndex := -1;
  end;
  ATreeNode.ImageIndex := vNewImageIndex;
  ATreeNode.SelectedIndex := vNewImageIndex;
end;

procedure TfrmConfig.WMClose(var Message: TMessage);
begin
  actCloseExecute(actClose);
  // Application.Title := TrayIcon.Hint; //'Quick run from Tray';
  // Hide;
end;

procedure TfrmConfig.WndProc(var Message: TMessage);
// var vWM_TASKBARCREATED: UINT;
begin
  if (WM_TASKBARCREATED > 0) and (Message.Msg = WM_TASKBARCREATED) then
  begin
    // возможно надо заново регистрировать (вроде не надо)
    // vWM_TASKBARCREATED := WM_TASKBARCREATED;
    WM_TASKBARCREATED := RegisterWindowMessage('TaskbarCreated');
    // ShowMessage('Debug: Begin. WM_TASKBARCREATED: Old = ' + IntToStr(vWM_TASKBARCREATED) + '; New = ' + IntToStr(WM_TASKBARCREATED));

    // Иногда оно True, но реально не отображается, поэтому False не прокатит.
    try
      TrayIcon.Visible := False;
      // если не будет работать, то смотреть в сторону Shell_NotifyIcon, NIM_ADD, node(типа NOTIFYICONDATA_
    except
      { ShowMessage('Debug: Begin. WM_TASKBARCREATED: Old = ' + IntToStr(vWM_TASKBARCREATED) + '; New = ' + IntToStr(WM_TASKBARCREATED) + #13#10 +
        'Except: GetLastError = ' + IntToStr(GetLastError)); }
    end;
    TrayIcon.Visible := True;
  end;
  inherited WndProc(Message);
end;

{ procedure TfrmConfig.XMLToMenu(MenuItems: TMenuItem;
  const NotifyEvent: TNotifyEvent);
  var
  XMLDoc: IXMLDocument;
  cNode: IXMLNode;
  //iImageListIndex: integer;
  //w: word;

  procedure ProcessNode(Node: IXMLNode; MenuItem: TMenuItem);
  var
  aNode: IXMLNode;
  //NodeAttributes: TDOMNamedNodeMap;
  s: string;// vBM: TBitmap;
  newMenuItem: TMenuItem; vCommonData: TCommandData; vHandle: THandle;
  begin
  // такая проверка все равно есть перед заходом в рекурсию
  //if aNode = nil then Exit; // выходим, если достигнут конец документа

  //NodeAttributes := Node.Attributes; // for cache only

  s := LowerCase( GetPropertyFromNodeAttributes(Node, 'isVisible') );
  if (s = '') or (s = '1') then
  begin
  s := GetPropertyFromNodeAttributes(Node, 'Caption');
  if s <> '' then
  begin
  // добавляем узел меню
  newMenuItem := TMenuItem.Create(MenuItems);
  newMenuItem.Caption := s;

  newMenuItem.OnClick := NotifyEvent;

  MenuItem.Add(newMenuItem);
  end
  else
  Exit; // нет текста, то что и не видима
  end
  else
  Exit;
  // если не видим, значит и вложения не должны быть видны

  vCommonData := TCommandData.Create(Node, False);

  if not vCommonData.isGroup then
  begin
  newMenuItem.Bitmap.Canvas.Brush.Color := clMenu;
  newMenuItem.Bitmap.Width := gMenuItemBmpWidth;
  newMenuItem.Bitmap.Height := gMenuItemBmpHeight;

  vHandle := MyExtractIcon(vCommonData.Command);
  if vHandle <> 0 then
  begin
  DrawIconEx(newMenuItem.Bitmap.Canvas.Handle, 0, 0, vHandle,
  gMenuItemBmpWidth, gMenuItemBmpHeight, 0,
  newMenuItem.Bitmap.Canvas.Brush.Handle, DI_NORMAL);
  end;

  newMenuItem.Tag :=longint(vCommonData);
  end;

  // переходим к дочернему узлу
  aNode := Node.ChildNodes.First;

  // проходим по всем дочерним узлам
  while aNode <> nil do
  begin
  ProcessNode(aNode, newMenuItem);
  aNode := aNode.NextSibling;
  end;
  end;

  begin
  if not FileExists(ExtractFilePath(ParamStr(0)) + 'StartFromTray_tvItems.xml') then
  Exit;
  XMLDoc := TXMLDocument.Create(nil);

  XMLDoc.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'StartFromTray_tvItems.xml');

  cNode := XMLDoc.ChildNodes.FindNode('tree2xml').ChildNodes.First;
  MenuItems.Clear; //iImageListIndex := 0;//MenuItems.Parent.ImageList.Clear;
  while cNode <> nil do
  begin
  ProcessNode(cNode, MenuItems); // Рекурсия
  cNode := cNode.NextSibling;
  end;
  end; }

// запускается при старте и нажатии "Отмена"
procedure TfrmConfig.XMLToTree(TreeNodes: TTreeNodes);
var
  ImageListHandle: HIMAGELIST;

  procedure ProcessNode(Node: IXMLNode; TreeNode: TTreeNode);
  var
    aNode: IXMLNode;
    vCommandData: TCommandData;
    iImageListIndex: Integer;
    vhIcon: HICON;
    // w: word;
    // NodeAttributes: OleVariant; vCommonData: TCommandData;
  begin
    // if aNode = nil then Exit; // выходим, если достигнут конец документа

    // NodeAttributes := Node.Attributes; // for cache only

    // добавляем узел в дерево
    TreeNode := TreeNodes.AddChild(TreeNode, GetPropertyFromNodeAttributes(Node,
      'Caption'));

    // vCommonData := TCommandData.Create(Node, True);

    // TreeNode.Data := TCommandData.Create(Node, True);
    vCommandData := TCommandData.Create(Node, True);

    TreeNode.Data := vCommandData;

    // переходим к дочернему узлу
    aNode := Node.ChildNodes.First;

    // проходим по всем дочерним узлам
    while aNode <> nil do
    begin
      ProcessNode(aNode, TreeNode);
      aNode := aNode.NextSibling;
    end;

    // fix potencial and prev. bug then isGroup = 1 for no children node
    vCommandData.isGroup := TreeNode.HasChildren;

    if vCommandData.isGroup then
    begin
      TreeNode.ImageIndex := 0;
      TreeNode.SelectedIndex := 0;
    end
    else
    begin
      // w := 0;
      vhIcon := MyExtractIcon(vCommandData.Command);
      iImageListIndex := ImageList_ReplaceIcon(ImageListHandle, -1, vhIcon);
      if vhIcon > 0 then
        DestroyIcon(vhIcon);

      TreeNode.ImageIndex := iImageListIndex;
      TreeNode.SelectedIndex := iImageListIndex;
    end;
  end;

var
  XMLDoc: IXMLDocument;
  cNode: IXMLNode;
  w: word; // ImageList: TCustomImageList;

begin

  // ImageList := TTreeView(TreeNodes.Owner).Images;
  ImageListHandle := TreeImageList.Handle; // ImageList.Handle;

  // ничего страшного, т.к. ppMenuItem использует тот же ImageList и мы его заново инициалищируем
  // ImageList.Clear;

  // добавим иконку для папки, если не добавлено (всегда первая)
  w := 3;
  // if ImageList.Count = 0 then
  ImageList_ReplaceIcon(ImageListHandle, -1,
    ExtractAssociatedIcon(Application.Handle, PChar('SHELL32.dll'), w));

  if not FileExists(ExtractFilePath(ParamStr(0)) + cItemsFileName) then
  // 'StartFromTray_tvItems.xml') then
    Exit;

  XMLDoc := TXMLDocument.Create(nil);

  XMLDoc.LoadFromFile(ExtractFilePath(ParamStr(0)) + cItemsFileName);
  // 'StartFromTray_tvItems.xml');

  { iImageListIndex := ImageList_ReplaceIcon(ImageListHandle, -1,
    ExtractAssociatedIcon(Application.Handle, PChar('SHELL32.dll'), w)); }

  cNode := XMLDoc.ChildNodes.FindNode('tree2xml').ChildNodes.First;
  while cNode <> nil do
  begin
    ProcessNode(cNode, nil); // Рекурсия
    cNode := cNode.NextSibling;
  end;

  TreeNodes.Owner.FullExpand;
end;

procedure TfrmConfig.DisposeTreeViewData;
var
  tn: TTreeNode;
begin
  tn := tvItems.TopItem;
  while tn <> nil do
  begin
    DisposeTreeNodeData(tn);
    tn := tn.GetNextSibling;
  end;
end;

procedure TfrmConfig.DisposeTreeNodeData(TreeNode: TTreeNode);
var
  p: TCommandData;
begin
  // if (TreeNode = nil) then Exit;
  if TreeNode.Data <> nil then
  begin
    p := TCommandData(TreeNode.Data);
    FreeAndNil(p);
    TreeNode.Data := nil;
  end;

  // child nodes
  TreeNode := TreeNode.GetFirstChild;
  while TreeNode <> nil do
  begin
    DisposeTreeNodeData(TreeNode);
    TreeNode := TreeNode.GetNextSibling;
  end;
end;

procedure TfrmConfig.ppTrayMenuItemOnClick(Sender: TObject);
var
  AMenuItem: TMenuItem;
  vCommandData: TCommandData;
begin
  AMenuItem := (Sender as TMenuItem);
  if AMenuItem.Count = 0 then
  begin
    vCommandData := TCommandData(AMenuItem.Tag);
    if not MouseButtonSwapped then
      vCommandData.Run(crtNormalRun)
    else
      vCommandData.Edit;
  end;
end;

procedure TfrmConfig.ppTrayMenuMenuRightClick(Sender: TObject; Item: TMenuItem);
var
  vCommandData: TCommandData;
begin
  if Item.Count = 0 then
  begin
    vCommandData := TCommandData(Item.Tag);
    if not MouseButtonSwapped then
      vCommandData.Edit
    else
      vCommandData.Run(crtNormalRun);
  end;
end;

end.
