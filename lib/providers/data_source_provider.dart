import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/sample_data_source.dart';

class DataSourceProviderModel extends ChangeNotifier {
  final DataSourceRegistry _registry = DataSourceRegistry();

  DataSourceRegistry get registry => _registry;

  DataSourceProviderModel() {
    _registry.addListener(notifyListeners);
    _registry.register(SampleDataSource());
  }

  @override
  void dispose() {
    _registry.removeListener(notifyListeners);
    super.dispose();
  }
}

ChangeNotifierProvider<DataSourceProviderModel> dataSourceProvider =
    ChangeNotifierProvider(create: (_) => DataSourceProviderModel());
