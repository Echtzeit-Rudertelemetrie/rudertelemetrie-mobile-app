/// The dashboard grid's dimensions, per orientation.
///
/// Portrait keeps four wide columns. A landscape screen is more than twice as
/// wide as it is tall, so the same four columns would make one horizontal step
/// jump a quarter of the screen while a vertical step moves an eighth of a much
/// shorter axis. Landscape therefore spreads the layout over four times as many
/// columns, which leaves the cells roughly square and tiles placeable in far
/// finer steps.
///
/// [landscapeCols] must stay a multiple of [portraitCols] so rotating scales
/// coordinates exactly instead of rounding tiles onto each other.
class DashboardGridSize {
  static const int portraitCols = 4;
  static const int landscapeCols = 16;
  static const int rows = 8;

  const DashboardGridSize._();
}
