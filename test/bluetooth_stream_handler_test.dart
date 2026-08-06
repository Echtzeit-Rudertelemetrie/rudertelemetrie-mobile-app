import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/models/speed_settings_model.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_stream_handler.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';

const _samples = BluetoothPacket.samplesPerRegion;
const _sampleMs = BluetoothPacket.sampleIntervalMs;
const _packetMs = _samples * _sampleMs;

/// One oarlock `MeasurementPack` with constant force/angle samples.
List<int> _oarlockFrame(
  int sensorId,
  int sequence, {
  double angleDeg = -169.013,
}) {
  final data = ByteData(BluetoothPacket.packetSize);
  data.setUint32(
    0,
    ((sensorId & 0xF) << 28) | (sequence & 0x0FFFFFFF),
    Endian.little,
  );
  for (var i = 0; i < _samples; i++) {
    data.setUint16(4 + i * 2, 1000, Endian.little);
    final encodedAngle = ((angleDeg + 180) / 360 * 65535).round().clamp(
      0,
      65535,
    );
    data.setUint16(4 + (_samples + i) * 2, encodedAngle, Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Boat telemetry frame. The IMU region starts at 20; roll/pitch/yaw are
/// centidegrees at 26/28/30, the device clock a uint32 at 32.
List<int> _boatFrame(
  double yawDeg, {
  double pitchDeg = 0,
  int timestampMs = 1000,
}) {
  final data = ByteData(BluetoothPacket.packetSize);
  data.setInt16(28, (pitchDeg * 100).round(), Endian.little);
  data.setInt16(30, (yawDeg * 100).round(), Endian.little);
  data.setUint32(32, timestampMs, Endian.little);
  return data.buffer.asUint8List();
}

/// Long enough for the pacing timer to pay out everything queued so far.
Future<void> _drainPlayback(int packets) =>
    Future<void>.delayed(Duration(milliseconds: packets * _packetMs + 150));

void main() {
  late DataSourceRegistry registry;
  late BluetoothStreamHandler handler;
  late List<int> accepted;
  late List<int> acceptedSensors;

  setUp(() {
    registry = DataSourceRegistry();
    accepted = [];
    acceptedSensors = [];
    handler = BluetoothStreamHandler(
      dataSourceRegistry: registry,
      deviceId: 'AA:BB:CC:DD:EE:01',
      speedSettings: SpeedSettingsModel(),
      onOarlockPacket: (sensorId, sequence) {
        acceptedSensors.add(sensorId);
        accepted.add(sequence);
      },
    );
  });

  tearDown(() => handler.dispose());

  DataSource sourceStartingWith(String prefix) =>
      registry.all.firstWhere((s) => s.name.startsWith(prefix));

  List<int> offsetsOf(List<Measurement> samples, DataSource source) => samples
      .map((m) => m.timestamp.difference(source.startTime).inMilliseconds)
      .toList();

  List<Measurement> listen(DataSource source) {
    final received = <Measurement>[];
    final sub = source.data.listen(received.add);
    addTearDown(sub.cancel);
    return received;
  }

  test('registers a force and angle stream per oarlock', () {
    handler.onData(_oarlockFrame(1, 0));
    handler.onData(_oarlockFrame(2, 0));

    expect(
      registry.all.map((source) => source.name),
      unorderedEquals([
        'Force 1 (EE01)',
        'Angle 1 (EE01)',
        'Raw Angle 1 (EE01)',
        'Force 2 (EE01)',
        'Angle 2 (EE01)',
        'Raw Angle 2 (EE01)',
      ]),
    );
  });

  test(
    'pays out a packet across the packet duration instead of at once',
    () async {
      handler.onData(_oarlockFrame(1, 0));
      final received = listen(sourceStartingWith('Force 1'));

      expect(received, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(received.length, inInclusiveRange(1, _samples - 1));

      await _drainPlayback(1);
      expect(received, hasLength(_samples));
    },
  );

  test(
    'anchors a large starting sequence number to the source start time',
    () async {
      handler.onData(_oarlockFrame(1, 1000000));
      final force = sourceStartingWith('Force 1');
      final received = listen(force);

      handler.onData(_oarlockFrame(1, 1000001));
      await _drainPlayback(2);

      expect(offsetsOf(received, force), [
        for (var i = 0; i < 2 * _samples; i++) i * _sampleMs,
      ]);
    },
  );

  test('leaves a gap in place of packets lost in transit', () async {
    handler.onData(_oarlockFrame(1, 10));
    final force = sourceStartingWith('Force 1');
    final received = listen(force);

    handler.onData(_oarlockFrame(1, 13)); // packets 11 and 12 never arrived
    await _drainPlayback(2);

    expect(offsetsOf(received, force).last, 3 * _packetMs + 7 * _sampleMs);
  });

  test('each oarlock is anchored independently', () async {
    handler.onData(_oarlockFrame(1, 500000));
    handler.onData(_oarlockFrame(2, 900000));
    final first = sourceStartingWith('Force 1');
    final second = sourceStartingWith('Force 2');
    final firstSamples = listen(first);
    final secondSamples = listen(second);

    handler.onData(_oarlockFrame(1, 500001));
    handler.onData(_oarlockFrame(2, 900001));
    await _drainPlayback(2);

    expect(offsetsOf(firstSamples, first).first, 0);
    expect(offsetsOf(secondSamples, second).first, 0);
    expect(offsetsOf(firstSamples, first).last, _packetMs + 7 * _sampleMs);
    expect(offsetsOf(secondSamples, second).last, _packetMs + 7 * _sampleMs);
  });

  test('a sequence counter wrapping past 28 bits keeps advancing', () async {
    handler.onData(_oarlockFrame(1, BluetoothPacket.sequenceModulo - 1));
    final force = sourceStartingWith('Force 1');
    final received = listen(force);

    handler.onData(_oarlockFrame(1, 0)); // wrapped
    await _drainPlayback(2);

    expect(offsetsOf(received, force).last, _packetMs + 7 * _sampleMs);
    expect(accepted, [BluetoothPacket.sequenceModulo - 1, 0]);
  });

  /// Die Sequenznummer allein genuegt dem Qualitaetsmonitor nicht: jede Dolle
  /// zaehlt eigenstaendig, also muss die sensorId mitgereicht werden, sonst
  /// verschraenkt der Monitor fremde Zaehler und meldet Phantomverluste.
  test('forwards the sensorId alongside the sequence number', () {
    handler.onData(_oarlockFrame(1, 10));
    handler.onData(_oarlockFrame(2, 9000));
    handler.onData(_oarlockFrame(1, 11));

    expect(acceptedSensors, [1, 2, 1]);
    expect(accepted, [10, 9000, 11]);
  });

  test('drops duplicates and late retries, and survives a sender restart', () {
    handler.onData(_oarlockFrame(1, 1000));
    handler.onData(_oarlockFrame(1, 1000)); // radio retry
    handler.onData(_oarlockFrame(1, 1001));
    handler.onData(_oarlockFrame(1, 999)); // late packet
    handler.onData(_oarlockFrame(1, 1)); // sender reboot

    expect(accepted, [1000, 1001, 1]);
  });

  test('subtracts boat yaw from every oarlock angle', () async {
    handler.onData(_boatFrame(30));
    handler.onData(_oarlockFrame(1, 0, angleDeg: 50));
    final received = listen(sourceStartingWith('Angle 1'));

    await _drainPlayback(1);

    expect(received, hasLength(_samples));
    for (final sample in received) {
      expect(sample.value, closeTo(20, 0.01));
    }
  });

  test('ignores boat pitch, which saturates at plus/minus 90 degrees', () async {
    handler.onData(_boatFrame(0, pitchDeg: 40));
    handler.onData(_oarlockFrame(1, 0, angleDeg: 50));
    final received = listen(sourceStartingWith('Angle 1'));

    await _drainPlayback(1);

    expect(received.last.value, closeTo(50, 0.01));
  });

  test('leaves the raw angle uncompensated', () async {
    handler.onData(_boatFrame(30));
    handler.onData(_oarlockFrame(1, 0, angleDeg: 50));
    final received = listen(sourceStartingWith('Raw Angle 1'));

    await _drainPlayback(1);

    expect(received.last.value, closeTo(50, 0.01));
  });

  test('wraps corrected angles into the -180 to 180 degree range', () async {
    handler.onData(_boatFrame(-30));
    handler.onData(_oarlockFrame(1, 0, angleDeg: 170));
    final received = listen(sourceStartingWith('Angle 1'));

    await _drainPlayback(1);

    expect(received.last.value, closeTo(-160, 0.01));
  });

  test('reports a notification that is not a whole packet', () {
    var invalid = 0;
    final strict = BluetoothStreamHandler(
      dataSourceRegistry: registry,
      deviceId: 'device',
      speedSettings: SpeedSettingsModel(),
      onInvalidPacket: () => invalid++,
    );
    addTearDown(strict.dispose);

    strict.onData(_oarlockFrame(1, 0).sublist(0, 10));

    expect(invalid, 1);
    expect(registry.all, isEmpty);
  });
}
