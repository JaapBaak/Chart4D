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
unit Chart4D.Svg;

/// <summary>
/// SVG export. <c>TSvgChartCanvas</c> implements <c>IChartCanvas</c> by writing SVG markup
/// instead of pixels, and <c>TChartSvg</c> renders a whole plot to an SVG document in one
/// call. RTL-only: measuring text, the one thing markup cannot do by itself, is delegated
/// to a framework canvas supplied by the caller, so the layout matches a PNG export.
/// </summary>

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  Chart4D.Types,
  Chart4D.Canvas.Interfaces,
  Chart4D.Plot;

type
  /// <summary>
  /// An <c>IChartCanvas</c> that records every drawing call as an SVG element. Text is
  /// written as real <c>&lt;text&gt;</c> elements, anchored at the point the renderer asked
  /// for, so a label keeps its alignment even when the viewer substitutes a font of
  /// slightly different width. Text is measured by the <c>TextMeasurer</c> canvas given to
  /// the constructor, which is never drawn on.
  /// </summary>
  TSvgChartCanvas = class(TInterfacedObject, IChartCanvas)
  private const
    /// <summary>
    /// Where the baseline sits within a measured line box, as a fraction of its height.
    /// Arial's ascent is 0.788 of its line height and Helvetica's 0.77; the adapters
    /// measure the full line box, so this places the baseline where GDI+ and FMX draw it
    /// to within a fraction of a pixel for either font.
    /// </summary>
    BaselineFractionOfLineHeight = 0.78;
    /// <summary>
    /// The dash and gap lengths of a dashed stroke, as multiples of the stroke width: the
    /// pattern GDI+ <c>DashStyleDash</c> and FMX <c>TStrokeDash.Dash</c> both draw.
    /// </summary>
    DashLengthFactor = 3;
    DashGapFactor = 1;
    /// <summary>The GDI+ miter limit, so sharp corners of a series line are cut off at the same point.</summary>
    StrokeMiterLimit = 10;

  private
    FWidth: Single;
    FHeight: Single;
    FTextMeasurer: IChartCanvas;
    FTitle: string;
    FBody: TStringBuilder;

    procedure AppendElement(const Markup: string);
    class function FormatNumber(const Value: Single): string; static;
    class function ColorAttributes(const AttributeName: string; const Color: TAlphaColor): string; static;
    class function PointList(const Points: TArray<TPointF>): string; static;
    class function TextAnchor(const AlignH: TTextAlignH): string; static;
    class function FontFamilyList(const FontName: string): string; static;
    class function ImageMimeType(const Bytes: TBytes): string; static;

  public
    /// <summary>
    /// Creates an empty SVG document of <c>Width</c> x <c>Height</c> pixels that measures
    /// text through <c>TextMeasurer</c>.
    /// </summary>
    /// <exception cref="EChart4DException">Raised when <c>TextMeasurer</c> is nil.</exception>
    constructor Create(const Width, Height: Single; const TextMeasurer: IChartCanvas);
    /// <summary>Destroys the canvas and the markup it collected.</summary>
    destructor Destroy; override;

    /// <summary>Writes a rectangle covering the whole document.</summary>
    procedure FillBackground(const Width, Height: Single; const Color: TAlphaColor);
    /// <summary>Writes a <c>&lt;line&gt;</c>, with a dash pattern when <c>Dashed</c>.</summary>
    procedure DrawLine(const X1, Y1, X2, Y2: Single; const Color: TAlphaColor;
                       const StrokeWidth: Single; const Dashed: Boolean);
    /// <summary>Writes an unfilled <c>&lt;polyline&gt;</c>; fewer than two points write nothing.</summary>
    procedure DrawPolyline(const Points: TArray<TPointF>; const Color: TAlphaColor;
                           const StrokeWidth: Single);
    /// <summary>Writes an even-odd filled <c>&lt;polygon&gt;</c>; fewer than three points write nothing.</summary>
    procedure FillPolygon(const Points: TArray<TPointF>; const Color: TAlphaColor);
    /// <summary>Writes a <c>&lt;rect&gt;</c>, normalized so reversed bounds still draw.</summary>
    procedure FillRect(const Bounds: TRectF; const Color: TAlphaColor);
    /// <summary>Writes a <c>&lt;circle&gt;</c>; a radius that is not positive writes nothing.</summary>
    procedure FillCircle(const CenterX, CenterY, Radius: Single; const Color: TAlphaColor);
    /// <summary>
    /// Writes a <c>&lt;text&gt;</c> element at the anchor <c>X</c> with the matching
    /// <c>text-anchor</c>, on the baseline of the line box the alignment describes.
    /// </summary>
    procedure DrawText(const X, Y: Single; const Text: string;
                       const TextStyle: TChartTextStyle;
                       const AlignH: TTextAlignH; const AlignV: TTextAlignV);
    /// <summary>Returns the size <c>TextMeasurer</c> measures for the text.</summary>
    function MeasureText(const Text: string;
                         const TextStyle: TChartTextStyle): TSizeF;
    /// <summary>
    /// Embeds a PNG, JPEG, GIF or BMP file as a data URI, aspect-fit inside
    /// <c>Bounds</c> and right-aligned. A missing file or another format writes nothing.
    /// </summary>
    procedure DrawImage(const FilePath: string; const Bounds: TRectF);

    /// <summary>
    /// Returns the complete SVG document. There is no XML declaration, so the same string
    /// works as a standalone file and pasted inline into an HTML page.
    /// </summary>
    function ToSvg: string;

    /// <summary>The document title, written as its <c>&lt;title&gt;</c> element when not empty.</summary>
    property Title: string read FTitle write FTitle;
  end;

  /// <summary>
  /// Renders a plot to an SVG document in one call, for callers that only need the markup.
  /// </summary>
  TChartSvg = class
  public
    /// <summary>
    /// Renders <c>Plot</c> at <c>Width</c> x <c>Height</c> pixels and returns the SVG
    /// document, titled with the plot's <c>Title</c>. <c>TextMeasurer</c> measures the
    /// text; pass a canvas of the framework the chart is shown in, so the SVG lays out
    /// exactly like the on-screen chart and the PNG export.
    /// </summary>
    /// <exception cref="EChart4DException">
    /// Raised when <c>Plot</c> is nil or has no series, when <c>TextMeasurer</c> is nil,
    /// and for every invalid input <c>TChartRenderer.Render</c> rejects.
    /// </exception>
    class function Render(const Plot: TChartPlot; const TextMeasurer: IChartCanvas;
                          const Width, Height: Single): string; static;
  end;

