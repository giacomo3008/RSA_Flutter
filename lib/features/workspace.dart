import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../shared/ui.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(rsaRepositoryProvider);
    final active = r.inboxEvents
        .where((e) => e.status != EventStatus.closed)
        .toList();
    final high = active.where((e) => e.priority == Priority.high).length;
    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        PageHeading(
          title: tr(context, 'homeGreeting', {
            'name': r.currentUser.name.split(' ').first,
          }),
          subtitle: tr(context, 'homeSubtitle'),
          action: FilledButton.icon(
            onPressed: () => context.push('/report'),
            icon: const Icon(Icons.add, size: 19),
            label: Text(tr(context, 'reportEvent')),
          ),
        ),
        SectionCard(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wb_sunny_outlined, color: teal),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.activeWard.name} · ${r.currentShift.label}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${formatTime(r.currentShift.startsAt)} – ${formatTime(r.currentShift.endsAt)}  ·  ${formatDate(r.now)}',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
              StatusPill(
                label: tr(
                  context,
                  r.currentUser.onDuty ? 'checkedIn' : 'offDuty',
                ),
                icon: r.currentUser.onDuty
                    ? Icons.check_circle_outline
                    : Icons.schedule,
              ),
              OutlinedButton(
                onPressed: () => runAction(context, r.toggleAttendance),
                child: Text(
                  tr(context, r.currentUser.onDuty ? 'checkOut' : 'checkIn'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _Metric(
                width:
                    (c.maxWidth - (c.maxWidth > 700 ? 48 : 16)) /
                    (c.maxWidth > 700 ? 4 : 2),
                number:
                    '${active.where((e) => e.claimedBy == r.currentUser.id).length}',
                label: tr(context, 'assignedToYou'),
                icon: Icons.assignment_ind_outlined,
                color: teal,
              ),
              _Metric(
                width:
                    (c.maxWidth - (c.maxWidth > 700 ? 48 : 16)) /
                    (c.maxWidth > 700 ? 4 : 2),
                number:
                    '${active.where((e) => e.status == EventStatus.unhandled).length}',
                label: tr(context, 'unhandled'),
                icon: Icons.inbox_outlined,
                color: const Color(0xff9a691d),
              ),
              _Metric(
                width:
                    (c.maxWidth - (c.maxWidth > 700 ? 48 : 16)) /
                    (c.maxWidth > 700 ? 4 : 2),
                number: '$high',
                label: tr(context, 'highPriority'),
                icon: Icons.priority_high_rounded,
                color: const Color(0xffb54345),
              ),
              _Metric(
                width:
                    (c.maxWidth - (c.maxWidth > 700 ? 48 : 16)) /
                    (c.maxWidth > 700 ? 4 : 2),
                number: '${r.staff.where((s) => s.onDuty).length}',
                label: tr(context, 'onDutyNow'),
                icon: Icons.people_outline,
                color: const Color(0xff53718e),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, c) {
            final expanded = c.maxWidth > 900;
            final left = SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(
                    tr(context, 'needsAttention'),
                    tr(context, 'viewInbox'),
                    () => context.go('/inbox'),
                  ),
                  Text(
                    tr(context, 'attentionSubtitle'),
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (active.isEmpty)
                    EmptyState(
                      icon: Icons.task_alt,
                      title: tr(context, 'allCaughtUp'),
                    ),
                  for (final e in active.take(4)) ...[
                    EventTile(event: e, compact: true),
                    if (r.canClaim(e))
                      Padding(
                        padding: const EdgeInsets.only(left: 57, bottom: 12),
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              runAction(context, () => r.claimEvent(e.id)),
                          icon: const Icon(Icons.pan_tool_outlined, size: 16),
                          label: Text(tr(context, 'takeCharge')),
                        ),
                      ),
                    const Divider(),
                  ],
                ],
              ),
            );
            final right = Column(
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        tr(context, 'yourTeam'),
                        tr(context, 'viewShift'),
                        () => context.go('/shift'),
                      ),
                      const SizedBox(height: 12),
                      for (final staff
                          in r.staff.where((s) => s.onDuty).take(4))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Avatar(staff.initials, size: 36),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      staff.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      staff.role.label,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.circle,
                                size: 7,
                                color:
                                    staff.availability == Availability.available
                                    ? teal
                                    : const Color(0xffb17d32),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                staff.availability.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome_outlined, color: teal),
                      const SizedBox(height: 12),
                      Text(
                        tr(context, 'assistantTitle'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(context, 'assistantCardText'),
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => context.go(
                          '/chat/${r.conversations.where((c) => c.kind == ConversationKind.assistant).first.id}',
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: Text(tr(context, 'openAssistant')),
                      ),
                    ],
                  ),
                ),
              ],
            );
            return expanded
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: left),
                      const SizedBox(width: 22),
                      Expanded(flex: 4, child: right),
                    ],
                  )
                : Column(children: [left, const SizedBox(height: 18), right]);
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              SizedBox(
                width: c.maxWidth > 650 ? (c.maxWidth - 18) / 2 : c.maxWidth,
                child: _Shortcut(
                  icon: Icons.menu_book_outlined,
                  title: tr(context, 'wardDiary'),
                  subtitle: tr(context, 'diaryShortcutText'),
                  path: '/diary',
                ),
              ),
              SizedBox(
                width: c.maxWidth > 650 ? (c.maxWidth - 18) / 2 : c.maxWidth,
                child: _Shortcut(
                  icon: Icons.swap_horiz_rounded,
                  title: tr(context, 'shiftHandover'),
                  subtitle: r.handover.status.label,
                  path: '/handover',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          tr(context, 'demoFooter'),
          style: const TextStyle(color: muted, fontSize: 11),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title, link;
  final VoidCallback action;
  const _SectionTitle(this.title, this.link, this.action);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      TextButton(
        onPressed: action,
        child: Text(link, style: const TextStyle(fontSize: 11)),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  final double width;
  final String number, label;
  final IconData icon;
  final Color color;
  const _Metric({
    required this.width,
    required this.number,
    required this.label,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: SectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 21),
              const Spacer(),
              Text(
                number,
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, path;
  const _Shortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.go(path),
    borderRadius: BorderRadius.circular(18),
    child: SectionCard(
      child: Row(
        children: [
          Icon(icon, color: teal, size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, size: 18, color: teal),
        ],
      ),
    ),
  );
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      PageHeading(
        title: tr(context, 'more'),
        subtitle: tr(context, 'moreSubtitle'),
      ),
      for (final item in [
        (Icons.menu_book_outlined, 'wardDiary', '/diary'),
        (Icons.swap_horiz, 'shiftHandover', '/handover'),
        (Icons.badge_outlined, 'myShift', '/shift'),
        (Icons.document_scanner_outlined, 'documentReview', '/ocr'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _Shortcut(
            icon: item.$1,
            title: tr(context, item.$2),
            subtitle: tr(context, 'openWorkspace'),
            path: item.$3,
          ),
        ),
    ],
  );
}

class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(rsaRepositoryProvider);
    return ListView(
      children: [
        PageHeading(
          title: tr(context, 'myShift'),
          subtitle: '${r.activeWard.name} · ${formatDate(r.now)}',
        ),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.currentShift.label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatTime(r.currentShift.startsAt)}–${formatTime(r.currentShift.endsAt)} · Europe/Rome',
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => runAction(context, r.toggleAttendance),
                    icon: const Icon(Icons.login),
                    label: Text(
                      tr(
                        context,
                        r.currentUser.onDuty ? 'checkOut' : 'checkIn',
                      ),
                    ),
                  ),
                  for (final a in Availability.values)
                    ChoiceChip(
                      label: Text(a.label),
                      selected: r.currentUser.availability == a,
                      onSelected: (_) =>
                          runAction(context, () => r.setAvailability(a)),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                tr(context, 'attendanceHint'),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'teamCoverage'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              for (final s in r.staff)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(s.initials),
                  title: Text(s.name),
                  subtitle: Text('${s.role.label} · ${s.skills.join(', ')}'),
                  trailing: StatusPill(
                    label: s.onDuty
                        ? s.availability.label
                        : tr(context, 'offDuty'),
                    color: s.onDuty ? teal : muted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class HandoverScreen extends ConsumerStatefulWidget {
  const HandoverScreen({super.key});
  @override
  ConsumerState<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends ConsumerState<HandoverScreen> {
  final contribution = TextEditingController();
  @override
  void dispose() {
    contribution.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(rsaRepositoryProvider);
    final h = r.handover;
    final signed =
        h.status == HandoverStatus.signed ||
        h.status == HandoverStatus.acknowledged;
    final events = r.events
        .where((e) => h.sourceEventIds.contains(e.id))
        .toList();
    return ListView(
      children: [
        PageHeading(
          title: tr(context, 'shiftHandover'),
          subtitle: '${r.activeWard.name} · ${h.shift}',
          action: StatusPill(label: h.status.label, icon: Icons.swap_horiz),
        ),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  StatusPill(
                    label: tr(context, 'versionLabel', {
                      'number': '${h.version}',
                    }),
                  ),
                  if (h.reviewedBy != null)
                    StatusPill(
                      label: tr(context, 'reviewedBy', {
                        'name':
                            r.staffById(h.reviewedBy!)?.name ?? h.reviewedBy!,
                      }),
                      icon: Icons.fact_check_outlined,
                    ),
                  if (h.validatedBy != null)
                    StatusPill(
                      label: tr(context, 'validatedBy', {
                        'name':
                            r.staffById(h.validatedBy!)?.name ?? h.validatedBy!,
                      }),
                      icon: Icons.verified_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                tr(context, 'importantEvents'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, 'handoverEvidenceHint'),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              for (final e in events) EventTile(event: e, compact: true),
              if (events.isEmpty)
                EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: tr(context, 'noSources'),
                ),
              const Divider(),
              const SizedBox(height: 18),
              Text(
                tr(context, 'openFollowUps'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              for (final e in events.where(
                (e) => e.status != EventStatus.closed,
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    eventIcon(e.type),
                    color: priorityColor(e.priority),
                  ),
                  title: Text('${e.type.label} · ${e.residentId ?? e.subject}'),
                  subtitle: Text(e.status.label),
                  trailing: const Icon(Icons.arrow_outward, size: 18),
                  onTap: () => context.go('/event/${e.id}'),
                ),
              const SizedBox(height: 14),
              if (h.contributions.isNotEmpty) ...[
                Text(
                  tr(context, 'staffContributions'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                for (final v in h.contributions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(v.text),
                    subtitle: Text(
                      '${r.staffById(v.authorId)?.name ?? v.authorId} · ${formatTime(v.createdAt)}',
                    ),
                  ),
              ],
              if (h.versions.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(tr(context, 'versionHistory')),
                  children: [
                    for (final v in h.versions)
                      ListTile(
                        title: Text(v.text),
                        subtitle: Text(
                          'v${v.version} · ${formatTime(v.createdAt)} · ${r.staffById(v.authorId)?.name ?? v.authorId}',
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              if (!signed)
                TextField(
                  controller: contribution,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: tr(context, 'personalShiftSummary'),
                  ),
                ),
              if (!signed)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => runAction(context, () async {
                      await r.contributeSummary(contribution.text);
                      contribution.clear();
                    }),
                    icon: const Icon(Icons.add_comment_outlined),
                    label: Text(tr(context, 'addContribution')),
                  ),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (!signed && r.can(Capability.coordination))
                    OutlinedButton.icon(
                      onPressed: () => runAction(context, r.reviewHandover),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(tr(context, 'markReviewed')),
                    ),
                  if (!signed && r.can(Capability.clinicalValidation))
                    OutlinedButton.icon(
                      onPressed: () => runAction(context, r.validateHandover),
                      icon: const Icon(Icons.verified_outlined),
                      label: Text(tr(context, 'clinicalValidation')),
                    ),
                  if (!signed && r.can(Capability.signHandover))
                    FilledButton.icon(
                      onPressed: () => runAction(context, r.signHandover),
                      icon: const Icon(Icons.draw_outlined),
                      label: Text(tr(context, 'signOutgoing')),
                    ),
                  if (signed &&
                      h.incomingStaffIds.contains(r.currentUser.id) &&
                      !h.acknowledgements.containsKey(r.currentUser.id))
                    FilledButton.icon(
                      onPressed: () =>
                          runAction(context, r.acknowledgeHandover),
                      icon: const Icon(Icons.check),
                      label: Text(tr(context, 'acknowledgeHandover')),
                    ),
                ],
              ),
              if (signed) ...[
                const SizedBox(height: 16),
                Text(
                  tr(context, 'signedBy', {
                    'name': r.staffById(h.signedBy ?? '')?.name ?? '—',
                    'time': h.signedAt == null ? '—' : formatTime(h.signedAt!),
                  }),
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(context, 'acknowledgements'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                for (final id in h.incomingStaffIds)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      h.acknowledgements.containsKey(id)
                          ? Icons.check_circle_outline
                          : Icons.schedule,
                      color: teal,
                    ),
                    title: Text(r.staffById(id)?.name ?? id),
                    subtitle: Text(
                      h.acknowledgements[id] == null
                          ? tr(context, 'awaitingAcknowledgement')
                          : formatTime(DateTime.parse(h.acknowledgements[id]!)),
                    ),
                  ),
                OutlinedButton(
                  onPressed: () async {
                    final note = await _textDialog(
                      context,
                      'amendHandover',
                      'amendmentText',
                    );
                    if (note != null && context.mounted) {
                      await runAction(context, () => r.amendHandover(note));
                    }
                  },
                  child: Text(tr(context, 'addAmendment')),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                tr(context, 'demoSignatureNote'),
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<String?> _textDialog(
  BuildContext context,
  String title,
  String label,
) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tr(c, title)),
      content: TextField(
        controller: controller,
        minLines: 2,
        maxLines: 5,
        decoration: InputDecoration(labelText: tr(c, label)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text(tr(c, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, controller.text),
          child: Text(tr(c, 'save')),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});
  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  final edits = <String, TextEditingController>{};
  @override
  void dispose() {
    for (final e in edits.values) {
      e.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(rsaRepositoryProvider);
    return ListView(
      children: [
        PageHeading(
          title: tr(context, 'documentReview'),
          subtitle: tr(context, 'ocrSubtitle'),
        ),
        for (final item in r.ocrItems)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(
                  label: tr(
                    context,
                    item.reviewedAt == null ? 'needsReview' : 'reviewed',
                  ),
                  icon: Icons.document_scanner_outlined,
                ),
                const SizedBox(height: 20),
                Text(
                  tr(context, 'syntheticDocument'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: const Color(0xfffcfaf4),
                    border: Border.all(color: const Color(0xffe7e0ce)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.description_outlined, color: muted),
                      const SizedBox(height: 14),
                      Text(
                        item.originalText,
                        style: const TextStyle(height: 1.8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr(context, 'uncertainValue'),
                        style: const TextStyle(
                          color: Color(0xff9a691d),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: edits.putIfAbsent(
                    item.id,
                    () => TextEditingController(
                      text: item.correctedText ?? item.originalText,
                    ),
                  ),
                  minLines: 4,
                  maxLines: 8,
                  readOnly: item.reviewedAt != null,
                  decoration: InputDecoration(
                    labelText: tr(context, 'extractedText'),
                  ),
                ),
                const SizedBox(height: 16),
                if (item.reviewedAt == null)
                  FilledButton.icon(
                    onPressed: () => runAction(
                      context,
                      () => r.confirmOcr(item.id, edits[item.id]!.text),
                    ),
                    icon: const Icon(Icons.check),
                    label: Text(tr(context, 'confirmExtracted')),
                  ),
                if (item.reviewedAt != null)
                  Text(
                    tr(context, 'reviewedBy', {
                      'name':
                          r.staffById(item.reviewedBy!)?.name ??
                          item.reviewedBy!,
                    }),
                  ),
                const SizedBox(height: 12),
                Text(
                  tr(context, 'ocrValidationNote'),
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class CoordinationScreen extends ConsumerWidget {
  const CoordinationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(rsaRepositoryProvider);
    return ListView(
      children: [
        PageHeading(
          title: tr(context, 'wardOverview'),
          subtitle: r.activeWard.name,
        ),
        _Shortcut(
          icon: Icons.warning_amber_outlined,
          title: tr(context, 'unhandledNotifications'),
          subtitle: tr(context, 'reviewOperationalItems'),
          path: '/inbox',
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'presentStaffSkills'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              for (final s in r.staff)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(s.initials),
                  title: Text(s.name),
                  subtitle: Text(
                    '${s.role.label} · ${s.onDuty ? s.availability.label : tr(context, 'offDuty')} · ${s.skills.join(', ')}',
                  ),
                  trailing: IconButton(
                    tooltip: tr(context, 'manageAttendance'),
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      var present = s.onDuty;
                      var availability = s.availability;
                      final skills = TextEditingController(
                        text: s.skills.join(', '),
                      );
                      final save = await showDialog<bool>(
                        context: context,
                        builder: (c) => StatefulBuilder(
                          builder: (c, set) => AlertDialog(
                            title: Text(s.name),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(tr(c, 'presentOnShift')),
                                    value: present,
                                    onChanged: (v) => set(() => present = v),
                                  ),
                                  DropdownButtonFormField<Availability>(
                                    isExpanded: true,
                                    initialValue: availability,
                                    items: [
                                      for (final a in Availability.values)
                                        DropdownMenuItem(
                                          value: a,
                                          child: Text(a.label),
                                        ),
                                    ],
                                    onChanged: (a) =>
                                        set(() => availability = a!),
                                  ),
                                  const SizedBox(height: 20),
                                  TextField(
                                    controller: skills,
                                    decoration: InputDecoration(
                                      labelText: tr(c, 'staffSkills'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: Text(tr(c, 'cancel')),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: Text(tr(c, 'save')),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (save == true && context.mounted) {
                        await runAction(
                          context,
                          () => r.updateStaff(
                            s.id,
                            onDuty: present,
                            availability: availability,
                            skills: skills.text
                                .split(',')
                                .map((x) => x.trim())
                                .where((x) => x.isNotEmpty)
                                .toList(),
                          ),
                        );
                      }
                      skills.dispose();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Shortcut(
          icon: Icons.swap_horiz,
          title: tr(context, 'handoverCompletion'),
          subtitle: r.handover.status.label,
          path: '/handover',
        ),
      ],
    );
  }
}

class ManagementScreen extends ConsumerStatefulWidget {
  const ManagementScreen({super.key});
  @override
  ConsumerState<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends ConsumerState<ManagementScreen> {
  String? wardId;
  DateTime? date;
  @override
  Widget build(BuildContext context) {
    final r = ref.watch(rsaRepositoryProvider);
    final counts = r.aggregateCounts(wardId: wardId, date: date);
    return ListView(
      children: [
        PageHeading(
          title: tr(context, 'operationsOverview'),
          subtitle: tr(context, 'aggregateOnly'),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: wardId ?? 'all',
                decoration: InputDecoration(
                  labelText: tr(context, 'wardScope'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(tr(context, 'allWards')),
                  ),
                  for (final w in r.wards)
                    DropdownMenuItem(value: w.id, child: Text(w.name)),
                ],
                onChanged: (id) =>
                    setState(() => wardId = id == 'all' ? null : id),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: date ?? facilityTime(r.now),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (selected != null && mounted) {
                  setState(() => date = selected);
                }
              },
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                date == null ? tr(context, 'allDates') : formatDate(date!),
              ),
            ),
            if (date != null)
              IconButton(
                tooltip: tr(context, 'clearDateFilter'),
                onPressed: () => setState(() => date = null),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final e in counts.entries)
              SizedBox(
                width: 220,
                child: SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.value}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr(context, e.key),
                        style: const TextStyle(color: muted),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'wardScope'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              for (final w in r.wards)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.apartment_outlined),
                  title: Text(w.name),
                  subtitle: Text(tr(context, 'aggregateScope')),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(rsaRepositoryProvider);
    return ListView(
      children: [
        PageHeading(
          title: tr(context, 'administration'),
          subtitle: tr(context, 'technicalConsole'),
        ),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'accountsAssignments'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              for (final s in r.staff)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(s.initials),
                  title: Text(s.name),
                  subtitle: Text('${s.role.label} · ${s.wardIds.join(', ')}'),
                  trailing: IconButton(
                    tooltip: tr(context, 'editAssignment'),
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      Role role = s.role;
                      final wards = s.wardIds.toSet();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (c) => StatefulBuilder(
                          builder: (c, set) => AlertDialog(
                            title: Text(tr(c, 'editAssignment')),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DropdownButtonFormField<Role>(
                                    isExpanded: true,
                                    initialValue: role,
                                    items: [
                                      for (final x in Role.values)
                                        DropdownMenuItem(
                                          value: x,
                                          child: Text(x.label),
                                        ),
                                    ],
                                    onChanged: (x) => set(() => role = x!),
                                  ),
                                  for (final w in r.wards)
                                    CheckboxListTile(
                                      title: Text(w.name),
                                      value: wards.contains(w.id),
                                      onChanged: (value) => set(
                                        () => value!
                                            ? wards.add(w.id)
                                            : wards.remove(w.id),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: Text(tr(c, 'cancel')),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: Text(tr(c, 'save')),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await runAction(
                          context,
                          () => r.updateStaff(
                            s.id,
                            role: role,
                            wardIds: wards.toList(),
                          ),
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'integrations'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              for (final key in [
                'corporateSso',
                'backendApi',
                'remotePush',
                'langGraph',
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(context, key)),
                  trailing: StatusPill(
                    label: tr(context, 'notConnected'),
                    color: muted,
                  ),
                ),
              const Divider(),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(tr(context, 'routingRules')),
                children: [
                  ListTile(title: Text(tr(context, 'highRouting'))),
                  ListTile(title: Text(tr(context, 'mediumRouting'))),
                  ListTile(title: Text(tr(context, 'lowRouting'))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'auditMetadata'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              for (final a in r.audit.take(30))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(a.action),
                  subtitle: Text(
                    '${a.actorId} · ${a.recordId} · ${formatTime(a.createdAt)}',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(rsaRepositoryProvider);
    return ListView(
      children: [
        PageHeading(
          title: tr(context, 'demoControls'),
          subtitle: tr(context, 'demoControlsSubtitle'),
        ),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: r.currentUser.id,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr(context, 'demoPersona'),
                ),
                items: [
                  for (final p in r.personas)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.name} · ${p.role.label}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) =>
                    runAction(context, () => r.switchPersona(id!)),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: r.activeWard.id,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr(context, 'wardScope'),
                ),
                items: [
                  for (final w in r.wards)
                    DropdownMenuItem(value: w.id, child: Text(w.name)),
                ],
                onChanged: (id) => runAction(context, () => r.selectWard(id!)),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr(context, 'demoConnectivity')),
                subtitle: Text(tr(context, r.online ? 'online' : 'offline')),
                value: r.online,
                onChanged: (value) =>
                    runAction(context, () => r.setOnline(value)),
              ),
              const Divider(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => runAction(
                      context,
                      () => r.advanceTime(const Duration(minutes: 10)),
                    ),
                    icon: const Icon(Icons.update),
                    label: Text(tr(context, 'advanceTime')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(tr(c, 'resetDemo')),
                          content: Text(tr(c, 'resetDemoWarning')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: Text(tr(c, 'cancel')),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: Text(tr(c, 'resetDemo')),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await runAction(context, r.reset);
                      }
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: Text(tr(context, 'resetDemo')),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                tr(context, 'demoTimingNote'),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, 'storageScopeNote'),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
