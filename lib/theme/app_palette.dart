import 'package:flutter/material.dart';

/// The one place the app's colours are defined. `getTheme()` builds the Forui
/// theme from these, and every widget and painter reads them from here — a
/// palette change is a single-file edit, and the muted-label shades cannot drift
/// apart again.
class AppPalette {
  const AppPalette._();

  /// Brand accent: record button, selection, chart series, focus rings.
  static const Color accent = Color(0xFFFF5A45);

  /// App background.
  static const Color background = Color(0xFF0A0B16);

  /// Raised surface: dashboard tiles.
  static const Color surface = Color(0xFF191C33);

  /// Overlay surface: sheets, menus, cards inside a scrolling screen.
  static const Color overlay = Color(0xFF161A30);

  /// Hairline around a raised surface. Separates a tile from the background at
  /// the low contrast this dark theme runs at, without reading as a frame.
  static const Color surfaceBorder = Color(0x14FFFFFF);

  /// Primary text on a dark surface.
  static const Color label = Colors.white;

  /// Secondary text: field labels, row subtitles.
  static const Color mutedLabel = Color(0xFFADB0BD);

  /// Tertiary text: units, hints, axis labels.
  static const Color faintLabel = Color(0xFF8A8D9C);

  /// Placeholder text and disabled controls.
  static const Color disabledLabel = Color(0xFF666A7B);

  /// Borders of unselected controls.
  static const Color outline = Color(0x2EFFFFFF);

  /// Chart grid lines and dividers.
  static const Color gridLine = Color(0x14FFFFFF);

  static const Color danger = Color(0xFFFF5F5F);
  static const Color warning = Color(0xFFFFB020);
  static const Color ok = Color(0xFF33D17A);
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

  /// Section headings inside a screen or a sheet.
  static const double heading = 16;

  /// Live readouts. Sized for a glance from the far end of a boat; a tile too
  /// small to hold it scales it down itself.
  static const double readout = 52;
}

/// Corner radii. Three steps only — a fourth reads as an accident rather than
/// a decision.
class AppRadii {
  const AppRadii._();

  /// Chips, handles, small controls.
  static const double control = 10;

  /// Dashboard tiles, list cards, sheet rows.
  static const double tile = 16;

  /// Full-width panels: the readiness card, the sheet itself.
  static const double panel = 20;
}

/// Minimum hit area for anything interactive, per the platform guidelines —
/// and the practical floor for wet hands on a moving boat.
const double kMinTapTarget = 44;
