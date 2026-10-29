import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models.dart';
import '../core/providers.dart';
import '../core/repository.dart';
import '../shared/ui.dart';

/// The coordinator leads the ward's operational work, without granting access.
class CoordinationScreen extends ConsumerWidget {
  const CoordinationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(rsaRepositoryProvider);
    if (!r.can(Capability.coordination)) return const _RoleAccessDenied();
    final people = r.staff;
    final open = r.events.where((e) => e.status != EventStatus.closed).toList();
    final unhandled = open
        .where((e) => e.status == EventStatus.unhandled)
        .toList();
    final shift = r.currentShift;
    final group = r.conversations
        .where((c) => c.kind == ConversationKind.ward)
        .firstOrNull;
    return ListView(
      children: [
        PageHeading(
          title: 'Ward coordination',
          subtitle:
              '${r.activeWard.name} · ${shift.label} · ${formatTime(shift.startsAt)}–${formatTime(shift.endsAt)}',
        ),
        const SectionCard(
          child: _RoleNotice(
            icon: Icons.supervisor_account_outlined,
            title: 'Ward operational lead',
            text:
                'Coordinate attendance, availability, skills and follow-up within this ward. Account permissions and access to other wards are managed by the system administrator.',
          ),
        ),
        const SizedBox(height: 20),
        _RoleMetrics(
          values: [
            (
              'On duty',
              people.where((s) => s.onDuty).length,
              Icons.people_outline,
            ),
            (
              'Available',
              people
                  .where(
                    (s) => s.onDuty && s.availability == Availability.available,
                  )
                  .length,
              Icons.check_circle_outline,
            ),
            (
              'Not taken charge',
              unhandled.length,
              Icons.assignment_late_outlined,
            ),
            (
              'High priority open',
              open.where((e) => e.priority == Priority.high).length,
              Icons.priority_high,
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _RoleSectionTitle('Open work requiring attention'),
              const SizedBox(height: 12),
              if (unhandled.isEmpty)
                const Text(
                  'All open reports have an assigned responsible person.',
                )
              else
                for (final event in unhandled)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      eventIcon(event.type),
                      color: priorityColor(event.priority),
                    ),
                    title: Text(
                      '${event.type.label} · ${event.residentId ?? event.subject}',
                    ),
                    subtitle: Text(
                      '${event.priority.label} priority · ${formatTime(event.occurredAt)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/event/${event.id}'),
                  ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/inbox'),
                icon: const Icon(Icons.inbox_outlined),
                label: const Text('Open ward inbox'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _RoleSectionTitle('Shift team and workload'),
              const SizedBox(height: 8),
              const Text(
                'Recorded presence, availability and skills for the current ward. Open workload counts reports explicitly taken charge of.',
              ),
              const SizedBox(height: 12),
              for (final person in people)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(person.initials),
                  title: Text(person.name),
                  subtitle: Text(
                    '${_rolesInWard(person, r.activeWard.id)} · ${person.onDuty ? person.availability.label : 'Off duty'}\n${person.skills.join(', ')}\n${open.where((e) => e.claimedBy == person.id).length} open reports taken charge of',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Manage attendance and skills',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          _StaffOperationsDialog(repository: r, person: person),
                    ),
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
              const _RoleSectionTitle('Ward group and handover'),
              const SizedBox(height: 12),
              Text(
                '${r.activeWard.name} · ${people.length} authorized care team members',
              ),
              const SizedBox(height: 8),
              const Text(
                'The ward conversation follows authorized ward membership. Private conversations remain private to their participants.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: group == null
                        ? null
                        : () => context.go('/chat/${group.id}'),
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('Open ward conversation'),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/handover'),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Review shift handover'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
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
    if (!r.can(Capability.management)) return const _RoleAccessDenied();
    final wards = r.wards
        .where((w) => r.currentUser.can(Capability.management, w.id))
        .toList();
    final counts = r.aggregateCounts(wardId: wardId, date: date);
    return ListView(
      children: [
        const PageHeading(
          title: 'Medical management',
          subtitle: 'Operational indicators across your authorized wards.',
        ),
        const SectionCard(
          child: _RoleNotice(
            icon: Icons.bar_chart_outlined,
            title: 'Aggregate access',
            text:
                'These indicators do not grant access to resident records, private conversations or clinical documents. Clinical access requires a separate ward assignment.',
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<String>(
                initialValue: wardId ?? 'all',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ward scope'),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All authorized wards'),
                  ),
                  for (final ward in wards)
                    DropdownMenuItem(value: ward.id, child: Text(ward.name)),
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
                  setState(
                    () => date = DateTime.utc(
                      selected.year,
                      selected.month,
                      selected.day,
                      12,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.date_range_outlined),
              label: Text(date == null ? 'All dates' : formatDate(date!)),
            ),
            if (date != null)
              IconButton(
                tooltip: 'Clear date filter',
                onPressed: () => setState(() => date = null),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _RoleMetrics(
          values: [
            (
              'Reported events',
              counts['events'] ?? 0,
              Icons.description_outlined,
            ),
            (
              'Not taken charge',
              counts['unhandled'] ?? 0,
              Icons.assignment_late_outlined,
            ),
            ('High priority', counts['high'] ?? 0, Icons.priority_high),
            ('Closed', counts['closed'] ?? 0, Icons.task_alt),
            ('Staff on duty now', counts['onDuty'] ?? 0, Icons.people_outline),
          ],
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _RoleSectionTitle('Ward configuration'),
              const SizedBox(height: 8),
              const Text(
                'Maintain the display name of wards within your management scope.',
              ),
              for (final ward in wards)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.apartment_outlined, color: teal),
                  title: Text(ward.name),
                  subtitle: const Text(
                    'Authorized aggregate and configuration scope',
                  ),
                  trailing: IconButton(
                    tooltip: 'Edit ward name',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          _WardNameDialog(repository: r, ward: ward),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(rsaRepositoryProvider);
    if (!r.can(Capability.administration)) return const _RoleAccessDenied();
    return ListView(
      children: [
        const PageHeading(
          title: 'System administration',
          subtitle:
              'Manage ward access, routing policy and technical audit metadata.',
        ),
        const SectionCard(
          child: _RoleNotice(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Technical administration',
            text:
                'Administration does not provide clinical record access. Grant only the professional roles and wards authorized for each account.',
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _RoleSectionTitle('Accounts and ward roles'),
              const SizedBox(height: 8),
              const Text(
                'One account may hold several professional roles, each assigned explicitly to a ward.',
              ),
              const SizedBox(height: 12),
              for (final person in r.staff)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(person.initials),
                  title: Text(person.name),
                  subtitle: Text(
                    person.assignments
                        .map(
                          (a) =>
                              '${r.wards.where((w) => w.id == a.wardId).firstOrNull?.name ?? a.wardId} · ${a.role.label}',
                        )
                        .join('\n'),
                  ),
                  trailing: IconButton(
                    tooltip: 'Edit ward role assignments',
                    icon: const Icon(Icons.manage_accounts_outlined),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          _AssignmentsDialog(repository: r, person: person),
                    ),
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
              const _RoleSectionTitle('Notification routing'),
              const SizedBox(height: 8),
              const Text(
                'Facility alert timings apply to the configured priority routing rules.',
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.priority_high,
                  color: Color(0xffb54345),
                ),
                title: const Text('High priority'),
                subtitle: Text(
                  'Eligible on-duty nurses and present coordinator. Escalation after ${r.highTimeoutMinutes} minutes if not taken charge of.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.notifications_none,
                  color: Color(0xff9a691d),
                ),
                title: const Text('Medium priority'),
                subtitle: Text(
                  'Quiet alert to available on-duty nurses. Reminder after ${r.mediumReminderMinutes} minutes; coordinator escalation after ${r.mediumEscalationMinutes} minutes.',
                ),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.menu_book_outlined, color: teal),
                title: Text('Low priority'),
                subtitle: Text(
                  'Recorded in the diary and available for handover. No immediate notification.',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _RoutingDialog(repository: r),
                ),
                icon: const Icon(Icons.tune),
                label: const Text('Edit alert timing'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoleSectionTitle('Service integrations'),
              SizedBox(height: 8),
              Text(
                'Service activation is managed through the deployment configuration.',
              ),
              _IntegrationRow(
                'Corporate SSO and MFA',
                'Awaiting identity provider configuration',
              ),
              _IntegrationRow(
                'Backend API and realtime delivery',
                'Awaiting service configuration',
              ),
              _IntegrationRow(
                'Push notifications',
                'Awaiting server and device registration',
              ),
              _IntegrationRow(
                'AI and document extraction',
                'Awaiting approved service configuration',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _RoleSectionTitle('Audit metadata'),
              const SizedBox(height: 8),
              const Text(
                'Actions, actor identifiers, record references and fingerprints. Clinical text is excluded from this view.',
              ),
              for (final entry in r.audit.take(30))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history, size: 20, color: muted),
                  title: Text(entry.action),
                  subtitle: SelectableText(
                    '${entry.actorId} · ${entry.recordId} · ${formatDate(entry.createdAt)} ${formatTime(entry.createdAt)}\n${entry.fingerprint}',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

String _rolesInWard(StaffMember member, String wardId) =>
    member.rolesLabelForWard(wardId);

class _RoleAccessDenied extends StatelessWidget {
  const _RoleAccessDenied();
  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.lock_outline,
    title: 'Access restricted',
    message: 'This workspace requires an authorized role for the current ward.',
  );
}

class _RoleSectionTitle extends StatelessWidget {
  final String text;
  const _RoleSectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
  );
}

class _RoleNotice extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const _RoleNotice({
    required this.icon,
    required this.title,
    required this.text,
  });
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: teal),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(color: muted)),
          ],
        ),
      ),
    ],
  );
}

class _RoleMetrics extends StatelessWidget {
  final List<(String, int, IconData)> values;
  const _RoleMetrics({required this.values});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final value in values)
          SizedBox(
            width: constraints.maxWidth < 460
                ? constraints.maxWidth
                : (constraints.maxWidth - 16) / 2,
            child: SectionCard(
              child: Row(
                children: [
                  Icon(value.$3, color: teal),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${value.$2}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(value.$1, style: const TextStyle(color: muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _StaffOperationsDialog extends StatefulWidget {
  final RsaRepository repository;
  final StaffMember person;
  const _StaffOperationsDialog({
    required this.repository,
    required this.person,
  });
  @override
  State<_StaffOperationsDialog> createState() => _StaffOperationsDialogState();
}

class _StaffOperationsDialogState extends State<_StaffOperationsDialog> {
  late final TextEditingController skills = TextEditingController(
    text: widget.person.skills.join(', '),
  );
  late bool present = widget.person.onDuty;
  late Availability availability = widget.person.availability;
  bool saving = false;
  @override
  void dispose() {
    skills.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.repository.updateStaff(
        widget.person.id,
        onDuty: present,
        availability: availability,
        skills: skills.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        showFailure(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.person.name),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Present on current shift'),
              value: present,
              onChanged: saving
                  ? null
                  : (value) => setState(() => present = value),
            ),
            DropdownButtonFormField<Availability>(
              isExpanded: true,
              initialValue: availability,
              decoration: const InputDecoration(labelText: 'Availability'),
              items: [
                for (final value in Availability.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: saving
                  ? null
                  : (value) => setState(() => availability = value!),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: skills,
              enabled: !saving,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Skills',
                helperText: 'Separate skills with commas',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Saving…' : 'Save changes'),
      ),
    ],
  );
}

class _WardNameDialog extends StatefulWidget {
  final RsaRepository repository;
  final Ward ward;
  const _WardNameDialog({required this.repository, required this.ward});
  @override
  State<_WardNameDialog> createState() => _WardNameDialogState();
}

class _WardNameDialogState extends State<_WardNameDialog> {
  late final name = TextEditingController(text: widget.ward.name);
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      setState(() => error = 'Enter a ward name.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.renameWard(widget.ward.id, name.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ward configuration'),
    content: SizedBox(
      width: 380,
      child: TextField(
        controller: name,
        enabled: !saving,
        maxLength: 100,
        decoration: InputDecoration(
          labelText: 'Ward display name',
          errorText: error,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Saving…' : 'Save changes'),
      ),
    ],
  );
}

class _AssignmentsDialog extends StatefulWidget {
  final RsaRepository repository;
  final StaffMember person;
  const _AssignmentsDialog({required this.repository, required this.person});
  @override
  State<_AssignmentsDialog> createState() => _AssignmentsDialogState();
}

class _AssignmentsDialogState extends State<_AssignmentsDialog> {
  late final selected = widget.person.assignments
      .map((a) => '${a.wardId}:${a.role.name}')
      .toSet();
  bool saving = false;
  String? error;
  Future<void> save() async {
    if (selected.isEmpty) {
      setState(() => error = 'Assign at least one role and ward.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final assignments = [
      for (final ward in widget.repository.wards)
        for (final role in Role.values)
          if (selected.contains('${ward.id}:${role.name}'))
            WardRoleAssignment(wardId: ward.id, role: role),
    ];
    try {
      await widget.repository.updateAssignments(widget.person.id, assignments);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Ward roles · ${widget.person.name}'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Each selected role applies only to its ward. Technical administration and aggregate management do not grant clinical access.',
            ),
            const SizedBox(height: 12),
            for (final ward in widget.repository.wards) ...[
              const Divider(),
              Text(
                ward.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              for (final role in Role.values)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(role.label),
                  value: selected.contains('${ward.id}:${role.name}'),
                  onChanged: saving
                      ? null
                      : (value) => setState(() {
                          final key = '${ward.id}:${role.name}';
                          if (value == true) {
                            selected.add(key);
                          } else {
                            selected.remove(key);
                          }
                        }),
                ),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Saving…' : 'Save assignments'),
      ),
    ],
  );
}

class _RoutingDialog extends StatefulWidget {
  final RsaRepository repository;
  const _RoutingDialog({required this.repository});
  @override
  State<_RoutingDialog> createState() => _RoutingDialogState();
}

class _RoutingDialogState extends State<_RoutingDialog> {
  late final high = TextEditingController(
    text: '${widget.repository.highTimeoutMinutes}',
  );
  late final reminder = TextEditingController(
    text: '${widget.repository.mediumReminderMinutes}',
  );
  late final escalation = TextEditingController(
    text: '${widget.repository.mediumEscalationMinutes}',
  );
  bool saving = false;
  String? error;
  @override
  void dispose() {
    high.dispose();
    reminder.dispose();
    escalation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final highValue = int.tryParse(high.text),
        reminderValue = int.tryParse(reminder.text),
        escalationValue = int.tryParse(escalation.text);
    if (highValue == null ||
        reminderValue == null ||
        escalationValue == null ||
        highValue <= 0 ||
        reminderValue <= 0 ||
        escalationValue <= reminderValue) {
      setState(
        () => error =
            'Use positive whole minutes. Medium escalation must follow its reminder.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.configureRouting(
        highMinutes: highValue,
        reminderMinutes: reminderValue,
        escalationMinutes: escalationValue,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Facility alert timing'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Changes apply when notification deadlines are calculated. Already scheduled next deadlines remain recorded.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: high,
              enabled: !saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'High escalation · minutes',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reminder,
              enabled: !saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Medium reminder · minutes',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: escalation,
              enabled: !saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Medium escalation · minutes',
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Saving…' : 'Save policy'),
      ),
    ],
  );
}

class _IntegrationRow extends StatelessWidget {
  final String title, status;
  const _IntegrationRow(this.title, this.status);
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.settings_ethernet, color: muted),
    title: Text(title),
    subtitle: Text(status),
  );
}
