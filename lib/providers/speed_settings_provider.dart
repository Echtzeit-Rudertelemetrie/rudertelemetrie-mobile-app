import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/models/speed_settings_model.dart';

final speedSettingsProvider = ChangeNotifierProvider<SpeedSettingsModel>(
  create: (_) => SpeedSettingsModel(),
);
