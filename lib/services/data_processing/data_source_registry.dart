import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

class DataSourceRegistry {
  final Map<String, DataSource> _sources = {};

  void register(DataSource source) => _sources[source.name] = source;

  void unregister(String key) => _sources.remove(key);

  DataSource? get(String key) => _sources[key];

  List<DataSource> get all => List.unmodifiable(_sources.values);
}