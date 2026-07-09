import 'package:flutter/foundation.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

class DataSourceRegistry extends ChangeNotifier {
  final Map<String, DataSource> _sources = {};

  void register(DataSource source) {
    _sources[source.name] = source;
    notifyListeners();
  }

  void unregister(String key) {
    if (_sources.remove(key) != null) notifyListeners();
  }

  DataSource? get(String key) => _sources[key];

  List<DataSource> get all => List.unmodifiable(_sources.values);
}
