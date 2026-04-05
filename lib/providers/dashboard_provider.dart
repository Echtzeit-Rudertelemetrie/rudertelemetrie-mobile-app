import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/models/dashboard_model.dart';

final dashboardProvider = ChangeNotifierProvider<DashboardModel>(
  create: (_) => DashboardModel(),
);
