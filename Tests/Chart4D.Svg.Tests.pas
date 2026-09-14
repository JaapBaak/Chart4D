{*******************************************************}
{                                                       }
{       Chart4D Library - Editorial data charts         }
{                                                       }
{          Copyright(c) 2026 GDK Software               }
{                All rights reserved                    }
{                                                       }
{             Licensed under MIT License                }
{                                                       }
{*******************************************************}
unit Chart4D.Svg.Tests;

/// <summary>
/// Tests for <c>TSvgChartCanvas</c>, which writes every <c>IChartCanvas</c> call as an SVG
/// element, and for <c>TChartSvg.Render</c>, which renders a whole plot through it. Text is
/// measured by a <c>TRecordingCanvas</c>, whose fixed metrics make baseline positions exact.
/// </summary>

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Chart4D.Canvas.Interfaces,
  Chart4D.Svg;

type
  [TestFixture]
  TSvgChartCanvasTests = class
  private
    FSvgCanvas: TSvgChartCanvas;
    FCanvas: IChartCanvas;

    function Markup: string;
    class function CountOccurrences(const Text, Fragment: string): Integer; static;
    class function ArialStyle(const Bold: Boolean): TChartTextStyle; static;
    class function WriteTempFile(const Bytes: TBytes): string; static;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure ToSvg_EmptyCanvas_WritesRootWithSizeAndViewBox;

    [Test]
    procedure ToSvg_Title_WritesEscapedTitleElement;

    [Test]
    procedure FillBackground_CoversDocumentFromViewBoxOrigin;

    [Test]
    procedure FillRect_OpaqueColor_WritesHexFillWithoutOpacity;

    [Test]
    procedure FillRect_TranslucentColor_WritesFillOpacity;

    [Test]
    procedure FillRect_ReversedBounds_WritesNormalizedRect;

    [Test]
    procedure DrawLine_Dashed_WritesDashArrayScaledByStrokeWidth;

    [Test]
    procedure DrawLine_Solid_WritesNoDashArray;

    [Test]
    procedure DrawPolyline_SinglePoint_WritesNothing;

    [Test]
    procedure DrawPolyline_Points_WritesUnfilledPolyline;

    [Test]
    procedure FillPolygon_Points_WritesEvenOddPolygon;

    [Test]
    procedure FillCircle_ZeroRadius_WritesNothing;

    [Test]
    procedure Coordinates_CommaDecimalSeparatorLocale_UseInvariantPoint;

    [Test]
    procedure DrawText_LeftTop_PlacesBaselineInsideLineBox;

    [Test]
    procedure DrawText_RightAligned_AnchorsAtXWithTextAnchorEnd;

    [Test]
    procedure DrawText_CenterMiddle_CentersLineBoxOnAnchor;

    [Test]
    procedure DrawText_Bold_WritesFontWeightBold;

    [Test]
    procedure DrawText_Regular_WritesNoFontWeight;

    [Test]
    procedure DrawText_Arial_FallsBackToHelveticaThenSansSerif;

    [Test]
    procedure DrawText_MarkupCharacters_AreEscaped;

    [Test]
    procedure DrawText_ControlCharacters_AreDropped;

    [Test]
    procedure DrawText_EmptyText_WritesNothing;

    [Test]
    procedure MeasureText_DelegatesToTextMeasurer;

    [Test]
    procedure DrawImage_PngFile_EmbedsDataUriAlignedRight;

    [Test]
    procedure DrawImage_UnrecognizedFormat_WritesNothing;

    [Test]
    procedure DrawImage_MissingFile_WritesNothing;

    [Test]
    procedure Create_NilTextMeasurer_RaisesException;

    [Test]
    procedure Render_PlotWithoutSeries_RaisesException;

    [Test]
    procedure Render_LineChart_WritesTitleAndOnePolylinePerSeries;

    [Test]
    procedure Render_AnnotatedAreaChart_WritesOneElementPerCanvasCall;
  end;

implementation

uses
  System.IOUtils,
  System.Types,
  System.UITypes,
  Chart4D.Plot,
  Chart4D.Renderer,
  Chart4D.Style,
  Chart4D.Tests.RecordingCanvas,
  Chart4D.Types;

const
  TranslucentDarkRed = TAlphaColor($30990000);

procedure TSvgChartCanvasTests.Setup;
begin
  const TextMeasurer: IChartCanvas = TRecordingCanvas.Create;
  FSvgCanvas := TSvgChartCanvas.Create(640, 450, TextMeasurer);
  FCanvas := FSvgCanvas;
end;

procedure TSvgChartCanvasTests.TearDown;
begin
  FCanvas := nil;
  FSvgCanvas := nil;
end;

function TSvgChartCanvasTests.Markup: string;
begin
  Result := FSvgCanvas.ToSvg;
end;

