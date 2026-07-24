import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/models/telemetry_quality.dart';

void main() {
  late TelemetryQualityMonitor monitor;
  final start = DateTime(2026);

  setUp(() => monitor = TelemetryQualityMonitor());
  tearDown(() => monitor.dispose());

  test('reports a sequence gap and recovers after the visibility window', () {
    monitor.recordPacket('device', 10, now: start);
    monitor.recordPacket(
      'device',
      13,
      now: start.add(const Duration(milliseconds: 80)),
    );

    final loss = monitor.qualityAt(
      start.add(const Duration(milliseconds: 400)),
    );
    expect(loss.level, TelemetryQualityLevel.delayed);
    expect(loss.missingPackets, 2);

    final recovered = monitor.qualityAt(start.add(const Duration(seconds: 5)));
    expect(recovered.missingPackets, 0);
  });

  test('reports lag and an interrupted data stream', () {
    monitor.recordPacket('device', 1, now: start);

    expect(
      monitor.qualityAt(start.add(const Duration(milliseconds: 300))).level,
      TelemetryQualityLevel.delayed,
    );
    expect(
      monitor.qualityAt(start.add(const Duration(milliseconds: 700))).level,
      TelemetryQualityLevel.interrupted,
    );
  });

  test('reports an invalid packet before the first valid packet', () {
    monitor.recordInvalidPacket('device', now: start);

    final quality = monitor.qualityAt(start);
    expect(quality.level, TelemetryQualityLevel.delayed);
    expect(quality.invalidPackets, 1);
  });

  test('handles the 28 bit sequence number wrap without a false loss', () {
    monitor.recordPacket('device', (1 << 28) - 1, now: start);
    monitor.recordPacket(
      'device',
      0,
      now: start.add(const Duration(milliseconds: 80)),
    );

    expect(monitor.qualityAt(start).missingPackets, 0);
  });
}
