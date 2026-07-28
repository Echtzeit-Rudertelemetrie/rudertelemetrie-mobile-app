import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// The chart treatment shared by every plot in the app — live dashboard tiles
/// and the session replay alike. Defined once so a trace does not change
/// character depending on which screen it is drawn on.

/// Fades the accent from under the trace down to nothing at the baseline. Only
/// meaningful where the area under the line is an area of something — see
/// `ChartTile._fillsUnderLine`.
const LinearGradient chartFillGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x73FF5A45), Color(0x00FF5A45)],
);

/// Horizontal rules only. Vertical ones add a second grid to read past without
/// telling the eye anything the axis labels do not.
FlGridData chartGridData(double interval) => FlGridData(
  show: true,
  drawVerticalLine: false,
  horizontalInterval: interval,
  getDrawingHorizontalLine: (_) =>
      const FlLine(color: AppPalette.gridLine, strokeWidth: 1),
);

const TextStyle chartAxisLabelStyle = TextStyle(
  color: AppPalette.disabledLabel,
  fontSize: AppTypeScale.caption,
);

/// No box. The grid lines already establish the plotting area, and a border
/// around a tile that already has one just doubles the frame.
FlBorderData get chartBorderData => FlBorderData(show: false);
