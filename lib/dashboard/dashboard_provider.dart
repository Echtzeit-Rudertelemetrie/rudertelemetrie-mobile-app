import 'package:provider/provider.dart';
import 'dashboard_model.dart';

final dashboardProvider = ChangeNotifierProvider<DashboardModel>(
  create: (_) => DashboardModel(),
);