implementation

uses
  System.IOUtils,
  System.NetEncoding,
  Chart4D.Consts,
  Chart4D.Renderer;

/// <summary>
/// Escapes text for use in SVG content and double-quoted attributes.
/// </summary>
function EscapeXml(const Text: string): string;
begin
  const Builder = TStringBuilder.Create(Length(Text));
  try
    for var Character in Text do
    begin
      case Character of
        '&': Builder.Append('&amp;');
        '<': Builder.Append('&lt;');
        '>': Builder.Append('&gt;');
        '"': Builder.Append('&quot;');
        #9, #10, #13: Builder.Append(Character);
        { XML 1.0 forbids every other control character outright, so a single one in a
          label would make the whole document fail to parse. }
        #0..#8, #11, #12, #14..#31: Continue;
      else
        Builder.Append(Character);
      end;
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

constructor TSvgChartCanvas.Create(const Width, Height: Single; const TextMeasurer: IChartCanvas);
begin
  inherited Create;

  const HasTextMeasurer = Assigned(TextMeasurer);
  if not HasTextMeasurer then
    raise EChart4DException.Create(SSvgTextMeasurerRequired);

  FWidth := Width;
  FHeight := Height;
  FTextMeasurer := TextMeasurer;
  FBody := TStringBuilder.Create;
