import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config_store.dart';

final boatConfigProvider = ChangeNotifierProvider<BoatConfig>(
  create: (_) => BoatConfig(store: FileBoatConfigStore())..load(),
);
