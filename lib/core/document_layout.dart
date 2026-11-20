/// Shared US Letter table geometry (in points) for both the live Flutter
/// preview and the generated PDF document.
class DocumentLayout {
  const DocumentLayout._();

  static const double marginLeft = 74.0;
  static const double marginRight = 68.0;
  static const double marginTop = 56.0;
  static const double marginBottom = 42.0;

  // 5-column table geometry (sum = 470.0 pt = 612 - 74 - 68).
  static const double colQtyWidth = 34.0;
  static const double colDescWidth = 230.0;
  static const double colUnitIntWidth = 37.0;
  static const double colUnitDecWidth = 17.0;
  static const double colBsIntWidth = 58.5;
  static const double colBsDecWidth = 17.5;
  static const double colTotalIntWidth = 58.5;
  static const double colTotalDecWidth = 17.5;

  static const double colUnitWidth = colUnitIntWidth + colUnitDecWidth; // 54.0
  static const double colBsWidth = colBsIntWidth + colBsDecWidth; // 76.0
  static const double colTotalWidth = colTotalIntWidth + colTotalDecWidth; // 76.0
  static const double tableWidth =
      colQtyWidth + colDescWidth + colUnitWidth + colBsWidth + colTotalWidth; // 470.0

  // Exact x-offsets for vertical rules across the 470 pt table.
  static const double xQtyRight = colQtyWidth; // 34.0
  static const double xDescRight = xQtyRight + colDescWidth; // 264.0
  static const double xUnitDecimal = xDescRight + colUnitIntWidth; // 301.0
  static const double xUnitRight = xDescRight + colUnitWidth; // 318.0
  static const double xBsDecimal = xUnitRight + colBsIntWidth; // 376.5
  static const double xBsRight = xUnitRight + colBsWidth; // 394.0
  static const double xTotalDecimal = xBsRight + colTotalIntWidth; // 452.5

  static const double lineThickness = 0.9;
  static const double tableHeaderHeight = 20.0;
  static const double tableBodyBaseHeight = 374.0;
  static const double totalRowHeight = 24.0;
}
