import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../core/models.dart';
import '../core/providers.dart';

const ink = Color(0xff203638);
const teal = Color(0xff17766d);
const muted = Color(0xff71817f);
const canvas = Color(0xfff5f7f6);
Map<String, dynamic> _translations = {};
Future<void> loadTranslations() async {
  tzdata.initializeTimeZones();
  _translations =
      jsonDecode(await rootBundle.loadString('lib/l10n/app_en.arb'))
          as Map<String, dynamic>;
}

String tr(
  BuildContext context,
  String key, [
  Map<String, String> args = const {},
]) {
  var value = _translations[key]?.toString() ?? key;
  for (final entry in args.entries) {
    value = value.replaceAll('{${entry.key}}', entry.value);
  }
  return value;
}

tz.TZDateTime facilityTime(DateTime instant) =>
    tz.TZDateTime.from(instant.toUtc(), tz.getLocation('Europe/Rome'));
String formatTime(DateTime instant) =>
    DateFormat.Hm('en_GB').format(facilityTime(instant));
String formatDate(DateTime instant) =>
    DateFormat('EEE, d MMM', 'en_GB').format(facilityTime(instant));
Color priorityColor(Priority p) => switch (p) {
  Priority.high => const Color(0xffb54345),
  Priority.medium => const Color(0xff9a691d),
  Priority.low => const Color(0xff358064),
};
IconData eventIcon(EventType t) => switch (t) {
  EventType.fall => Icons.personal_injury_outlined,
  EventType.health => Icons.favorite_border,
  EventType.wandering => Icons.directions_walk,
  EventType.agitation => Icons.waves_outlined,
  EventType.refusal => Icons.do_not_disturb_alt_outlined,
  EventType.skin => Icons.healing_outlined,
  EventType.safety => Icons.health_and_safety_outlined,
  EventType.hygiene => Icons.water_drop_outlined,
};
void showFailure(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.toString().replaceFirst('Exception: ', '')),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> runAction(
  BuildContext context,
  Future<dynamic> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) showFailure(context, e);
  }
}

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const SectionCard({super.key, required this.child, this.padding});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xffe2e9e5)),
    ),
    child: Padding(padding: padding ?? const EdgeInsets.all(24), child: child),
  );
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  const StatusPill({super.key, required this.label, this.color, this.icon});
  @override
  Widget build(BuildContext context) {
    final c = color ?? teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: LayoutBuilder(
      builder: (context, c) => Wrap(
        spacing: 24,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: c.maxWidth > 700 ? c.maxWidth - 240 : c.maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: muted, fontSize: 14),
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 34, color: muted),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
        ],
      ],
    ),
  );
}

class EventTile extends ConsumerWidget {
  final CareEvent event;
  final bool compact;
  const EventTile({super.key, required this.event, this.compact = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(rsaRepositoryProvider);
    final e = event;
    final resident = e.residentId == null
        ? null
        : repo.residentById(e.residentId!);
    return InkWell(
      onTap: () => context.go('/event/${e.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 12 : 17,
          horizontal: 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: priorityColor(e.priority).withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                eventIcon(e.type),
                color: priorityColor(e.priority),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        e.type.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      StatusPill(
                        label: e.priority.label,
                        color: priorityColor(e.priority),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${resident?.name ?? e.subject} · ${e.place}',
                    style: const TextStyle(fontSize: 13, color: muted),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${formatTime(e.occurredAt)} · ${e.status.label}',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                  if (!compact && e.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      e.notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: muted),
          ],
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String initials;
  final double size;
  const Avatar(this.initials, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: size / 2,
    backgroundColor: const Color(0xffe7f0ec),
    child: Text(
      initials,
      style: TextStyle(
        color: teal,
        fontWeight: FontWeight.w800,
        fontSize: size * .32,
      ),
    ),
  );
}
