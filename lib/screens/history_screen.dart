import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/recording/session_control.dart';
import 'package:rudertelemetrie_mobile_app/screens/session_detail_screen.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_record.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';

/// Lists saved sessions from the [SessionStore], newest first.
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
    child: FutureBuilder<List<SessionSummary>>(
      future: _sessions,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFF45866),
              ),
            ),
          );
        }
        final sessions = snapshot.data!
          ..sort((a, b) => b.info.startedAt.compareTo(a.info.startedAt));
        if (sessions.isEmpty) {
          return const Center(
            child: Text('No saved sessions yet.',
                style: TextStyle(color: Colors.white54)),
          );
        }
        return ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (context, i) => _SessionRow(
            summary: sessions[i],
            onOpen: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionDetailScreen(summary: sessions[i]),
                ),
              );
              if (mounted) setState(_load);
            },
          ),
        );
      },
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
    final date =
        '${started.year}-${_two(started.month)}-${_two(started.day)} '
        '${_two(started.hour)}:${_two(started.minute)}';
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '${formatElapsed(summary.duration)}  ·  '
                    '${formatDistance(summary.distanceMeters)}  ·  '
                    '${summary.info.startMode.name}',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
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

  String _two(int v) => v.toString().padLeft(2, '0');
}
