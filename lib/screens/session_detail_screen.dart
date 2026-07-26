import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:rudertelemetrie_mobile_app/components/recording/session_control.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_record.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';

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
  String? _selected;

  @override
  void initState() {
    super.initState();
    _series = _loadSeries();
  }

  Future<Map<String, List<SessionSample>>> _loadSeries() async {
    final csv = await context.read<SessionStore>().readCsv(widget.summary.info.id);
    return csv == null ? {} : parseSessionCsv(csv);
  }

  Future<void> _export() async {
    final paths =
        await context.read<SessionStore>().exportPaths(widget.summary.info.id);
    if (paths.isEmpty) return;
    await Share.shareXFiles(paths.map(XFile.new).toList());
  }

  Future<void> _delete() async {
    await context.read<SessionStore>().deleteSession(widget.summary.info.id);
    if (mounted) Navigator.pop(context);
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
            const Text('Replay',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
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
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    ),
  );

  Widget _replay() => FutureBuilder<Map<String, List<SessionSample>>>(
    future: _series,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 40,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFFF45866)),
            ),
          ),
        );
      }
      final series = snapshot.data!;
      if (series.isEmpty) {
        return const Text('No recorded series.',
            style: TextStyle(color: Colors.white38));
      }
      final sources = series.keys.toList()..sort();
      final selected = _selected ??= sources.first;
      final points = series[selected]!;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<String>(
            value: selected,
            isExpanded: true,
            dropdownColor: const Color(0xFF1a1c2b),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: [
              for (final name in sources)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (v) => setState(() => _selected = v),
          ),
          SizedBox(height: 200, child: _chart(points)),
        ],
      );
    },
  );

  Widget _chart(List<SessionSample> points) {
    final spots = [
      for (final p in points) FlSpot(p.elapsedMs / 1000, p.value),
    ];
    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: const Color(0xFFF45866),
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
          bottomTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 18)),
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
