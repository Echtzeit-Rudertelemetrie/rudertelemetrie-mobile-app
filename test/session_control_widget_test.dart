import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/recording/session_control.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/recording_provider.dart';

void main() {
  // Regression: the recording session registers derived sources in its
  // constructor, which notifies the data source registry. If the session is
  // created lazily during SessionControl's build (while a sibling watches the
  // registry), Flutter throws "setState() called during build". The provider is
  // eager (lazy: false) to prevent this.
  testWidgets('SessionControl mounts without a build-phase registry error',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [dataSourceProvider, recordingProvider],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              // Depend on the registry so a mid-build notify would mark us dirty.
              context.watch<DataSourceProviderModel>();
              return const Scaffold(body: SessionControl());
            },
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
