import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/async_content.dart';
import 'package:rudertelemetrie_mobile_app/components/confirm_dialog.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/utils/format.dart';
import 'package:rudertelemetrie_mobile_app/screens/session_detail_screen.dart';
import 'package:rudertelemetrie_mobile_app/services/notifications/app_notifications.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_record.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';

/// Lists saved sessions from the [SessionStore], newest first, grouped by day.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<SessionSummary>> _sessions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _sessions = context.read<SessionStore>().listSessions();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _sessions;
  }

  @override
  Widget build(BuildContext context) => FScaffold(
    header: FHeader.nested(
      title: const Text('History'),
      prefixes: [
        FHeaderAction(
          icon: const Icon(FIcons.arrowLeft),
          onPress: () => Navigator.pop(context),
        ),
      ],
    ),
    child: AsyncContent<List<SessionSummary>>(
      future: _sessions,
      onRetry: () => setState(_load),
      errorMessage: 'Could not read your saved sessions.',
      height: double.infinity,
      builder: (context, data) => _list(data),
    ),
  );

  Widget _list(List<SessionSummary> sessions) {
    sessions.sort((a, b) => b.info.startedAt.compareTo(a.info.startedAt));
    return RefreshIndicator(
      onRefresh: _refresh,
      child: sessions.isEmpty ? _emptyState() : _grouped(sessions),
    );
  }

  /// Always scrollable, so pull-to-refresh works even with nothing in the list.
  Widget _emptyState() => ListView(
    padding: EdgeInsets.zero,
    physics: const AlwaysScrollableScrollPhysics(),
    children: const [
      SizedBox(height: 120),
      Center(
        child: Text(
          'No saved sessions yet.',
          style: TextStyle(color: Colors.white54),
        ),
      ),
    ],
  );

  Widget _grouped(List<SessionSummary> sessions) {
    final rows = _rowsByDay(sessions);
    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (context, i) => switch (rows[i]) {
        final _DayHeader header => _DayHeaderRow(header: header),
        final _SessionRowData row => Dismissible(
          key: ValueKey(row.summary.info.id),
          direction: DismissDirection.endToStart,
          background: _deleteBackground(),
          confirmDismiss: (_) => _confirmDelete(row.summary),
          onDismissed: (_) => _delete(row.summary),
          child: _SessionRow(
            summary: row.summary,
            onOpen: () => _open(row.summary),
          ),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _deleteBackground() => Container(
    alignment: Alignment.centerRight,
    color: Colors.redAccent.withAlpha(60),
    padding: const EdgeInsets.only(right: 20),
    child: const Icon(FIcons.trash2, color: Colors.redAccent),
  );

  Future<bool> _confirmDelete(SessionSummary summary) =>
      confirmDestructiveAction(
        context,
        title: 'Delete this session?',
        detail:
            '${_dayLabel(summary.info.startedAt)} · '
            '${formatElapsed(summary.duration)} · '
            '${formatDistance(summary.distanceMeters)}\n'
            'The recording cannot be recovered.',
        confirmLabel: 'Delete',
      );

  Future<void> _delete(SessionSummary summary) async {
    final notifications = context.read<AppNotifications>();
    await context.read<SessionStore>().deleteSession(summary.info.id);
    notifications.info('Session deleted');
    if (mounted) setState(_load);
  }

  Future<void> _open(SessionSummary summary) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionDetailScreen(summary: summary)),
    );
    if (mounted) setState(_load);
  }
}

/// Flattens sessions (already newest-first) into day headers followed by their
/// rows. Insertion order carries the day ordering.
List<Object> _rowsByDay(List<SessionSummary> sessions) {
  final byDay = <DateTime, List<SessionSummary>>{};
  for (final summary in sessions) {
    (byDay[DateUtils.dateOnly(summary.info.startedAt)] ??= []).add(summary);
  }
  return [
    for (final entry in byDay.entries) ...[
      _DayHeader(entry.key, entry.value),
      ...entry.value.map(_SessionRowData.new),
    ],
  ];
}

class _DayHeader {
  final DateTime day;
  final List<SessionSummary> sessions;
  const _DayHeader(this.day, this.sessions);

  double get distanceMeters =>
      sessions.fold(0, (sum, s) => sum + s.distanceMeters);

  Duration get duration =>
      sessions.fold(Duration.zero, (sum, s) => sum + s.duration);
}

class _SessionRowData {
  final SessionSummary summary;
  const _SessionRowData(this.summary);
}

String _two(int v) => v.toString().padLeft(2, '0');

String _dayLabel(DateTime at) => '${at.year}-${_two(at.month)}-${_two(at.day)}';

class _DayHeaderRow extends StatelessWidget {
  final _DayHeader header;

  const _DayHeaderRow({required this.header});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _dayLabel(header.day),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Text(
          '${formatElapsed(header.duration)} · '
          '${formatDistance(header.distanceMeters)}',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    ),
  );
}

class _SessionRow extends StatelessWidget {
  final SessionSummary summary;
  final VoidCallback onOpen;

  const _SessionRow({required this.summary, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final started = summary.info.startedAt;
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_two(started.hour)}:${_two(started.minute)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _metrics(summary),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(FIcons.chevronRight, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  /// Start mode is an implementation detail; average pace is what a rower
  /// actually wants to compare outings on.
  String _metrics(SessionSummary summary) {
    final parts = [
      formatElapsed(summary.duration),
      formatDistance(summary.distanceMeters),
    ];
    final pace = _averagePace(summary);
    if (pace != null) parts.add('${formatPace(pace)} ${Unit.pace.label}');
    return parts.join('  ·  ');
  }

  double? _averagePace(SessionSummary summary) {
    final speedKmh = summary.averages['Speed (km/h)'];
    if (speedKmh == null || speedKmh <= 0) return null;
    return 500 / (speedKmh / 3.6);
  }
}
