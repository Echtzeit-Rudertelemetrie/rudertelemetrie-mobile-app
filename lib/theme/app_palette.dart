import 'package:flutter/material.dart';

/// The one place the app's colours are defined. `getTheme()` builds the Forui
/// theme from these, and every widget and painter reads them from here — a
/// palette change is a single-file edit, and the muted-label shades cannot drift
/// apart again.
class AppPalette {
  const AppPalette._();

  /// Brand accent: record button, selection, chart series, focus rings.
  static const Color accent = Color(0xFFF45866);

  /// App background.
  static const Color background = Color(0xFF0c0e1d);

  /// Raised surface: dashboard tiles.
  static const Color surface = Color(0xFF1a1d30);

  /// Overlay surface: sheets, menus.
  static const Color overlay = Color(0xFF1a1c2b);

  /// Primary text on a dark surface.
  static const Color label = Colors.white;

  /// Secondary text: field labels, row subtitles.
  static const Color mutedLabel = Colors.white70;

  /// Tertiary text: units, hints, axis labels.
  static const Color faintLabel = Colors.white54;

  /// Placeholder text and disabled controls.
  static const Color disabledLabel = Colors.white38;

  /// Borders of unselected controls.
  static const Color outline = Colors.white24;

  /// Chart grid lines and dividers.
  static const Color gridLine = Colors.white10;

  static const Color danger = Colors.redAccent;
  static const Color warning = Colors.amber;
  static const Color ok = Colors.greenAccent;
}

/// Minimum on-screen text size. This app is read at arm's length, in direct
/// sunlight, from a moving boat — anything smaller is decorative, not legible.
class AppTypeScale {
  const AppTypeScale._();

  /// Axis ticks, units, the smallest thing allowed on screen.
  static const double caption = 12;

  /// Row subtitles, field labels.
  static const double label = 13;

  /// Body text and tile titles.
  static const double body = 15;

  /// Live readouts.
  static const double readout = 40;
}

/// Minimum hit area for anything interactive, per the platform guidelines —
/// and the practical floor for wet hands on a moving boat.
const double kMinTapTarget = 44;
