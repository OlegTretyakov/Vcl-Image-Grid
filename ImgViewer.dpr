program ImgViewer;

uses
  Vcl.Forms,
  ImageViewerMainForm in 'imageViewerMainForm.pas' {ImgViewerMainFrm},
  Vcl.ImageGrid in 'Vcl.ImageGrid.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TImgViewerMainFrm, ImgViewerMainFrm);
  Application.Run;
end.
