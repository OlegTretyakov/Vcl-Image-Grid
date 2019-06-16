(*====================================================================*)
{Control by Oleg Tretyakov}
(*====================================================================*)

unit Vcl.ImageGrid;

interface
  uses
  System.Classes,
  System.Generics.Collections,
  System.Threading,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.ExtCtrls,
  System.Types,
  Winapi.Windows,
  Winapi.Messages;

type
  TPictireSize = System.Types.TSize;
  TPicturePoint = System.Types.TPoint;
  TStretchMode = (smVertical, smHorizontal);
  TStretchPriority = (spSize, spCount);


  TImages = class;
  TImageGrid = class;

  TGridImage = class(TImage)
   private
    fList : TImages;
   public
    constructor Create(AOwner : TImageGrid); reintroduce;
    destructor Destroy; override;
  end;
  TGridImageClass = class of TGridImage;
  TImages  = class(TList<TGridImage>)
   private
    FGrid : TImageGrid;
    function AddImage(AClass : TGridImageClass) : TGridImage;
   protected
    procedure Notify(const Value: TGridImage; Action: TCollectionNotification); override;
   public
    constructor Create(AGrid : TImageGrid); reintroduce;
  end;

  TImageGrid = class(TScrollBox)
   private
    fImages : TImages;
    fEditing : Boolean;
    fMode : TStretchMode;
    fFixedRows : Integer;
    fFixedCols : Integer;
    fMaxRows : Integer;
    fMaxCols : Integer;
    fPictureSize : TPictireSize;
    fPictureStretchPriority : TStretchPriority;
    procedure SetMode(const Value: TStretchMode);
    procedure SetFixedCols(const Value: integer);
    procedure SetFixedRows(const Value: integer);
    procedure SetMaxCols(const Value: integer);
    procedure SetMaxRows(const Value: integer);
    procedure SetPictureSize(const Value: TPictireSize);
    procedure SetPictureStretchPriority(const Value: TStretchPriority);
    procedure UpdatePictures;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
   protected
    function DefaultImageClass : TGridImageClass; virtual;
    procedure Resizing(State: TWindowState); override;
   public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function ImagesCount : Integer;
    procedure BeginUpdate;
    function Add(const AClass : TGridImageClass = nil) : TGridImage;
    procedure Delete(AIndex : Integer);
    procedure Clear;
    procedure EndUpdate;
   published
    property Mode: TStretchMode read FMode write SetMode;
    property FixedRows: integer  read FFixedRows write SetFixedRows;
    property FixedCols : integer read fFixedCols write SetFixedCols;
    property MaxRows: integer  read FMaxRows write SetMaxRows;
    property MaxCols : integer read fMaxCols write SetMaxCols;
    property PictureSize : TPictireSize read fPictureSize write SetPictureSize;
    property PictureStretchPriority : TStretchPriority read fPictureStretchPriority write SetPictureStretchPriority;
  end;

  TGridFileImage = class(TGridImage)
   private
    type
     TImageState = (isNotLoaded, isPainted, isError);
    var
     fState : TImageState;
     fLoadTask : ITask;
     FFileName : String;
     procedure RunLoadPicture;
   protected
    procedure Paint; override;
   public
    destructor Destroy; override;
  end;

  TImageFilesGrid = class(TImageGrid)
   protected
    function DefaultImageClass : TGridImageClass; override;
   public
    procedure Add(const AImageName : string);
  end;

implementation
uses
System.SysUtils,
System.Math,
Vcl.Imaging.jpeg,
Vcl.Imaging.pngimage,
Vcl.Imaging.GIFImg;

{ TImageGrid }

constructor TImageGrid.Create(AOwner: TComponent);
begin
  inherited;
  fImages := TImages.Create(self);
  Self.AutoScroll := True;
  self.VertScrollBar.Tracking := true;
  self.HorzScrollBar.Tracking := true;
  fMode := smVertical;
  fFixedRows := 3;
  fFixedCols := 3;
  fMaxRows := 0;
  fMaxCols := 5;
  Self.Color := clWindow;
  fPictureSize := TPictireSize.Create(150, 150);
  fPictureStretchPriority := spCount;
  fEditing := False;
end;

destructor TImageGrid.Destroy;
begin
  fEditing := true;
  FreeAndNil(fImages);
  inherited;
end;

function TImageGrid.Add(const AClass: TGridImageClass): TGridImage;
begin
  if not assigned(AClass) then
    result := FImages.AddImage(DefaultImageClass)
  else
    result := FImages.AddImage(AClass);
end;

procedure TImageGrid.BeginUpdate;
begin
  fEditing := True;
end;

function TImageGrid.ImagesCount: Integer;
begin
  result := fImages.Count;
end;

procedure TImageGrid.Resizing(State: TWindowState);
begin
  inherited;
  UpdatePictures;
end;

function TImageGrid.DefaultImageClass: TGridImageClass;
begin
  result := TGridImage;
end;

procedure TImageGrid.Delete(AIndex: Integer);
begin
  System.TMonitor.Enter(fImages);
  try
    fImages[AIndex].DisposeOf;
  finally
    System.TMonitor.Exit(fImages);
  end;
