unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Buttons, Process;

type

  { TForm1 }

  TForm1 = class(TForm)
    MineCountEdit: TEdit;
    Label2: TLabel;
    StartButton: TButton;
    SizeXEdit: TEdit;
    SizeYEdit: TEdit;
    Label1: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure StartButtonClick(Sender: TObject);
    procedure OnMineMouseDown(Sender: TObject; MouseButton: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure OnRestartButtonClick(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation

type MineButton = record
  Button: TSpeedButton;
  Position: TPoint;
  State: Integer;
  RevealedState: Integer; // 0 - not revealed, 1 - revealed, 2 - marked
end;

var MineButtons: Array of ^MineButton;
  MinefieldSize: TPoint;
  MinePicture, FlagPicture: TBitMap;
  Exploded, Won: Boolean;
  TotalMineCount: Integer;
  RestartButton: TButton;

const ButtonSize = 15;

{$R *.lfm}

{ TForm1 }

function RandInt(Min, Max: Integer): Integer;
begin
  Result := Random(Max - Min + 1) + Min;
end;

type PositionArray = specialize TArray<TPoint>;
function PositionArrayContains(arr: PositionArray; o: TPoint): Boolean;
var i: Integer;
begin
  for i := 0 to (length(arr) - 1) do
  begin
    if arr[i] = o then
      Exit(true);
  end;
  Result := false;
end;

function GenerateUniqueMinePositions(Count: Integer): specialize TArray<TPoint>;
var i, x, y: Integer;
begin
  SetLength(Result, Count);
  for i := 0 to (Count - 1) do
  begin
    Result[i] := TPoint.Create(-1, -1);
  end;

  for i := 0 to (Count - 1) do
  begin
    x := RandInt(0, MinefieldSize.x - 1);
    y := RandInt(0, MinefieldSize.y - 1);

    while PositionArrayContains(Result, TPoint.Create(x, y)) do
    begin
      x := RandInt(0, MinefieldSize.x - 1);
      y := RandInt(0, MinefieldSize.y - 1);
    end;

    Result[i] := TPoint.Create(x, y);
  end;
end;

procedure Mark(Position: TPoint);
var State, Square: ^MineButton;
  i, CorrectlyMarkedMines: Integer;
  WinLabel: TLabel;
begin
  State := MineButtons[(Position.x * MinefieldSize.x) + Position.y];
  if State^.RevealedState = 2 then
  begin
    State^.RevealedState := 0;
    State^.Button.Glyph := nil;
    Exit;
  end
  else if State^.RevealedState <> 0 then
    Exit;

  State^.Button.Glyph := FlagPicture;
  State^.RevealedState := 2;

  Form1.Update;

  CorrectlyMarkedMines := 0;
  for i := 0 to length(MineButtons) - 1 do
  begin
    Square := MineButtons[i];
    if Square^.State <> -1 then
      continue;

    if Square^.RevealedState = 2 then
       CorrectlyMarkedMines += 1;
  end;

  if CorrectlyMarkedMines = TotalMineCount then
  begin
     WinLabel := TLabel.Create(Form1);
     WinLabel.Top := 0;
     WinLabel.Left := 0;
     WinLabel.Parent := Form1;
     WinLabel.AutoSize := true;
     WinLabel.Caption := 'You win!';
     WinLabel.Visible := true;
     WinLabel.Font.Color := ClGreen;
     WinLabel.Transparent := false;

     RestartButton.Visible := true;
     RestartButton.BringToFront;

     Won := true;
  end;

end;

procedure Reveal(Position: TPoint);
var i, j, x, y: Integer;
  State: ^MineButton;
  Button: TSpeedButton;
begin
  Form1.Update;
  State := MineButtons[(Position.x * MinefieldSize.x) + Position.y];
  Button := State^.Button;
  State^.RevealedState := 1;

  Button.Glyph := nil;

  if State^.State = -1 then
  begin
    Button.Glyph := MinePicture;
    Exploded := true;
    RestartButton.Visible := true;
    RestartButton.BringToFront;
    Form1.Caption := 'BOOM! You lost!';
    Exit;
  end;

  if State^.State <> 0 then
  begin
    Button.Caption := IntToStr(State^.State);
    Button.Font.Style := [fsBold];
    Exit;
  end;

  Button.Visible := false;

  x := Position.x;
  y := Position.y;
  for i := -1 to 1 do
  begin
    for j := -1 to 1 do
    begin
      if (i = 0) and (j = 0) then
         continue;

      if ((x + i) < 0) or ((x + i) >= MinefieldSize.x) or ((y + j) < 0) or ((y + j) >= MinefieldSize.y) then
         continue;

      if MineButtons[((x + i) * MinefieldSize.x) + y + j]^.RevealedState <> 1 then
         Reveal(TPoint.Create(x + i, y + j));
    end;
  end;
end;

procedure TForm1.OnRestartButtonClick(Sender: TObject);
var Process: TProcess;
begin
  Process := TProcess.Create(nil);
  Process.Executable := Application.ExeName;
  Process.Execute;
  Application.Terminate;
end;

procedure TForm1.OnMineMouseDown(Sender: TObject; MouseButton: TMouseButton; Shift: TShiftState; x, y: Integer);
var Button: TSpeedButton;
  State: ^MineButton;
begin
  if Exploded or Won then Exit;
  if not (Sender is TSpeedButton) then Exit;

  Button := TSpeedButton(Sender);
  State := MineButtons[Button.Tag];

  if MouseButton = mbLeft then
    Reveal(TPoint(State^.Position))
  else if MouseButton = mbRight then
    Mark(TPoint(State^.Position));
end;

procedure TForm1.StartButtonClick(Sender: TObject);
var SizeX, SizeY,
  x, y,
  j, k,
  ButtonIndex,
  MineCount: Integer;

  Mines: specialize TArray<TPoint>;
  Button: TSpeedButton;
  ButtonState: ^MineButton;
begin
  SizeX := StrToIntDef(Form1.SizeXEdit.Text, 50);
  SizeY := StrToIntDef(Form1.SizeYEdit.Text, 50);
  TotalMineCount := StrToIntDef(MineCountEdit.Text, 20);

  SizeXEdit.Visible := false;
  SizeYEdit.Visible := false;
  MineCountEdit.Visible := false;

  StartButton.Visible := false;
  Label1.Visible := false;
  Label2.Visible := false;

  MinefieldSize := TPoint.Create(SizeX, SizeY);
  SetLength(MineButtons, SizeX * SizeY);

  Mines := GenerateUniqueMinePositions(TotalMineCount);

  ButtonIndex := 0;

  Form1.Width := ButtonSize * SizeX;
  Form1.Height := ButtonSize * SizeY;

  RestartButton.Top := (Form1.Height div 2) - 25;
  RestartButton.Left := (Form1.Width div 2) - 75;

  for x := 0 to (SizeX - 1) do
  begin
    for y := 0 to (SizeY - 1) do
    begin
      Button := TSpeedButton.Create(self);
      Button.Width := ButtonSize;
      Button.Height := ButtonSize;
      Button.Visible := true;
      Button.Top := x * ButtonSize;
      Button.Left := y * ButtonSize;
      Button.Parent := Form1;

      new(ButtonState);
      ButtonState^.Position := TPoint.Create(x, y);
      ButtonState^.Button := Button;
      ButtonState^.RevealedState := 0;


      Button.Tag := Int64(buttonIndex);
      Button.OnMouseDown := @OnMineMouseDown;
      MineButtons[buttonIndex] := ButtonState;
      ButtonIndex += 1;

      if PositionArrayContains(Mines, TPoint.Create(x, y)) then
      begin
         ButtonState^.State := -1
      end
      else
      begin
        MineCount := 0;
        for j := -1 to 1 do
        begin
          for k := -1 to 1 do
          begin
            if (j = 0) and (k = 0) then
              continue;
            if PositionArrayContains(Mines, TPoint.Create(x + j, y + k)) then
              MineCount += 1;
          end;
        end;
        ButtonState^.State := MineCount;
      end;
    end;
  end;

end;

procedure TForm1.FormCreate(Sender: TObject);
var MPicture, FPicture: TPicture;
begin
  Randomize;

  MPicture := TPicture.Create;
  MPicture.LoadFromFile('mine.jpg');
  MinePicture := MPicture.Bitmap;

  FPicture := TPicture.Create;
  FPicture.LoadFromFile('flag.jpg');
  FlagPicture := FPicture.Bitmap;

  Exploded := false;

  RestartButton := TButton.Create(self);
  RestartButton.Parent := Form1;
  RestartButton.Caption := 'Restart';
  RestartButton.Visible := false;
  RestartButton.OnClick := @Form1.OnRestartButtonClick;
end;

end.

