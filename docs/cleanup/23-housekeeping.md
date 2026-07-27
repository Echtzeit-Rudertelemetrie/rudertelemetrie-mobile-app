# 23 — Housekeeping: dead code, dispose order, naming, i18n

**Priority:** P2 · **Effort:** S each · **Area:** maintenance

Small independent items. Each can be done in isolation.

## 23a — Remove the simulation/demo leftovers

`SineWaveChart`, `LiveValueDisplay`, `FrequencySlider` and
`SimulationSettingsModel` have no references anywhere in the app, yet
`simulationSettingsProvider` is still registered in `MultiProvider` — so a dead
model is constructed at every launch.

- `lib/components/sine_wave_chart.dart`
- `lib/components/live_value_display.dart`
- `lib/components/settings/frequency_slider.dart`
- `lib/models/simulation_settings_model.dart`
- `lib/providers/simulation_settings_provider.dart`
- `lib/main.dart:22` — remove from the provider list.
- `lib/utils/slider_util.dart` — only used by `FrequencySlider`; remove with it.

**Done when:** the files are gone, `main.dart` no longer registers the provider,
and `flutter analyze` plus the full test suite stay clean.

## 23b — Fix `dispose()` ordering

`ConnectedDevicesSettingsState.dispose` calls `super.dispose()` *before*
cancelling its stream subscriptions
(`lib/components/settings/connected_devices/connected_devices_settings.dart:47-51`).
A stream event delivered in that window calls `setState` on a disposed state.
Cancel first, then call `super.dispose()` last — the convention every other
`dispose` in the codebase follows.

**Done when:** subscriptions are cancelled before `super.dispose()`.

## 23c — Rename the misspelled tiles directory

`lib/components/dashboart_tiles/` → `dashboard_tiles/`. Mechanical rename plus
import updates across `dashboard_screen.dart`.

**Done when:** the directory is renamed and `flutter analyze` is clean.

## 23d — Wire up localisation

`FLocalizations.supportedLocales` and its delegates are configured in
`lib/main.dart:59-60`, but every user-facing string in the app is a hardcoded
English literal — in a German-language project.

Introduce `flutter_localizations` + ARB files, extract the strings, and provide
`de` and `en`. Worth doing before the string count grows further; the setup and
history screens are the bulk of it.

**Done when:** no user-facing literal remains in `lib/screens/` or
`lib/components/`, and switching the device language switches the app.

## 23e — Fix the working-tree indentation in `stroke_settings_screen.dart`

The uncommitted "wrap in `Material`" change added a nesting level without
reflowing the `ListView` children, leaving them indented one level short.
Run `dart format` on the touched files before committing.

**Done when:** `dart format --output=none --set-exit-if-changed lib/` passes.
