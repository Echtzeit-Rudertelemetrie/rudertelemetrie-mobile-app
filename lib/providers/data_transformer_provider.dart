import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_transformer.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/transformers/time_window_transformer.dart';

class DataTransformerProviderModel extends ChangeNotifier {
  DataTransformer get(String key) {
    return switch (key) {
      _ => TimeWindowTransformer(duration: Duration(seconds: 5), yUnit: Unit.N)
    };
  }
}

ChangeNotifierProvider<DataTransformerProviderModel> dataTransformerProvider =
    ChangeNotifierProvider(create: (_) => DataTransformerProviderModel());
