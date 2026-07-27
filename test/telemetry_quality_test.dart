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

  group('loss spikes', () {
    late List<int> spikes;
    late TelemetryQualityMonitor spiking;
    late Map<String, int> sequence;

    setUp(() {
      spikes = [];
      sequence = {'device': 0, 'left': 0, 'right': 0};
      spiking = TelemetryQualityMonitor(onLossSpike: spikes.add);
      // A first packet per device, so the next one can show a gap at all.
      for (final device in sequence.keys) {
        spiking.recordPacket(device, 0, now: start);
      }
    });
    tearDown(() => spiking.dispose());

    /// Drops [packets] from [device]'s sequence, [atMillis] after [start].
    void lose(int packets, int atMillis, {String device = 'device'}) {
      sequence[device] = sequence[device]! + packets + 1;
      spiking.recordPacket(
        device,
        sequence[device]!,
        now: start.add(Duration(milliseconds: atMillis)),
      );
    }

    test('stays quiet for a trickle of lost packets', () {
      lose(1, 0);
      lose(1, 3000);
      lose(1, 6000);

      expect(spikes, isEmpty);
    });

    test('reports once the window total crosses the threshold', () {
      lose(4, 0);
      expect(spikes, isEmpty);

      lose(4, 2000);
      expect(spikes, [8]);
    });

    test('a single large burst reports immediately', () {
      lose(20, 0);
      expect(spikes, [20]);
    });

    test('losses older than the window do not accumulate into a spike', () {
      lose(7, 0);
      lose(1, 20000);

      expect(spikes, isEmpty);
    });

    test('does not repeat inside the cooldown, but reports a later spike', () {
      lose(20, 0);
      lose(20, 5000);
      expect(spikes, [20]); // second burst falls inside the cooldown

      lose(20, 60000);
      expect(spikes, [20, 20]);
    });

    test('sums losses across oarlocks — the boat is what matters', () {
      lose(4, 0, device: 'left');
      expect(spikes, isEmpty);

      lose(4, 100, device: 'right');
      expect(spikes, [8]);
    });
  });
}
