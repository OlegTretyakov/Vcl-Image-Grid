unit ImageViewerMainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.ImageGrid, System.ImageList, Vcl.ImgList, Vcl.Imaging.jpeg, Vcl.Graphics;

type
  TImgViewerMainFrm = class(TForm)
    Panel1: TPanel;
    Splitter1: TSplitter;
    StatusBar1: TStatusBar;
    DirectoryTree: TTreeView;
    ImageList1: TImageList;
    procedure FormShow(Sender: TObject);
    procedure DirectoryTreeExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
    procedure DirectoryTreeDeletion(Sender: TObject; Node: TTreeNode);
    procedure DirectoryTreeCollapsed(Sender: TObject; Node: TTreeNode);
    procedure DirectoryTreeClick(Sender: TObject);
  private
    fImageGrid: TImageFilesGrid;
    fSelectedNode : TTreeNode;
    function FillRoot : boolean;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  ImgViewerMainFrm: TImgViewerMainFrm;

implementation

uses
System.Types,
System.IOUtils;

const
C_ROOT_NAME = 'This computer';

type
TFolderType = (ftDrive, ftDir);
TDirectoryData = record
  DirType : TFolderType;
  FullPath : string;
end;

pDirectoryData = ^TDirectoryData;

{$R *.dfm}

constructor TImgViewerMainFrm.Create(AOwner: TComponent);
begin
  inherited;
  fImageGrid := TImageFilesGrid.Create(self);
  fImageGrid.Parent := Self;
  fImageGrid.Align := alClient;
end;

procedure TImgViewerMainFrm.DirectoryTreeClick(Sender: TObject);
const
C_SrExt : array[0..3] of string = ('\*.bmp','\*.jpg','\*.jpeg','\*.png');//,'\*.ico');
var
 vNode: TTreeNode;
 vData : pDirectoryData;
 vSR: TSearchRec;
 vSt : TStringList;
 vExtStr : string;
begin
  if DirectoryTree.SelectionCount = 1 then
  begin
    vNode := DirectoryTree.Selected;
    if fSelectedNode = vNode then
      Exit;
    fSelectedNode := vNode;
    if not Assigned(vNode.Data) then
      Exit;
    vData := pDirectoryData(vNode.Data);
    vSt := TStringList.Create;
    try
      for vExtStr in C_SrExt do
      begin
        if FindFirst(vData.FullPath+vExtStr, faAnyFile, vSR) = 0 then
        try
          repeat
            vSt.Add(vSR.Name);
          until FindNext(vSR) <> 0;
        finally
          FindClose(vSR);
        end;
      end;
      vSt.Sort;
      fImageGrid.BeginUpdate;
      try
        fImageGrid.Clear;
        for vExtStr in vSt do
          fImageGrid.Add(vData.FullPath+'\'+vExtStr);
      finally
        fImageGrid.EndUpdate;
      end;
    finally
      FreeAndNil(vSt);
    end;
  end;
end;

procedure TImgViewerMainFrm.DirectoryTreeCollapsed(Sender: TObject; Node: TTreeNode);
var
 vData : pDirectoryData;
begin
  if Node = DirectoryTree.Items.GetFirstNode then
    Exit;
  if not Assigned(Node.Data) then
    Exit;
  vData := pDirectoryData(Node.Data);
  if vData.DirType = ftDir then
  begin
    Node.ImageIndex := 2;
    Node.SelectedIndex := 2;
  end;
end;

procedure TImgViewerMainFrm.DirectoryTreeDeletion(Sender: TObject; Node: TTreeNode);
var
 vData : pDirectoryData;
begin
  if not Assigned(Node.Data) then
    Exit;
  vData := pDirectoryData(Node.Data);
  Dispose(vData); 
end;

procedure TImgViewerMainFrm.DirectoryTreeExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);  
var   
  i : Integer;
  vChildNode : TTreeNode;
  vDirectories : TStringDynArray; 
  vData : pDirectoryData;
begin
  if Node = DirectoryTree.Items.GetFirstNode then
  begin
    AllowExpansion := FillRoot;
    Exit;
  end;  
  vData := pDirectoryData(Node.Data);
  vDirectories := TDirectory.GetDirectories(vData.FullPath);
  AllowExpansion := Length(vDirectories) > 0;
  if not AllowExpansion then
    Exit;
  DirectoryTree.Items.BeginUpdate; 
  try    
    vChildNode := Node.getFirstChild;
    while Assigned(vChildNode) do
    begin
      DirectoryTree.Items.Delete(vChildNode);
      vChildNode := Node.getFirstChild;
    end;  
    if not Assigned(Node.Data) then
      Exit;
    vData := pDirectoryData(Node.Data); 
    if vData.DirType = ftDir then
    begin 
      Node.ImageIndex := 3;
      Node.SelectedIndex := 3;
    end;
    for i := Low(vDirectories) to High(vDirectories) do
    begin       
      if TDirectory.Exists(vDirectories[i]) then
      begin
        vChildNode := DirectoryTree.Items.AddChild(Node, ExtractFileName(vDirectories[i])); 
        vChildNode.ImageIndex := 2; 
        vChildNode.SelectedIndex := 2;
        New(vData);
        vChildNode.Data := vData;
        vData.FullPath := vDirectories[i]; 
        vData.DirType := ftDir; 
        if Length(TDirectory.GetDirectories(vDirectories[i])) > 0 then
          DirectoryTree.Items.AddChild(vChildNode, '');
      end;
    end;
  finally
    DirectoryTree.Items.EndUpdate;
  end;
end;

function TImgViewerMainFrm.FillRoot : boolean;
var
  i, j : Integer;
  vRoot, vChildNode : TTreeNode;
  vDrives, vDirectories : TStringDynArray;  
  vData : pDirectoryData;
begin
  j := 0;
  DirectoryTree.Items.BeginUpdate;
  try
    vRoot := DirectoryTree.Items.GetFirstNode; 
    vRoot.Text := C_ROOT_NAME;
    vRoot.ImageIndex := 0;
    vRoot.SelectedIndex := 0;
    vChildNode := vRoot.getFirstChild;
    while Assigned(vChildNode) do
    begin
      DirectoryTree.Items.Delete(vChildNode);
      vChildNode := vRoot.getFirstChild;
    end;
    vDrives := TDirectory.GetLogicalDrives;
    for i := Low(vDrives) to High(vDrives) do
    begin       
      if TDirectory.Exists(vDrives[i]) then
      begin
        vChildNode := DirectoryTree.Items.AddChild(vRoot, ExtractFileDrive(vDrives[i])); 
        vChildNode.ImageIndex := 1;   
        vChildNode.SelectedIndex := 1;
        New(vData);
        vChildNode.Data := vData;
        vData.FullPath := vDrives[i]; 
        vData.DirType := ftDrive;
        Inc(j);     
        vDirectories := TDirectory.GetDirectories(vDrives[i]);
        if Length(vDirectories) > 0 then
          DirectoryTree.Items.AddChild(vChildNode, '');
      end;
    end;
    if j < 1 then
      DirectoryTree.Items.AddChild(vRoot, '');
  finally
    DirectoryTree.Items.EndUpdate;
    result := j > 0;
  end;
end;

procedure TImgViewerMainFrm.FormShow(Sender: TObject);
begin
  FillRoot;
end;

end.
