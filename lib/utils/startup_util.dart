import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/bluetooth_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/notifications/app_notifications.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

FThemeData getTheme() {
  final base =
      const <TargetPlatform>{
        .android,
        .iOS,
        .fuchsia,
      }.contains(defaultTargetPlatform)
      ? FThemes.neutral.dark.touch
      : FThemes.neutral.dark.desktop;

  const background = AppPalette.background;
  final newColors = base.colors.copyWith(
    primary: AppPalette.accent,
    primaryForeground: AppPalette.label,
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
  final notifications = context.read<AppNotifications>();

  bluetoothManager.onDeviceConnected.listen(
    (device) => notifications.info('${device.name} connected'),
  );
  bluetoothManager.onDeviceLost.listen(
    (device) => notifications.alert('${device.name} disconnected'),
  );
  bluetoothManager.onError.listen(notifications.alert);

  bluetoothManager.initialize(dataSourceRegistry);
}

/// Sweeps directories left behind by a recording the app never got to finish,
/// and tells the user what came back.
Future<void> recoverInterruptedSessions(BuildContext context) async {
  final store = context.read<SessionStore>();
  final notifications = context.read<AppNotifications>();

  final recovered = await store.recoverOrphans();
  if (recovered.isEmpty) return;
  notifications.info(
    'Recovered ${recovered.length} interrupted '
    'session${recovered.length == 1 ? '' : 's'}',
    detail: 'Find them in History.',
  );
}