end;

procedure TImageGrid.Clear;
begin
  System.TMonitor.Enter(fImages);
  try
    while fImages.Count > 0 do
      fImages[fImages.Count - 1].DisposeOf;
  finally
    System.TMonitor.Exit(fImages);
  end;
end;

procedure TImageGrid.EndUpdate;
begin
  if fEditing then
  begin
    fEditing := false;
    UpdatePictures;
  end;
end;

procedure TImageGrid.SetFixedCols(const Value: integer);
begin
  fFixedCols := Value;
  if not fEditing then
    UpdatePictures;
end;

procedure TImageGrid.SetFixedRows(const Value: integer);
begin
  FFixedRows := Value;
  if not fEditing then
    UpdatePictures;
end;

procedure TImageGrid.SetMaxCols(const Value: integer);
begin
  if Value = fMaxCols then
    Exit;
  if (Value = 1) then
  begin
    if ((fMaxRows = 0) or (FMaxRows > 1)) then
      SetMode(smHorizontal)
    else
      Exit;
  end;
  fMaxCols := Value;
  if not fEditing then
    UpdatePictures;
end;

procedure TImageGrid.SetMaxRows(const Value: integer);
begin
  if Value = fMaxRows then
    Exit;
  if (Value = 1) then
  begin
    if ((fMaxCols = 0) or (fMaxCols > 1)) then
      SetMode(smVertical)
    else
      Exit;
  end;
  fMaxRows := Value;
  if not fEditing then
    UpdatePictures;
end;

procedure TImageGrid.SetPictureSize(const Value: TPictireSize);
begin
  fPictureSize := Value;
  if not fEditing then
    UpdatePictures;
end;

procedure TImageGrid.SetMode(const Value: TStretchMode);
begin
  if fMode = Value then
    Exit;
  fMode := Value;
  case fMode of
    smVertical:
    begin
      fMaxRows := 0;
      HorzScrollBar.Visible := false;
    end;
    smHorizontal:
    begin
      fMaxCols := 0;
      VertScrollBar.Visible := false;
    end;
  end;
  if not fEditing then
    UpdatePictures;
end;

procedure TImageGrid.SetPictureStretchPriority(const Value: TStretchPriority);
begin
  fPictureStretchPriority := Value;
  if not fEditing then
    UpdatePictures;
end;

procedure TImageGrid.UpdatePictures;
var
  i, vOffset : Integer;
  vPictureSize : TPictireSize;
  vPictureCoord : TPicturePoint;
  vImg : TGridImage;
begin
  if fEditing then
    Exit;

  case fMode of
    smVertical: VertScrollBar.Visible := false;
    smHorizontal: HorzScrollBar.Visible := false;
  end;
  if fImages.Count < 1 then
    Exit;

  case fPictureStretchPriority of
    spSize:
    begin
      case fMode of
        smVertical:
        begin
          vPictureSize := TPictireSize.Create(Max(self.Width div fFixedCols, self.PictureSize.Width), self.PictureSize.Height);
        end;
        smHorizontal:
        begin
          vPictureSize := TPictireSize.Create(self.PictureSize.Width, Max(self.Height div fFixedRows, self.PictureSize.Width));
        end;
      end;
    end;
    spCount:
      vPictureSize := PictureSize;
  end;

  i := 0;
  while i < fImages.Count do
  begin
    fImages[i].Height := vPictureSize.Height;
    fImages[i].Width := vPictureSize.Width;
    Inc(i);
  end;
  vOffset := 20;
  i := 0;
  vPictureCoord := TPicturePoint.Create(vOffset, vOffset);
  while i < fImages.Count do
  begin
    vImg := fImages[i];
    vImg.Top := vPictureCoord.Y;
    vImg.Left := vPictureCoord.X;
    case fMode of
      smVertical:
      begin
        if (vImg.Left + vImg.Width + vOffset + vPictureSize.Width > self.Width) then
        begin
          vPictureCoord.X := vOffset;
          vPictureCoord.Y := vPictureCoord.Y + vPictureSize.Height + vOffset;
        end else
          vPictureCoord.X := vImg.Left + vImg.Width + vOffset;
      end;
      smHorizontal:
      begin
        if (vImg.Top + vImg.Height + vOffset + vPictureSize.Height > self.Height) then
        begin
          vPictureCoord.Y := vOffset;
          vPictureCoord.X := vPictureCoord.X + vPictureSize.Width + vOffset;
        end else
           vPictureCoord.Y := vImg.Top + vImg.Height + vOffset;
      end;
    end;
    Inc(i);
  end;
  case fMode of
    smVertical: VertScrollBar.Visible := true;
    smHorizontal: HorzScrollBar.Visible := true;
  end;
end;

procedure TImageGrid.WMMouseWheel(var Message: TWMMouseWheel);
begin
  case fMode of
    smVertical: VertScrollBar.Position :=  VertScrollBar.Position - Message.WheelDelta;
    smHorizontal: HorzScrollBar.Position :=  HorzScrollBar.Position - Message.WheelDelta;
  end;
