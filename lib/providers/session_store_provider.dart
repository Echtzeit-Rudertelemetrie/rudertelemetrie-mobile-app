import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';

/// Single [SessionStore] shared by the recording session (writes) and the
/// history screen (reads/export/delete).
final sessionStoreProvider = Provider<SessionStore>(
  lazy: false,
  create: (context) =>
      FileSessionStore(context.read<DataSourceProviderModel>().registry),
);
