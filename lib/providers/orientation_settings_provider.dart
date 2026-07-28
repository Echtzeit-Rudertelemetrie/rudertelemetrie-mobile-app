import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/display/orientation_settings.dart';

final orientationSettingsProvider = ChangeNotifierProvider<OrientationSettings>(
  create: (_) =>
      OrientationSettings(store: FileOrientationSettingsStore())..load(),
);