class function TSvgChartCanvasTests.CountOccurrences(const Text, Fragment: string): Integer;
begin
  Result := 0;

  var Position := Text.IndexOf(Fragment);
  while Position >= 0 do
  begin
    Inc(Result);
    Position := Text.IndexOf(Fragment, Position + Fragment.Length);
  end;
end;

class function TSvgChartCanvasTests.ArialStyle(const Bold: Boolean): TChartTextStyle;
begin
  Result := TChartTextStyle.Create('Arial', 20, Bold, ChartTextDark);
end;

class function TSvgChartCanvasTests.WriteTempFile(const Bytes: TBytes): string;
begin
  Result := TPath.GetTempFileName;
  TFile.WriteAllBytes(Result, Bytes);
end;

procedure TSvgChartCanvasTests.ToSvg_EmptyCanvas_WritesRootWithSizeAndViewBox;
begin
  const Svg = Markup;

  Assert.IsTrue(Svg.StartsWith('<svg xmlns="http://www.w3.org/2000/svg" width="640" height="450" ' +
                               'viewBox="-0.5 -0.5 640 450"'), Svg);
  Assert.IsTrue(Svg.TrimRight.EndsWith('</svg>'), Svg);
  Assert.DoesNotContain(Svg, '<?xml');
  Assert.DoesNotContain(Svg, '<title>');
end;

procedure TSvgChartCanvasTests.ToSvg_Title_WritesEscapedTitleElement;
begin
  FSvgCanvas.Title := 'Rich & poor';

  Assert.Contains(Markup, '<title>Rich &amp; poor</title>', False);
end;

procedure TSvgChartCanvasTests.FillBackground_CoversDocumentFromViewBoxOrigin;
begin
  FCanvas.FillBackground(640, 450, TAlphaColor($FFFFFFFF));

  Assert.Contains(Markup, '<rect x="-0.5" y="-0.5" width="640" height="450" fill="#FFFFFF"/>', False);
end;

procedure TSvgChartCanvasTests.FillRect_OpaqueColor_WritesHexFillWithoutOpacity;
begin
  FCanvas.FillRect(TRectF.Create(10, 20, 110, 70), ChartBlue);

  Assert.Contains(Markup, '<rect x="10" y="20" width="100" height="50" fill="#1380A1"/>', False);
  Assert.DoesNotContain(Markup, 'opacity');
end;

procedure TSvgChartCanvasTests.FillRect_TranslucentColor_WritesFillOpacity;
begin
  FCanvas.FillRect(TRectF.Create(0, 0, 10, 10), TranslucentDarkRed);

  Assert.Contains(Markup, 'fill="#990000" fill-opacity="0.188"', False);
end;

procedure TSvgChartCanvasTests.FillRect_ReversedBounds_WritesNormalizedRect;
begin
  FCanvas.FillRect(TRectF.Create(110, 70, 10, 20), ChartBlue);

  Assert.Contains(Markup, '<rect x="10" y="20" width="100" height="50"', False);
end;

procedure TSvgChartCanvasTests.DrawLine_Dashed_WritesDashArrayScaledByStrokeWidth;
begin
  FCanvas.DrawLine(0, 10, 100, 10, ChartTextDark, 2, True);

  Assert.Contains(Markup, '<line x1="0" y1="10" x2="100" y2="10" stroke="#222222" stroke-width="2" ' +
                          'stroke-dasharray="6 2"/>', False);
end;

procedure TSvgChartCanvasTests.DrawLine_Solid_WritesNoDashArray;
begin
  FCanvas.DrawLine(0, 10, 100, 10, ChartTextDark, 1, False);

  Assert.DoesNotContain(Markup, 'stroke-dasharray');
end;

procedure TSvgChartCanvasTests.DrawPolyline_SinglePoint_WritesNothing;
begin
  FCanvas.DrawPolyline([TPointF.Create(5, 5)], ChartBlue, 3);

  Assert.DoesNotContain(Markup, '<polyline');
end;

procedure TSvgChartCanvasTests.DrawPolyline_Points_WritesUnfilledPolyline;
begin
  FCanvas.DrawPolyline([TPointF.Create(0, 0), TPointF.Create(10, 5.5), TPointF.Create(20, 3)], ChartBlue, 3);

  Assert.Contains(Markup, '<polyline points="0,0 10,5.5 20,3" fill="none" stroke="#1380A1" stroke-width="3"', False);
end;

procedure TSvgChartCanvasTests.FillPolygon_Points_WritesEvenOddPolygon;
begin
  FCanvas.FillPolygon([TPointF.Create(0, 0), TPointF.Create(10, 0), TPointF.Create(5, 8)], ChartOrange);

  Assert.Contains(Markup, '<polygon points="0,0 10,0 5,8" fill="#FAAB18" fill-rule="evenodd"/>', False);
