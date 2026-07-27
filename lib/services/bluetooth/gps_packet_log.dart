import 'package:flutter/foundation.dart';
import 'package:rudertelemetrie_mobile_app/services/kinematics/gps_kinematics.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';

/// Console trace of the boat packet (id 0), which carries GPS.
///
/// Separates three things a live dashboard cannot tell apart: whether boat
/// packets arrive at all, whether the receiver reports a valid fix, and how
/// often the position actually changes — the firmware repeats its last fix in
/// every packet, so the packet rate is not the fix rate.
class GpsPacketLog {
  static const _reportInterval = Duration(seconds: 5);

  /// Boat packets are ~80 ms apart; longer than this is a dropout worth a line.
  static const _gapThreshold = Duration(milliseconds: 500);

  final String deviceId;
  final void Function(String message) _write;

  DateTime? _windowStart;
  DateTime? _lastPacketAt;
  int _packets = 0;
  int _validPackets = 0;
  int _missedPackets = 0;
  int _positionUpdates = 0;
  double _maxStepSpeedMps = 0;

  int? _lastSequence;
  GpsSample? _lastFix;
  DateTime? _lastFixAt;
  GpsSample? _lastSample;
  List<int>? _lastRawFrame;
  bool _sawFirstPacket = false;
  bool _sawFirstFix = false;

  GpsPacketLog({required this.deviceId, void Function(String)? write})
    : _write = write ?? debugPrint;

  void record(BoatPacket packet, DateTime at, {List<int>? rawFrame}) {
    _noteArrival(packet, at);
    _lastSample = packet.gps;
    _lastRawFrame = rawFrame;
    if (packet.gps.valid) {
      _validPackets++;
      _noteFix(packet.gps, at);
    }
    if (at.difference(_windowStart!) >= _reportInterval) _report(at);
  }

  void _noteArrival(BoatPacket packet, DateTime at) {
    _windowStart ??= at;
    _packets++;
    if (!_sawFirstPacket) {
      _sawFirstPacket = true;
      _write('$_tag first boat packet (seq ${packet.sequenceNumber})');
    }
    _noteGap(at);
    _noteSequence(packet.sequenceNumber);
    _lastPacketAt = at;
  }

  void _noteGap(DateTime at) {
    final last = _lastPacketAt;
    if (last == null) return;
    final gap = at.difference(last);
    if (gap >= _gapThreshold) {
      _write('$_tag gap of ${gap.inMilliseconds} ms between boat packets');
    }
  }

  void _noteSequence(int sequence) {
    final previous = _lastSequence;
    _lastSequence = sequence;
    if (previous == null) return;

    final advance = (sequence - previous) % BluetoothPacket.sequenceModulo;
    if (advance > 1 && advance < BluetoothPacket.sequenceModulo ~/ 2) {
      _missedPackets += advance - 1;
    }
  }

  void _noteFix(GpsSample gps, DateTime at) {
    if (!_sawFirstFix) {
      _sawFirstFix = true;
      _write(
        '$_tag first valid fix ${_position(gps)}, ${gps.satellites} sats',
      );
    }

    final previous = _lastFix;
    if (previous != null && _isSamePosition(previous, gps)) return;

    _positionUpdates++;
    if (previous != null) _noteStepSpeed(previous, gps, at);
    _lastFix = gps;
    _lastFixAt = at;
  }

  bool _isSamePosition(GpsSample a, GpsSample b) =>
      a.latitude == b.latitude && a.longitude == b.longitude;

  /// The implied speed between two *distinct* positions. If this sits far above
  /// [GpsKinematics.maxPlausibleSpeedMps] while the boat moves normally, every
  /// real step is being discarded as a glitch.
  void _noteStepSpeed(GpsSample previous, GpsSample current, DateTime at) {
    final since = _lastFixAt;
    if (since == null) return;
    final seconds = at.difference(since).inMicroseconds / 1e6;
    if (seconds <= 0) return;

    final meters = haversineMeters(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    final speed = meters / seconds;
    if (speed > _maxStepSpeedMps) _maxStepSpeedMps = speed;
  }

  void _report(DateTime at) {
    final seconds = at.difference(_windowStart!).inMilliseconds / 1000;
    _write('$_tag ${_summary(seconds)}');
    _resetWindow(at);
  }

  String _summary(double seconds) {
    final parts = [
      '$_packets packets/${seconds.toStringAsFixed(1)}s',
      '${(_packets / seconds).toStringAsFixed(1)} Hz',
      if (_missedPackets > 0) 'missed $_missedPackets',
      'valid $_validPackets',
      'position updates $_positionUpdates '
          '(${(_positionUpdates / seconds).toStringAsFixed(2)} Hz)',
      if (_positionUpdates > 1)
        'max step ${_maxStepSpeedMps.toStringAsFixed(1)} m/s',
      _fixDescription(),
    ];
    return parts.join(', ');
  }

  String _fixDescription() {
    final fix = _lastFix;
    if (fix != null) {
      return '${_position(fix)} sats ${fix.satellites} '
          'fw speed ${fix.speedMps.toStringAsFixed(2)} m/s';
    }
    return 'no valid fix yet, ${_rawDescription()}';
  }

  /// With `valid` never set, the decoded fields and the bytes they came from are
  /// the only way to tell a receiver without a lock (all zeroes) from a byte
  /// layout the app reads at the wrong offsets (plausible values, wrong slots).
  String _rawDescription() {
    final sample = _lastSample;
    if (sample == null) return 'no boat packet decoded';
    return 'last ${_position(sample)} sats ${sample.satellites} '
        'course ${sample.courseDeg.toStringAsFixed(2)} '
        'fw speed ${sample.speedMps.toStringAsFixed(2)} m/s '
        'raw ${_hex(_lastRawFrame)}';
  }

  String _hex(List<int>? frame) {
    if (frame == null) return 'unavailable';
    return frame
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .replaceAllMapped(RegExp(r'.{8}'), (m) => '${m[0]} ')
        .trim();
  }

  String _position(GpsSample gps) =>
      '${gps.latitude.toStringAsFixed(6)}/${gps.longitude.toStringAsFixed(6)}';

  void _resetWindow(DateTime at) {
    _windowStart = at;
    _packets = 0;
    _validPackets = 0;
    _missedPackets = 0;
    _positionUpdates = 0;
    _maxStepSpeedMps = 0;
  }

  String get _tag => 'GPS[$deviceId]';
}