end;

destructor TSvgChartCanvas.Destroy;
begin
  FBody.Free;
  inherited Destroy;
end;

procedure TSvgChartCanvas.FillBackground(const Width, Height: Single; const Color: TAlphaColor);
begin
  { Starts at the view box origin rather than at 0, so the half-pixel grid alignment in
    ToSvg does not leave an unpainted strip along the top and left edges. }
  FillRect(TRectF.Create(-0.5, -0.5, Width - 0.5, Height - 0.5), Color);
end;

procedure TSvgChartCanvas.DrawLine(const X1, Y1, X2, Y2: Single; const Color: TAlphaColor;
                                   const StrokeWidth: Single; const Dashed: Boolean);
begin
  var DashAttribute := '';
  if Dashed then
    DashAttribute := Format(' stroke-dasharray="%s %s"',
                            [FormatNumber(StrokeWidth * DashLengthFactor), FormatNumber(StrokeWidth * DashGapFactor)]);

  AppendElement(Format('<line x1="%s" y1="%s" x2="%s" y2="%s" %s stroke-width="%s"%s/>',
                       [FormatNumber(X1), FormatNumber(Y1), FormatNumber(X2), FormatNumber(Y2),
                        ColorAttributes('stroke', Color), FormatNumber(StrokeWidth), DashAttribute]));
end;

procedure TSvgChartCanvas.DrawPolyline(const Points: TArray<TPointF>; const Color: TAlphaColor;
                                       const StrokeWidth: Single);
begin
  const HasEnoughPoints = (Length(Points) >= 2);
  if not HasEnoughPoints then
    Exit;

  AppendElement(Format('<polyline points="%s" fill="none" %s stroke-width="%s" stroke-miterlimit="%d"/>',
                       [PointList(Points), ColorAttributes('stroke', Color), FormatNumber(StrokeWidth),
                        StrokeMiterLimit]));
end;

procedure TSvgChartCanvas.FillPolygon(const Points: TArray<TPointF>; const Color: TAlphaColor);
begin
  const HasEnoughPoints = (Length(Points) >= 3);
  if not HasEnoughPoints then
    Exit;

  { GDI+ fills polygons in alternate mode, which is SVG's even-odd rule: a band whose
    low and high edges cross must leave the same gaps in both exports. }
  AppendElement(Format('<polygon points="%s" %s fill-rule="evenodd"/>',
                       [PointList(Points), ColorAttributes('fill', Color)]));
end;

procedure TSvgChartCanvas.FillRect(const Bounds: TRectF; const Color: TAlphaColor);
begin
  const Normalized = TRectF.Create(Bounds.TopLeft, Bounds.BottomRight, True);

  AppendElement(Format('<rect x="%s" y="%s" width="%s" height="%s" %s/>',
                       [FormatNumber(Normalized.Left), FormatNumber(Normalized.Top),
                        FormatNumber(Normalized.Width), FormatNumber(Normalized.Height),
                        ColorAttributes('fill', Color)]));
end;

procedure TSvgChartCanvas.FillCircle(const CenterX, CenterY, Radius: Single; const Color: TAlphaColor);
begin
  const HasPositiveRadius = (Radius > 0);
  if not HasPositiveRadius then
    Exit;

  AppendElement(Format('<circle cx="%s" cy="%s" r="%s" %s/>',
                       [FormatNumber(CenterX), FormatNumber(CenterY), FormatNumber(Radius),
                        ColorAttributes('fill', Color)]));
end;

procedure TSvgChartCanvas.DrawText(const X, Y: Single; const Text: string;
                                   const TextStyle: TChartTextStyle;
                                   const AlignH: TTextAlignH; const AlignV: TTextAlignV);
