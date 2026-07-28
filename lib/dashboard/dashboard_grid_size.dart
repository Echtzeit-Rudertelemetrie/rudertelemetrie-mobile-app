/// The dashboard grid's dimensions, per orientation.
///
/// Both orientations subdivide the same coarse 4×8 grid — the one every layout
/// was saved in before the grid became orientation-aware, and still the unit a
/// new tile is sized in. Subdividing it is what lets tiles be nudged in small
/// steps instead of jumping a quarter of the screen.
///
/// Portrait halves the coarse cell on both axes, which keeps its cells roughly
/// square. Landscape is more than twice as wide as it is tall, so it quarters
/// the width and leaves the coarse rows alone — same result, square-ish cells.
///
/// Every value stays a multiple of the coarse grid, and each axis a multiple or
/// divisor of its counterpart in the other orientation, so rotating scales
/// coordinates exactly instead of rounding tiles onto each other.
class DashboardGridSize {
  static const int coarseCols = 4;
  static const int coarseRows = 8;

  static const int portraitCols = 8;
  static const int portraitRows = 16;

  static const int landscapeCols = 16;
  static const int landscapeRows = 8;

  const DashboardGridSize._();
}
