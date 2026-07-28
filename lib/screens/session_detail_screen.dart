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
import 'package:rudertelemetrie_mobile_app/theme/chart_style.dart';

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
  final GlobalKey _shareButton = GlobalKey();
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
    final anchor = _shareAnchor();
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
      await SharePlus.instance.share(
        ShareParams(
          files: paths.map(XFile.new).toList(),
          subject: 'Session ${_formatStartedAt(widget.summary.info.startedAt)}',
          sharePositionOrigin: anchor,
        ),
      );
    } catch (error) {
      notifications.alert('Export failed', detail: '$error');
    }
  }

  /// iPad presents the share sheet as a popover, which has to be anchored to
  /// the button that opened it.
  Rect? _shareAnchor() {
    final box = _shareButton.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
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
          FHeaderAction(
            key: _shareButton,
            icon: const Icon(FIcons.share2),
            onPress: _export,
          ),
          FHeaderAction(icon: const Icon(FIcons.trash2), onPress: _delete),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _summary(s),
            const SizedBox(height: 16),
            const Text(
              'Replay',
              style: TextStyle(
                color: AppPalette.faintLabel,
                fontSize: AppTypeScale.caption,
              ),
            ),
            const SizedBox(height: 6),
            _replay(),
          ],
        ),
      ),
    );
  }

  /// The four numbers a rower compares outings on get card-sized type; the
  /// long tail of averages and peaks stays a scannable list underneath.
  Widget _summary(SessionSummary s) {
    final headline = _headlineAverages(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroGrid(
          stats: [
            ('Duration', formatElapsed(s.duration)),
            ('Distance', formatDistance(s.distanceMeters)),
            for (final key in headline)
              ('Avg $key', s.averages[key]!.toStringAsFixed(1)),
          ],
        ),
        const SizedBox(height: 16),
        _StatList(
          stats: [
            ('Start mode', s.info.startMode.name),
            for (final e in s.averages.entries)
              if (!headline.contains(e.key))
                ('Avg ${e.key}', e.value.toStringAsFixed(1)),
            for (final e in s.peaks.entries)
              ('Peak ${e.key}', e.value.toStringAsFixed(1)),
          ],
        ),
      ],
    );
  }

  /// Two averages to sit beside duration and distance, picked by what a rower
  /// actually reads first. A session missing those falls back to whatever it
  /// does have, so the grid is never left with holes in it.
  List<String> _headlineAverages(SessionSummary s) {
    const preferred = ['Pace (/500m)', 'Stroke Rate', 'Speed (km/h)'];
    final available = s.averages.keys.toList();
    final ranked = [
      ...preferred.where(available.contains),
      ...available.where((key) => !preferred.contains(key)),
    ];
    return ranked.take(2).toList();
  }

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
        style: TextStyle(color: AppPalette.disabledLabel),
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
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(AppRadii.control),
          style: const TextStyle(
            color: AppPalette.label,
            fontSize: AppTypeScale.label,
          ),
          items: [
            for (final name in sources)
              DropdownMenuItem(value: name, child: Text(name)),
          ],
          onChanged: (v) => setState(() => _selected = v),
        ),
        Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(4, 12, 12, 4),
          decoration: BoxDecoration(
            color: AppPalette.overlay,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(color: AppPalette.surfaceBorder),
          ),
          child: _chart(_displaySeries(selected, series[selected]!)),
        ),
      ],
    );
  }

  Widget _chart(List<SessionSample> points) {
    final spots = [for (final p in points) FlSpot(p.elapsedMs / 1000, p.value)];
    // A series that dips below zero — an oar angle, say — has no meaningful
    // area under it, so it is drawn as a bare trace instead.
    final fills = points.every((p) => p.value >= 0);

    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: AppPalette.accent,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: fills, gradient: chartFillGradient),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(_axisLabel(value), style: chartAxisLabelStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  '${_axisLabel(value)}s',
                  style: chartAxisLabelStyle,
                ),
              ),
            ),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: chartBorderData,
      ),
    );
  }

  String _axisLabel(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

/// The session's headline numbers, two to a row.
class _HeroGrid extends StatelessWidget {
  final List<(String, String)> stats;

  const _HeroGrid({required this.stats});

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
    childAspectRatio: 2.1,
    children: [for (final (label, value) in stats) _HeroStat(label, value)],
  );
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppPalette.overlay,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      border: Border.all(color: AppPalette.surfaceBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppPalette.faintLabel,
            fontSize: AppTypeScale.caption,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: AppPalette.label,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Everything past the headline: one label/value pair per divided row.
class _StatList extends StatelessWidget {
  final List<(String, String)> stats;

  const _StatList({required this.stats});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < stats.length; i++) ...[
        if (i > 0) const Divider(height: 1, color: AppPalette.gridLine),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stats[i].$1,
                style: const TextStyle(
                  color: AppPalette.faintLabel,
                  fontSize: AppTypeScale.label,
                ),
              ),
              Text(
                stats[i].$2,
                style: const TextStyle(
                  color: AppPalette.label,
                  fontSize: AppTypeScale.label,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