end;

procedure TSvgChartCanvasTests.FillCircle_ZeroRadius_WritesNothing;
begin
  FCanvas.FillCircle(10, 10, 0, ChartBlue);

  Assert.DoesNotContain(Markup, '<circle');
end;

procedure TSvgChartCanvasTests.Coordinates_CommaDecimalSeparatorLocale_UseInvariantPoint;
begin
  const SavedSeparator = FormatSettings.DecimalSeparator;
  FormatSettings.DecimalSeparator := ',';
  try
    FCanvas.FillCircle(1.5, 2.25, 3, ChartBlue);
  finally
    FormatSettings.DecimalSeparator := SavedSeparator;
  end;

  Assert.Contains(Markup, '<circle cx="1.5" cy="2.25" r="3" fill="#1380A1"/>', False);
end;

procedure TSvgChartCanvasTests.DrawText_LeftTop_PlacesBaselineInsideLineBox;
begin
  { The recording canvas measures a 20 px font as 24 px high, so the baseline lands
    0.78 * 24 = 18.72 px below the top anchor. }
  FCanvas.DrawText(16, 16, 'Title', ArialStyle(False), TTextAlignH.Left, TTextAlignV.Top);

  Assert.Contains(Markup, '<text x="16" y="34.72" text-anchor="start"', False);
end;

procedure TSvgChartCanvasTests.DrawText_RightAligned_AnchorsAtXWithTextAnchorEnd;
begin
  FCanvas.DrawText(600, 16, 'Label', ArialStyle(False), TTextAlignH.Right, TTextAlignV.Top);

  Assert.Contains(Markup, '<text x="600" y="34.72" text-anchor="end"', False);
end;

procedure TSvgChartCanvasTests.DrawText_CenterMiddle_CentersLineBoxOnAnchor;
begin
  FCanvas.DrawText(320, 100, 'Label', ArialStyle(False), TTextAlignH.Center, TTextAlignV.Middle);

  Assert.Contains(Markup, '<text x="320" y="106.72" text-anchor="middle"', False);
end;

procedure TSvgChartCanvasTests.DrawText_Bold_WritesFontWeightBold;
begin
  FCanvas.DrawText(0, 0, 'Title', ArialStyle(True), TTextAlignH.Left, TTextAlignV.Top);

  Assert.Contains(Markup, 'font-size="20" font-weight="bold" fill="#222222">Title</text>', False);
end;

procedure TSvgChartCanvasTests.DrawText_Regular_WritesNoFontWeight;
begin
  FCanvas.DrawText(0, 0, 'Label', ArialStyle(False), TTextAlignH.Left, TTextAlignV.Top);

  Assert.DoesNotContain(Markup, 'font-weight');
end;

procedure TSvgChartCanvasTests.DrawText_Arial_FallsBackToHelveticaThenSansSerif;
begin
  FCanvas.DrawText(0, 0, 'Label', ArialStyle(False), TTextAlignH.Left, TTextAlignV.Top);

  Assert.Contains(Markup, 'font-family="''Arial'', Helvetica, sans-serif"', False);
end;

procedure TSvgChartCanvasTests.DrawText_MarkupCharacters_AreEscaped;
begin
  FCanvas.DrawText(0, 0, 'A & B <C> "D"', ArialStyle(False), TTextAlignH.Left, TTextAlignV.Top);

  Assert.Contains(Markup, '>A &amp; B &lt;C&gt; &quot;D&quot;</text>', False);
end;

