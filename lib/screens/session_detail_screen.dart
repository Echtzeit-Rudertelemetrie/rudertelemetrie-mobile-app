import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:rudertelemetrie_mobile_app/components/async_content.dart';
import 'package:rudertelemetrie_mobile_app/components/confirm_dialog.dart';
import 'package:rudertelemetrie_mobile_app/services/notifications/app_notifications.dart';
import 'package:rudertelemetrie_mobile_app/utils/format.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/series_decimation.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_record.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// Read-only view of one saved session: summary, a replay chart from
/// `session.csv`, plus export (share sheet) and delete.
class SessionDetailScreen extends StatefulWidget {
  final SessionSummary summary;

  const SessionDetailScreen({super.key, required this.summary});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late Future<Map<String, List<SessionSample>>> _series;
  final Map<String, List<SessionSample>> _decimated = {};
  String? _selected;

  @override
  void initState() {
    super.initState();
    _series = _loadSeries();
  }

  /// Parsed once, off the UI isolate: a 20-minute outing is well over a hundred
  /// thousand samples per source, and decoding that on the main isolate locks
  /// the screen for as long as it takes.
  Future<Map<String, List<SessionSample>>> _loadSeries() async {
    final csv = await context.read<SessionStore>().readCsv(
      widget.summary.info.id,
    );
    return csv == null ? {} : compute(parseSessionCsv, csv);
  }

  /// Decimated per source and memoised, so switching series in the dropdown
  /// never re-parses the file.
  List<SessionSample> _displaySeries(
    String name,
    List<SessionSample> samples,
  ) => _decimated[name] ??= decimateSeries(samples);

  Future<void> _export() async {
    final notifications = context.read<AppNotifications>();
    try {
      final paths = await context.read<SessionStore>().exportPaths(
        widget.summary.info.id,
      );
      if (paths.isEmpty) {
        notifications.alert(
          'Nothing to export',
          detail: 'This session has no saved files.',
        );
        return;
      }
      await Share.shareXFiles(paths.map(XFile.new).toList());
    } catch (error) {
      notifications.alert('Export failed', detail: '$error');
    }
  }

  Future<void> _delete() async {
    final summary = widget.summary;
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete this session?',
      detail:
          '${_formatStartedAt(summary.info.startedAt)} · '
          '${formatElapsed(summary.duration)} · '
          '${formatDistance(summary.distanceMeters)}\n'
          'The recording cannot be recovered.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    await context.read<SessionStore>().deleteSession(summary.info.id);
    if (mounted) Navigator.pop(context);
  }

  String _formatStartedAt(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Session'),
        prefixes: [
          FHeaderAction(
            icon: const Icon(FIcons.arrowLeft),
            onPress: () => Navigator.pop(context),
          ),
        ],
        suffixes: [
          FHeaderAction(icon: const Icon(FIcons.share2), onPress: _export),
          FHeaderAction(icon: const Icon(FIcons.trash2), onPress: _delete),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          children: [
            _summary(s),
            const SizedBox(height: 16),
            const Text(
              'Replay',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 6),
            _replay(),
          ],
        ),
      ),
    );
  }

  Widget _summary(SessionSummary s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stat('Duration', formatElapsed(s.duration)),
      _stat('Distance', formatDistance(s.distanceMeters)),
      _stat('Start mode', s.info.startMode.name),
      for (final e in s.averages.entries)
        _stat('Avg ${e.key}', e.value.toStringAsFixed(1)),
      for (final e in s.peaks.entries)
        _stat('Peak ${e.key}', e.value.toStringAsFixed(1)),
    ],
  );

  Widget _stat(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    ),
  );

  Widget _replay() => AsyncContent<Map<String, List<SessionSample>>>(
    future: _series,
    onRetry: () => setState(() {
      _decimated.clear();
      _series = _loadSeries();
    }),
    errorMessage: 'Could not read this session’s recording.',
    height: 160,
    builder: (context, series) => _seriesView(series),
  );

  Widget _seriesView(Map<String, List<SessionSample>> series) {
    if (series.isEmpty) {
      return const Text(
        'No recorded series.',
        style: TextStyle(color: Colors.white38),
      );
    }
    final sources = series.keys.toList()..sort();
    final selected = _selected ??= sources.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          value: selected,
          isExpanded: true,
          dropdownColor: AppPalette.overlay,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: [
            for (final name in sources)
              DropdownMenuItem(value: name, child: Text(name)),
          ],
          onChanged: (v) => setState(() => _selected = v),
        ),
        SizedBox(
          height: 200,
          child: _chart(_displaySeries(selected, series[selected]!)),
        ),
      ],
    );
  }

  Widget _chart(List<SessionSample> points) {
    final spots = [for (final p in points) FlSpot(p.elapsedMs / 1000, p.value)];
    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: AppPalette.accent,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 18),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
      ),
    );
  }
}
