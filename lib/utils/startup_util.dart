import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/bluetooth_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';

FThemeData getTheme() {
  final base =
      const <TargetPlatform>{
        .android,
        .iOS,
        .fuchsia,
      }.contains(defaultTargetPlatform)
      ? FThemes.neutral.dark.touch
      : FThemes.neutral.dark.desktop;

  const background = Color(0xFF0c0e1d);
  final newColors = base.colors.copyWith(
    primary: const Color(0xFFF45866),
    primaryForeground: Colors.white,
    background: background,
  );

  return base.copyWith(
    colors: newColors,
    scaffoldStyle: base.scaffoldStyle.copyWith(backgroundColor: background),
    buttonStyles: FButtonStyles.inherit(
      colors: newColors,
      typography: base.typography,
      style: base.style,
      touch: const <TargetPlatform>{
        .android,
        .iOS,
        .fuchsia,
      }.contains(defaultTargetPlatform),
    ),
    tileGroupStyle: FTileGroupStyle.inherit(
      colors: newColors.copyWith(card: background),
      typography: base.typography,
      style: base.style,
    ),
    sliderStyles: FSliderStyles.inherit(
      colors: newColors.copyWith(secondary: Colors.white),
      typography: base.typography,
      style: base.style,
    ),
  );
}

void initializeBluetooth(BuildContext context) {
  final dataSourceRegistry = context.read<DataSourceProviderModel>().registry;
  final bluetoothManager = context.read<BluetoothProviderModel>().manager;

  bluetoothManager.initialize(dataSourceRegistry);
}