begin
  const HasText = not Text.IsEmpty;
  if not HasText then
    Exit;

  const Size = FTextMeasurer.MeasureText(Text, TextStyle);
  const Origin = TChartTextAlign.ResolveOrigin(X, Y, Size, AlignH, AlignV);
  const Baseline = Origin.Y + Size.Height * BaselineFractionOfLineHeight;

  var WeightAttribute := '';
  if TextStyle.Bold then
    WeightAttribute := ' font-weight="bold"';

  AppendElement(Format('<text x="%s" y="%s" text-anchor="%s" font-family="%s" font-size="%s"%s %s>%s</text>',
                       [FormatNumber(X), FormatNumber(Baseline), TextAnchor(AlignH),
                        FontFamilyList(TextStyle.FontName), FormatNumber(TextStyle.Size), WeightAttribute,
                        ColorAttributes('fill', TextStyle.Color), EscapeXml(Text)]));
end;

function TSvgChartCanvas.MeasureText(const Text: string;
                                     const TextStyle: TChartTextStyle): TSizeF;
begin
  Result := FTextMeasurer.MeasureText(Text, TextStyle);
end;

procedure TSvgChartCanvas.DrawImage(const FilePath: string; const Bounds: TRectF);
begin
  const HasFile = (not FilePath.IsEmpty) and TFile.Exists(FilePath);
  if not HasFile then
    Exit;

  const Bytes = TFile.ReadAllBytes(FilePath);
  const MimeType = ImageMimeType(Bytes);
  const IsSupportedImage = not MimeType.IsEmpty;
  if not IsSupportedImage then
    Exit;

  { A data URI may not contain the line breaks TNetEncoding.Base64 inserts by default. }
  const Encoding = TBase64Encoding.Create(0);
  try
    const Normalized = TRectF.Create(Bounds.TopLeft, Bounds.BottomRight, True);

    { xMaxYMid meet is TChartImageFit's rule, aspect fit, right-aligned and vertically
      centred, applied by the viewer, so the image's own pixel size is never needed. }
    AppendElement(Format('<image x="%s" y="%s" width="%s" height="%s" preserveAspectRatio="xMaxYMid meet" ' +
                         'href="data:%s;base64,%s"/>',
                         [FormatNumber(Normalized.Left), FormatNumber(Normalized.Top),
                          FormatNumber(Normalized.Width), FormatNumber(Normalized.Height),
                          MimeType, Encoding.EncodeBytesToString(Bytes)]));
  finally
    Encoding.Free;
  end;
end;

function TSvgChartCanvas.ToSvg: string;
begin
  const Document = TStringBuilder.Create;
  try
    { The renderer puts 1 px lines on whole-pixel coordinates, which GDI+ draws crisp
      because its pixel centres lie on whole numbers. SVG's pixel centres lie half a pixel
      further on, so the view box starts at -0.5 to line both grids up. xml:space="preserve"
      keeps runs of spaces inside a label, which SVG would otherwise collapse into one. }
    Document.Append(Format('<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" ' +
                           'viewBox="-0.5 -0.5 %0:s %1:s" xml:space="preserve">',
                           [FormatNumber(FWidth), FormatNumber(FHeight)]));
    Document.Append(sLineBreak);

    const HasTitle = not FTitle.IsEmpty;
    if HasTitle then
    begin
      Document.Append('<title>').Append(EscapeXml(FTitle)).Append('</title>');
      Document.Append(sLineBreak);
    end;

    Document.Append(FBody.ToString);
    Document.Append('</svg>');
    Document.Append(sLineBreak);

    Result := Document.ToString;
  finally
    Document.Free;
  end;
end;

procedure TSvgChartCanvas.AppendElement(const Markup: string);
begin
  FBody.Append(Markup);
  FBody.Append(sLineBreak);
end;

class function TSvgChartCanvas.FormatNumber(const Value: Single): string;
begin
  Result := FormatFloat('0.##', Value, TFormatSettings.Invariant);

  const IsNegativeZero = (Result = '-0');
  if IsNegativeZero then
    Result := '0';
end;

class function TSvgChartCanvas.ColorAttributes(const AttributeName: string; const Color: TAlphaColor): string;
begin
  const Channels = TAlphaColorRec(Color);
  Result := Format('%s="#%.2x%.2x%.2x"', [AttributeName, Channels.R, Channels.G, Channels.B]);

  const IsOpaque = (Channels.A = $FF);
  if not IsOpaque then
    Result := Result + Format(' %s-opacity="%s"',
                              [AttributeName, FormatFloat('0.###', Channels.A / $FF, TFormatSettings.Invariant)]);
end;

class function TSvgChartCanvas.PointList(const Points: TArray<TPointF>): string;
begin
  const Builder = TStringBuilder.Create;
  try
    for var Index := 0 to High(Points) do
    begin
      if Index > 0 then
        Builder.Append(' ');

      Builder.Append(FormatNumber(Points[Index].X)).Append(',').Append(FormatNumber(Points[Index].Y));
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TSvgChartCanvas.TextAnchor(const AlignH: TTextAlignH): string;
begin
  case AlignH of
    TTextAlignH.Left   : Result := 'start';
    TTextAlignH.Center : Result := 'middle';
    TTextAlignH.Right  : Result := 'end';
  else
    raise EChart4DException.CreateFmt(SUnsupportedTextAlignH, [Ord(AlignH)]);
  end;
end;

class function TSvgChartCanvas.FontFamilyList(const FontName: string): string;
begin
  Result := '''' + EscapeXml(FontName.Replace('''', '')) + '''';

  { Arial and Helvetica share their metrics, so a viewer that has only the other one
    still reproduces the measured label widths. }
  if SameText(FontName, 'Arial') then
    Result := Result + ', Helvetica'
  else if SameText(FontName, 'Helvetica') then
    Result := Result + ', Arial';

  Result := Result + ', sans-serif';
end;

class function TSvgChartCanvas.ImageMimeType(const Bytes: TBytes): string;
begin
  Result := '';

  const IsPng = (Length(Bytes) >= 4) and (Bytes[0] = $89) and (Bytes[1] = $50) and (Bytes[2] = $4E) and
                (Bytes[3] = $47);
  const IsJpeg = (Length(Bytes) >= 3) and (Bytes[0] = $FF) and (Bytes[1] = $D8) and (Bytes[2] = $FF);
  const IsGif = (Length(Bytes) >= 4) and (Bytes[0] = $47) and (Bytes[1] = $49) and (Bytes[2] = $46) and
                (Bytes[3] = $38);
  const IsBmp = (Length(Bytes) >= 2) and (Bytes[0] = $42) and (Bytes[1] = $4D);

  if IsPng then
    Result := 'image/png'
  else if IsJpeg then
    Result := 'image/jpeg'
  else if IsGif then
    Result := 'image/gif'
  else if IsBmp then
    Result := 'image/bmp';
end;

{ TChartSvg }

class function TChartSvg.Render(const Plot: TChartPlot; const TextMeasurer: IChartCanvas;
                                const Width, Height: Single): string;
begin
  const HasPlot = Assigned(Plot);
  if not HasPlot then
    raise EChart4DException.Create(SRenderPlotRequired);

  const HasNoSeries = (Plot.Series.Count = 0);
  if HasNoSeries then
    raise EChart4DException.Create(SNoSeriesToRender);

  const SvgCanvas = TSvgChartCanvas.Create(Width, Height, TextMeasurer);
  const Canvas: IChartCanvas = SvgCanvas;
  SvgCanvas.Title := Plot.Title;

  TChartRenderer.Render(Plot, Canvas, Width, Height);
  Result := SvgCanvas.ToSvg;
end;

end.