procedure TSvgChartCanvasTests.DrawText_ControlCharacters_AreDropped;
begin
  FCanvas.DrawText(0, 0, 'A'#1'B'#27'C', ArialStyle(False), TTextAlignH.Left, TTextAlignV.Top);

  Assert.Contains(Markup, '>ABC</text>', False);
end;

procedure TSvgChartCanvasTests.DrawText_EmptyText_WritesNothing;
begin
  FCanvas.DrawText(0, 0, '', ArialStyle(False), TTextAlignH.Left, TTextAlignV.Top);

  Assert.DoesNotContain(Markup, '<text');
end;

procedure TSvgChartCanvasTests.MeasureText_DelegatesToTextMeasurer;
begin
  const Size = FCanvas.MeasureText('Label', ArialStyle(False));

  Assert.AreEqual(Double(5 * 20 * 0.6), Double(Size.Width), 0.001);
  Assert.AreEqual(Double(20 * 1.2), Double(Size.Height), 0.001);
end;

procedure TSvgChartCanvasTests.DrawImage_PngFile_EmbedsDataUriAlignedRight;
begin
  const PngSignature: TBytes = [$89, $50, $4E, $47, $0D, $0A, $1A, $0A, 0, 0, 0, 13];
  const FilePath = WriteTempFile(PngSignature);
  try
    FCanvas.DrawImage(FilePath, TRectF.Create(500, 420, 624, 440));
  finally
    TFile.Delete(FilePath);
  end;

  Assert.Contains(Markup, '<image x="500" y="420" width="124" height="20" preserveAspectRatio="xMaxYMid meet" ' +
                          'href="data:image/png;base64,iVBORw0KGgoAAAAN"/>', False);
end;

procedure TSvgChartCanvasTests.DrawImage_UnrecognizedFormat_WritesNothing;
begin
  const FilePath = WriteTempFile(TEncoding.ASCII.GetBytes('not an image'));
  try
    FCanvas.DrawImage(FilePath, TRectF.Create(500, 420, 624, 440));
  finally
    TFile.Delete(FilePath);
  end;

  Assert.DoesNotContain(Markup, '<image');
end;

procedure TSvgChartCanvasTests.DrawImage_MissingFile_WritesNothing;
begin
  FCanvas.DrawImage(TPath.Combine(TPath.GetTempPath, 'Chart4D-no-such-logo.png'), TRectF.Create(0, 0, 10, 10));

  Assert.DoesNotContain(Markup, '<image');
end;

procedure TSvgChartCanvasTests.Create_NilTextMeasurer_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      const Canvas: IChartCanvas = TSvgChartCanvas.Create(640, 450, nil);
    end,
    EChart4DException);
end;

procedure TSvgChartCanvasTests.Render_PlotWithoutSeries_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    const TextMeasurer: IChartCanvas = TRecordingCanvas.Create;

    Assert.WillRaise(
      procedure
      begin
        TChartSvg.Render(Plot, TextMeasurer, 640, 450);
      end,
      EChart4DException);
  finally
    Plot.Free;
  end;
end;

procedure TSvgChartCanvasTests.Render_LineChart_WritesTitleAndOnePolylinePerSeries;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Title := 'Life expectancy';
    Plot.Categories := ['1960', '1980', '2000', '2020'];
    Plot.AddSeries('Netherlands', [73.4, 75.7, 78.0, 81.4]);
    Plot.AddSeries('Belgium', [69.7, 73.2, 77.7, 80.7]);

    const TextMeasurer: IChartCanvas = TRecordingCanvas.Create;
    const Svg = TChartSvg.Render(Plot, TextMeasurer, 640, 450);

    Assert.AreEqual(2, CountOccurrences(Svg, '<polyline '));
    Assert.Contains(Svg, '<title>Life expectancy</title>', False);
    Assert.Contains(Svg, '>Life expectancy</text>', False);
  finally
    Plot.Free;
  end;
end;

procedure TSvgChartCanvasTests.Render_AnnotatedAreaChart_WritesOneElementPerCanvasCall;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Area;
    Plot.Title := 'Electricity from renewables';
    Plot.Source := 'Source: Ember';
    Plot.Categories := ['2000', '2005', '2010', '2015', '2020'];
    Plot.AddSeries('Wind', [1, 3, 6, 11, 17]);
    Plot.AddSeries('Solar', [0, 0, 1, 3, 8]);
    Plot.AddHorizontalLine(10, ChartDarkRed, True);
    Plot.AddHorizontalRangeOverlay(12, 16, TranslucentDarkRed);
    Plot.AddTextAnnotation(3, 12, 'Target', ChartDarkRed);
    Plot.AddArrow(1, 8, 2, 6);

    const Recording = TRecordingCanvas.Create;
    const RecordingCanvas: IChartCanvas = Recording;
    TChartRenderer.Render(Plot, RecordingCanvas, 640, 450);

    const TextMeasurer: IChartCanvas = TRecordingCanvas.Create;
    const Svg = TChartSvg.Render(Plot, TextMeasurer, 640, 450);

    Assert.AreEqual(Recording.CountOfKind(TCanvasCallKind.FillBackground) + Recording.CountOfKind(TCanvasCallKind.FillRect),
                    CountOccurrences(Svg, '<rect '), 'rect');
    Assert.AreEqual(Recording.CountOfKind(TCanvasCallKind.DrawLine), CountOccurrences(Svg, '<line '), 'line');
    Assert.AreEqual(Recording.CountOfKind(TCanvasCallKind.DrawPolyline), CountOccurrences(Svg, '<polyline '), 'polyline');
    Assert.AreEqual(Recording.CountOfKind(TCanvasCallKind.FillPolygon), CountOccurrences(Svg, '<polygon '), 'polygon');
    Assert.AreEqual(Recording.CountOfKind(TCanvasCallKind.FillCircle), CountOccurrences(Svg, '<circle '), 'circle');
    Assert.AreEqual(Recording.CountOfKind(TCanvasCallKind.DrawText), CountOccurrences(Svg, '<text '), 'text');
  finally
    Plot.Free;
  end;
end;

end.
