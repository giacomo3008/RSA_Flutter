import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../shared/ui.dart';
import 'shift_attendance_card.dart';
export 'role_workspaces.dart'
    show CoordinationScreen, ManagementScreen, AdminScreen;

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
        const ShiftAttendanceCard(),
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
                                      staff.rolesLabelForWard(r.activeWard.id),
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

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    children: [
      PageHeading(
        title: tr(context, 'more'),
        subtitle: tr(context, 'moreSubtitle'),
      ),
      for (final item in [
        (Icons.menu_book_outlined, 'wardDiary', '/diary'),
        (Icons.swap_horiz, 'shiftHandover', '/handover'),
        (Icons.badge_outlined, 'myShift', '/shift'),
        (Icons.document_scanner_outlined, 'documentReview', '/documents'),
        if (ref.watch(rsaRepositoryProvider).can(Capability.coordination))
          (Icons.people_outline, 'coordination', '/coordination'),
        if (ref.watch(rsaRepositoryProvider).can(Capability.clinicalValidation))
          (Icons.verified_outlined, 'clinicalWorkspace', '/clinical'),
        (Icons.manage_accounts_outlined, 'accountSettings', '/settings'),
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
                  subtitle: Text(
                    '${s.rolesLabelForWard(r.activeWard.id)} · ${s.skills.join(', ')}',
                  ),
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
