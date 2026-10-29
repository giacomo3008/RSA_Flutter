import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/models.dart';
import '../shared/ui.dart';

/// Rich presentation of saved text. Only exact source lines become report cards;
/// human edits and unmatched text remain visible verbatim.
class HandoverRecordContent extends StatelessWidget {
  final String text;
  final List<CareEvent> events;
  final bool frozen;
  const HandoverRecordContent({
    super.key,
    required this.text,
    required this.events,
    required this.frozen,
  });

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final children = <Widget>[];
    const headings = <String, (IconData, Color)>{
      'Important reported events': (Icons.assignment_outlined, teal),
      'Open follow-ups': (Icons.pending_actions_outlined, Color(0xff9a691d)),
      'Unresolved notifications': (
        Icons.notifications_active_outlined,
        Color(0xffb54345),
      ),
      'Items to pass to the next shift': (Icons.swap_horiz, Color(0xff6c895c)),
      'Amendment': (Icons.edit_note_outlined, teal),
      'Additional staff updates': (Icons.post_add_outlined, teal),
    };
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final heading = headings[line];
      if (heading != null) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: children.isEmpty ? 0 : 24,
              bottom: 12,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: heading.$2.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(heading.$1, size: 18, color: heading.$2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      final event = events.where((e) {
        final subject = e.residentId ?? e.subject;
        return line ==
                ('${e.type.label} · $subject — ${e.status.label}. ${e.notes}')
                    .trim() ||
            line ==
                '${e.priority.label}: ${e.type.label} · $subject — ${e.status.label}.';
      }).firstOrNull;
      if (event != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: HandoverEventCard(
              event: event,
              frozen: frozen,
              compact: seen.contains(event.id),
            ),
          ),
        );
        seen.add(event.id);
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: SelectableText(
              raw,
              style: const TextStyle(fontSize: 13, height: 1.7),
            ),
          ),
        );
      }
    }
    final remaining = events.where((e) => !seen.contains(e.id)).toList();
    if (remaining.isNotEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(top: 20, bottom: 12),
          child: Text(
            'Other linked reports',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      );
      for (final e in remaining) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: HandoverEventCard(event: e, frozen: frozen),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class HandoverEventCard extends StatelessWidget {
  final CareEvent event;
  final bool frozen, compact;
  const HandoverEventCard({
    super.key,
    required this.event,
    required this.frozen,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(event.priority);
    final statusColor = switch (event.status) {
      EventStatus.unhandled => const Color(0xff9a691d),
      EventStatus.takenCharge => const Color(0xff38758c),
      EventStatus.closed => const Color(0xff358064),
    };
    return Material(
      key: ValueKey('handover-report-${event.id}${compact ? '-compact' : ''}'),
      color: color.withValues(alpha: compact ? .025 : .045),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: color.withValues(alpha: .19)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/event/${event.id}'),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      eventIcon(event.type),
                      size: compact ? 18 : 22,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${event.type.label} · ${event.residentId ?? event.subject}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 12 : 14,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            StatusPill(
                              label: '${event.priority.label} priority',
                              color: color,
                            ),
                            StatusPill(
                              label: event.status.label,
                              color: statusColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, size: 19, color: muted),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 13),
                Wrap(
                  spacing: 14,
                  runSpacing: 7,
                  children: [
                    _Fact(icon: Icons.place_outlined, text: event.place),
                    _Fact(
                      icon: Icons.schedule,
                      text:
                          '${formatDate(event.occurredAt)} · ${formatTime(event.occurredAt)}',
                    ),
                  ],
                ),
                if (event.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    event.notes,
                    style: const TextStyle(fontSize: 13, height: 1.65),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 7,
                  children: [
                    Text(
                      frozen
                          ? 'Status preserved at signature'
                          : 'Current report status',
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                    const Text(
                      'Open report →',
                      style: TextStyle(
                        color: teal,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Fact({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: muted),
      const SizedBox(width: 5),
      Flexible(
        child: Text(text, style: const TextStyle(fontSize: 11, color: muted)),
      ),
    ],
  );
}