end;

{ TImageGrid.TImageList }

function TImages.AddImage(AClass: TGridImageClass): TGridImage;
begin
  result := AClass.Create(FGrid);
  result.fList := Self;
  Add(result);
end;

constructor TImages.Create(AGrid: TImageGrid);
begin
  FGrid := AGrid;
  inherited Create;
end;

procedure TImages.Notify(const Value: TGridImage; Action: TCollectionNotification);
begin
  inherited;
  if not FGrid.FEditing then
    FGrid.UpdatePictures;
end;

{ TGridImage }

constructor TGridImage.Create(AOwner: TImageGrid);
begin
  inherited Create(AOwner);
  Center := True;
  Stretch := True;
  Proportional := True;
  Height := AOwner.fPictureSize.Height;
  Width := AOwner.fPictureSize.Width;
  Parent := AOwner;
  Visible := true;
end;

destructor TGridImage.Destroy;
var
 i : Integer;
begin
  i := fList.IndexOf(self);
  if i <> -1 then
    fList.Delete(i);
  inherited;
end;



{ TImageFilesGrid }

procedure TImageFilesGrid.Add(const AImageName: string);
var
 vImage : TGridFileImage;
begin
  vImage := inherited Add as TGridFileImage;
  vImage.FFileName := AImageName;
  vImage.fState := isNotLoaded;
end;

function TImageFilesGrid.DefaultImageClass: TGridImageClass;
begin
  result := TGridFileImage;
end;

{ TGridFileImage }

destructor TGridFileImage.Destroy;
begin
  if Assigned(fLoadTask) then
    fLoadTask.Cancel;
  fLoadTask := nil;
  inherited;
end;

procedure TGridFileImage.Paint;
begin
  case fState of
    isNotLoaded:
    begin
      if not assigned(fLoadTask) then
        RunLoadPicture;
    end;
    isPainted:
    begin
      inherited Paint;
    end;
  end;
end;

procedure TGridFileImage.RunLoadPicture;
begin
  fLoadTask := TTask.Run(
  procedure
  var
    vBitmap : TGraphic;
    vFirstBytes: AnsiString;
    vFileType : (ftUnkown, ftBM, ftPNG, ftGIF, ftJPG);
    vFS: TFileStream;
  begin
    {$IFDEF DEBUG}
    OutputDebugString(PChar(Format('Load started. thread: %d', [GetCurrentThreadId])));
    {$ENDIF}
    vFS := TFileStream.Create(FFileName, fmOpenRead);
    vFileType := ftUnkown;
    try
      Sleep(10);
      if TTask.CurrentTask.Status = TTaskStatus.Canceled then
        Exit;

      SetLength(vFirstBytes, 8);
      vFS.Read(vFirstBytes[1], 8);
      if Copy(vFirstBytes, 1, 2) = 'BM' then
      begin
        try
          vBitmap := Vcl.Graphics.TBitmap.Create;
          vFS.Seek(0, soFromBeginning);
          vBitmap.LoadFromStream(vFS);
          vFileType := ftBM;
        except
          fState := isError;
          Exit;
        end;
      end else
      if vFirstBytes = #137'PNG'#13#10#26#10 then
      begin
        try
          vBitmap := TPngImage.Create;
          vFS.Seek(0, soFromBeginning);
          vBitmap.LoadFromStream(vFS);
          vFileType := ftPNG;
        except
          fState := isError;
          Exit;
        end;
      end else
      if Copy(vFirstBytes, 1, 3) =  'GIF' then
      begin
        try
          vBitmap := TGIFImage.Create;
          vFS.Seek(0, soFromBeginning);
          vBitmap.LoadFromStream(vFS);
          vFileType := ftGIF;
        except
          fState := isError;
          Exit;
        end;
      end else
      if Copy(vFirstBytes, 1, 2) = #$FF#$D8 then
      begin
        try
          vBitmap := TJPEGImage.Create;
          TJPEGImage(vBitmap).Performance := jpBestSpeed;
          TJPEGImage(vBitmap).Scale := jsEighth;
          TJPEGImage(vBitmap).DIBNeeded;
          vFS.Seek(0, soFromBeginning);
          vBitmap.LoadFromStream(vFS);
          vFileType := ftJPG;
        except
          fState := isError;
          Exit;
        end;
      end;

      Sleep(5);
      if TTask.CurrentTask.Status = TTaskStatus.Canceled then
        Exit;

      if vFileType <> ftUnkown then
      begin
        fState := isPainted;
        TThread.Synchronize(nil,
        procedure
        begin
          Picture.Bitmap.Assign(vBitmap);
          Stretch := (Height * Width) > (vBitmap.Height * vBitmap.Width);
          Paint;
        end);
      end else
        fState := isError;
    finally
      vFS.Free;
      FreeAndNil(vBitmap);
      fLoadTask := nil;
      {$IFDEF DEBUG}
      OutputDebugString(PChar(Format('Load finished. thread: %d', [GetCurrentThreadId])));
      {$ENDIF}
    end;
  end
  );
end;

end.
