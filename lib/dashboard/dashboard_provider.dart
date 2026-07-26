import 'package:provider/provider.dart';
import 'dashboard_model.dart';
import 'dashboard_preset_store.dart';

final dashboardProvider = ChangeNotifierProvider<DashboardModel>(
  create: (_) => DashboardModel(store: FileDashboardPresetStore())..load(),
);
