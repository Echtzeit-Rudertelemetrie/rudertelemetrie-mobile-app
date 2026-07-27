import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/notifications/app_notifications.dart';

/// Single message queue shared by every service that needs to tell the user
/// something, drained by `NoticePresenter` near the root of the tree.
final notificationsProvider = ChangeNotifierProvider<AppNotifications>(
  lazy: false,
  create: (_) => AppNotifications(),
);
