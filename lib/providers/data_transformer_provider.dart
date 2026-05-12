import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_transformer.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/transformers/since_threshold_transformer.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/transformers/time_window_transformer.dart';

class DataTransformerProviderModel extends ChangeNotifier {
  final List<DataTransformer> _transformers = [
    TimeWindowTransformer(duration: Duration(seconds: 20), yUnit: Unit.N),
    SinceThresholdTransformer(yUnit: Unit.N, threshold: 50)
  ];

  List<DataTransformer> get all => _transformers;

  DataTransformer get(String key) {
    return _transformers.firstWhere(
      (t) => t.name == key,
      orElse: () => _transformers.first,
    );
  }
}

ChangeNotifierProvider<DataTransformerProviderModel> dataTransformerProvider =
    ChangeNotifierProvider(create: (_) => DataTransformerProviderModel());
