import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/models/simulation_settings_model.dart';

ChangeNotifierProvider<SimulationSettingsModel> simulationSettingsProvider =
    ChangeNotifierProvider<SimulationSettingsModel>(
      create: (_) => SimulationSettingsModel(),
    );
