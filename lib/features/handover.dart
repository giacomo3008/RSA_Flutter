import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models.dart';
import '../core/providers.dart';
import '../core/repository.dart';
import '../shared/ui.dart';

/// A handover document is reviewed and signed independently of live event work.
class HandoverScreen extends ConsumerStatefulWidget {
  const HandoverScreen({super.key});

  @override
  ConsumerState<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends ConsumerState<HandoverScreen> {
  final _draft = TextEditingController();
  final _contribution = TextEditingController();
  bool _editing = false;
  bool _busy = false;
  String? _recordIdentity;
  int? _historicalVersion;

  @override
  void dispose() {
    _draft.dispose();
    _contribution.dispose();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() action, {String? message}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _prepare(RsaRepository r) async {
    if ((r.handover.draftText?.isNotEmpty ?? false) &&
        !await _confirm(
          'Prepare a new draft?',
          'This prepares a new draft from the linked reports and staff contributions. Your current text remains in version history. Review and validation will need to be repeated.',
          'Prepare draft',
        )) {
      return;
    }
    if (!mounted) return;
    await _act(
      r.prepareHandoverDraft,
      message: 'Draft prepared. Review the sources before signing.',
    );
  }

  Future<void> _amend(RsaRepository r) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => const _AmendmentDialog(),
    );
    if (note == null || !mounted) return;
    await _act(
      () => r.amendHandover(note),
      message: 'New draft version opened. The signed version is preserved.',
    );
  }

  Future<void> _assignIncoming(RsaRepository r) async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => _IncomingTeamDialog(
        wardId: r.activeWard.id,
        staff: r.staff
            .where((s) => s.can(Capability.acknowledge, r.activeWard.id))
            .toList(),
        selected: r.handover.incomingStaffIds,
      ),
    );
    if (selected == null || !mounted) return;
    await _act(() => r.assignHandoverIncomingStaff(selected));
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(rsaRepositoryProvider);
    final h = r.handover;
    final identity = '${h.id}:${h.version}';
    if (_recordIdentity != identity) {
      _recordIdentity = identity;
      _editing = false;
      _historicalVersion = null;
      _draft.text = r.handoverText(h);
    }
    final signed = h.signedBy != null;
    final canCoordinate = r.can(Capability.coordination);
    final canEdit = canCoordinate || r.can(Capability.clinicalValidation);
    final sources = r.events
        .where((e) => h.sourceEventIds.contains(e.id))
        .toList();
    final urgent = sources
        .where(
          (e) => e.priority == Priority.high && e.status != EventStatus.closed,
        )
        .toList();
    final versions = <int, RecordVersion>{};
    for (final v in h.versions) {
      final data = _versionData(v);
      if (data['signedBy'] != null || data['kind'] == 'signed') {
        versions[v.version] = v;
      }
    }
    final historical = _historicalVersion == null
        ? null
        : versions[_historicalVersion];
    final historicalData = historical == null ? null : _versionData(historical);
    final displayText =
        historicalData?['narrative'] as String? ?? r.handoverText(h);
    final snapshots = historicalData == null
        ? h.sourceSnapshots
        : (historicalData['sourceSnapshots'] as List? ?? [])
              .map(objectMap)
              .toList();
    final viewingHistory = historical != null;

    return ListView(
      key: const Key('handover-screen'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        PageHeading(
          title: 'Shift handover',
          subtitle: 'Close the loop. Keep the next team informed.',
          action: canCoordinate
              ? signed
                    ? OutlinedButton.icon(
                        key: const Key('handover-add-amendment'),
                        onPressed: _busy || viewingHistory
                            ? null
                            : () => _amend(r),
                        icon: const Icon(Icons.edit_note_outlined, size: 19),
                        label: const Text('Add amendment'),
                      )
                    : FilledButton.icon(
                        key: const Key('handover-prepare-draft'),
                        onPressed: _busy || _editing || viewingHistory
                            ? null
                            : () => _prepare(r),
                        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                        label: const Text('Prepare draft'),
                      )
              : null,
        ),
        _shiftSelector(r),
        const SizedBox(height: 18),
        _ShiftBanner(handover: h, wardName: r.activeWard.name),
        if (urgent.isNotEmpty) ...[
          const SizedBox(height: 18),
          _UrgentItems(events: urgent),
        ],
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final record = SectionCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 18,
                    runSpacing: 14,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_outlined, size: 20),
                          SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              'Handover record',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: 230,
                        child: DropdownButtonFormField<int>(
                          key: ValueKey(
                            'handover-version-${h.id}-${h.version}-${_historicalVersion ?? h.version}',
                          ),
                          initialValue: _historicalVersion ?? h.version,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: h.version,
                              child: Text(
                                'Version ${h.version} · ${_documentStatus(h)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            for (final version
                                in versions.keys.toList().reversed)
                              if (version != h.version)
                                DropdownMenuItem(
                                  value: version,
                                  child: Text(
                                    'Version $version · Signed',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                          ],
                          onChanged: _editing
                              ? null
                              : (version) => setState(
                                  () => _historicalVersion =
                                      version == h.version ? null : version,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusPill(
                        label: viewingHistory
                            ? 'Signed version · Read only'
                            : signed
                            ? 'Signed handover'
                            : 'Draft · Review required',
                      ),
                      if ((historical?.createdAt ?? h.signedAt ?? h.preparedAt)
                          case final time?)
                        Text(
                          '${formatDate(time)} · ${formatTime(time)}',
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 22),
                  if (h.needsDraftUpdate && !viewingHistory) ...[
                    const Text(
                      'Sources or staff contributions have changed. Refresh or edit the draft to include the latest information before review.',
                      style: TextStyle(
                        color: Color(0xff9a691d),
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_editing && !viewingHistory) ...[
                    TextField(
                      key: const Key('handover-draft-editor'),
                      controller: _draft,
                      minLines: 15,
                      maxLines: null,
                      decoration: const InputDecoration(
                        labelText: 'Handover draft',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Saving an edit resets review and clinical validation. The source reports stay unchanged.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          key: const Key('handover-save-draft'),
                          onPressed: _busy
                              ? null
                              : () => _act(
                                  () async {
                                    await r.saveHandoverDraft(_draft.text);
                                    if (mounted) {
                                      setState(() => _editing = false);
                                    }
                                  },
                                  message:
                                      'Draft saved. Review is required before signing.',
                                ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Save draft'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _editing = false),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ] else if (displayText.trim().isEmpty)
                    const EmptyState(
                      icon: Icons.edit_note_outlined,
                      title: 'Prepare the handover',
                      message:
                          'The coordinator can prepare a draft from linked reports or write the handover directly.',
                    )
                  else
                    _Narrative(text: displayText),
                  const SizedBox(height: 24),
                  if (!viewingHistory && !_editing) ...[
                    Text(
                      signed
                          ? 'This signed content is preserved. Open linked reports to see their latest status.'
                          : 'Prepared from recorded sources. A person must review the content before it is signed.',
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (!signed && canEdit)
                          OutlinedButton.icon(
                            key: const Key('handover-edit-draft'),
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _draft.text = r.handoverText(h);
                                    _editing = true;
                                  }),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit draft'),
                          ),
                        if (!signed && canCoordinate)
                          OutlinedButton.icon(
                            key: const Key('handover-mark-reviewed'),
                            onPressed:
                                _busy ||
                                    h.status != HandoverStatus.aiDraft ||
                                    h.needsDraftUpdate ||
                                    displayText.trim().isEmpty
                                ? null
                                : () => _act(
                                    r.reviewHandover,
                                    message: 'Handover marked as reviewed.',
                                  ),
                            icon: const Icon(
                              Icons.fact_check_outlined,
                              size: 18,
                            ),
                            label: const Text('Mark reviewed'),
                          ),
                        if (!signed && r.can(Capability.clinicalValidation))
                          OutlinedButton.icon(
                            key: const Key('handover-clinical-validation'),
                            onPressed:
                                _busy || h.status != HandoverStatus.reviewed
                                ? null
                                : () => _act(
                                    r.validateHandover,
                                    message: 'Clinical validation recorded.',
                                  ),
                            icon: const Icon(Icons.verified_outlined, size: 18),
                            label: const Text('Validate clinical content'),
                          ),
                        if (!signed && r.can(Capability.signHandover))
                          FilledButton.icon(
                            key: const Key('handover-sign'),
                            onPressed:
                                _busy ||
                                    (h.status != HandoverStatus.reviewed &&
                                        h.status !=
                                            HandoverStatus
                                                .clinicallyValidated) ||
                                    (h.requiresClinicalValidation &&
                                        h.validatedBy == null)
                                ? null
                                : () async {
                                    if (await _confirm(
                                          'Sign version ${h.version}?',
                                          'Your name and the signature time will be linked to this exact version. Open events remain active until explicitly closed.',
                                          'Sign handover',
                                        ) &&
                                        mounted) {
                                      await _act(
                                        r.signHandover,
                                        message:
                                            'Handover signed. Incoming staff can now acknowledge it.',
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.draw_outlined, size: 18),
                            label: const Text('Sign outgoing handover'),
                          ),
                      ],
                    ),
                    if (h.reviewedBy != null ||
                        h.validatedBy != null ||
                        h.signedBy != null) ...[
                      const SizedBox(height: 16),
                      if (h.reviewedBy != null)
                        _Attribution(
                          label: 'Reviewed',
                          name:
                              r.staffForDisplay(h.reviewedBy!)?.name ??
                              h.reviewedBy!,
                          at: h.reviewedAt,
                        ),
                      if (h.validatedBy != null)
                        _Attribution(
                          label: 'Clinically validated',
                          name:
                              r.staffForDisplay(h.validatedBy!)?.name ??
                              h.validatedBy!,
                          at: h.validatedAt,
                        ),
                      if (h.signedBy != null)
                        _Attribution(
                          label: 'Signed',
                          name:
                              r.staffForDisplay(h.signedBy!)?.name ??
                              h.signedBy!,
                          at: h.signedAt,
                        ),
                    ],
                    if (h.requiresClinicalValidation && !signed) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Physician validation is required before this version can be signed.',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.link, color: teal, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Linked source reports',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if ((signed || viewingHistory) && snapshots.isNotEmpty)
                    for (final snapshot in snapshots)
                      _SourceReport(
                        event: CareEvent.fromJson(snapshot),
                        frozen: true,
                      )
                  else
                    for (final event in sources)
                      _SourceReport(event: event, frozen: false),
                  if (sources.isEmpty && snapshots.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No source reports linked.',
                        style: TextStyle(color: muted),
                      ),
                    ),
                  if (h.contributions.isNotEmpty && !viewingHistory) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Staff contributions',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    for (final contribution in h.contributions)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(contribution.text),
                            const SizedBox(height: 5),
                            Text(
                              '${r.staffForDisplay(contribution.authorId)?.name ?? contribution.authorId} · ${formatTime(contribution.createdAt)}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (h.versions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    ExpansionTile(
                      key: const Key('handover-version-history'),
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'Version history',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      children: [
                        for (final version in h.versions.reversed)
                          _HistoryEntry(version: version, repository: r),
                      ],
                    ),
                  ],
                ],
              ),
            );
            final side = Column(
              children: [
                if (viewingHistory) ...[
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Version ${historical.version} · Read only',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'You are viewing a preserved version. Return to the current version to contribute or acknowledge receipt.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          key: const Key('handover-back-to-current'),
                          onPressed: () =>
                              setState(() => _historicalVersion = null),
                          child: const Text('Back to current version'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _historicalReceipts(r, historicalData!),
                ] else ...[
                  _contributionCard(r, signed),
                  const SizedBox(height: 18),
                  _incomingCard(r, h, signed),
                ],
              ],
            );
            if (constraints.maxWidth < 1000) {
              return Column(
                children: [record, const SizedBox(height: 20), side],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: record),
                const SizedBox(width: 22),
                SizedBox(width: 280, child: side),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _shiftSelector(RsaRepository r) {
    final h = r.handover;
    final existingShiftIds = r.handovers
        .map((h) => h.outgoingShift?.id)
        .toSet();
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: DropdownButtonFormField<String>(
          key: ValueKey('handover-shift-${h.id}'),
          initialValue: h.id,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Outgoing shift',
            isDense: true,
          ),
          items: [
            for (final record in r.handovers)
              DropdownMenuItem(
                value: record.id,
                child: Text(
                  record.outgoingShift == null
                      ? record.shift
                      : '${formatDate(record.outgoingShift!.startsAt)} · ${record.outgoingShift!.label} · ${formatTime(record.outgoingShift!.startsAt)}–${formatTime(record.outgoingShift!.endsAt)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (r.can(Capability.coordination))
              for (final shift in r.shifts.where(
                (s) => !existingShiftIds.contains(s.id),
              ))
                DropdownMenuItem(
                  value: 'new:${shift.id}',
                  child: Text(
                    '${formatDate(shift.startsAt)} · ${shift.label} · New handover',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
          ],
          onChanged: _busy || _editing
              ? null
              : (value) {
                  if (value == null) return;
                  _act(
                    () => value.startsWith('new:')
                        ? r.selectHandoverShift(
                            r.shifts.firstWhere(
                              (s) => s.id == value.substring(4),
                            ),
                          )
                        : r.selectHandover(value),
                  );
                },
        ),
      ),
    );
  }

  Widget _contributionCard(RsaRepository r, bool signed) => SectionCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.edit_note_outlined, size: 19),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your shift contribution',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          signed
              ? 'This version is signed. Ask the coordinator to open an amendment for additional information.'
              : 'Add the facts and open items you want the next shift to know.',
          style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
        ),
        if (!signed) ...[
          const SizedBox(height: 16),
          TextField(
            key: const Key('handover-contribution'),
            controller: _contribution,
            minLines: 5,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'What should the next team know?',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('handover-add-contribution'),
              onPressed: _busy || _contribution.text.trim().isEmpty
                  ? null
                  : () => _act(
                      () async {
                        await r.contributeSummary(_contribution.text);
                        _contribution.clear();
                      },
                      message:
                          'Contribution added. Refresh or edit the draft before review.',
                    ),
              icon: const Icon(Icons.send_outlined, size: 17),
              label: const Text('Add contribution'),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _historicalReceipts(RsaRepository r, Map<String, dynamic> data) {
    final receipts = objectMap(data['acknowledgements'] ?? {});
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Retained acknowledgements',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (receipts.isEmpty)
            const Text(
              'No acknowledgements were retained with this snapshot.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          for (final receipt in receipts.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.check_circle_outline,
                color: teal,
                size: 20,
              ),
              title: Text(
                r.staffForDisplay(receipt.key)?.name ?? receipt.key,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${formatDate(DateTime.parse(receipt.value.toString()))} · ${formatTime(DateTime.parse(receipt.value.toString()))}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _incomingCard(RsaRepository r, Handover h, bool signed) {
    final displayedVersion = h.version;
    final displayedHandoverId = h.id;
    final currentAcknowledged = h.acknowledgements.containsKey(
      r.currentUser.id,
    );
    return SectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Incoming team',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (!signed && r.can(Capability.coordination))
                IconButton(
                  tooltip: 'Assign incoming staff',
                  icon: const Icon(Icons.group_add_outlined, size: 19),
                  onPressed: _busy ? null : () => _assignIncoming(r),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (h.incomingStaffIds.isEmpty)
            const Text(
              'The coordinator has not assigned the incoming team yet.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          for (final id in h.incomingStaffIds)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Avatar(r.staffForDisplay(id)?.initials ?? '?', size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.staffForDisplay(id)?.name ?? id,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          h.acknowledgements[id] != null
                              ? 'Acknowledged · ${formatTime(DateTime.parse(h.acknowledgements[id]!))}'
                              : signed
                              ? 'Awaiting acknowledgement'
                              : 'Awaiting signed version',
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    h.acknowledgements.containsKey(id)
                        ? Icons.check_circle_outline
                        : Icons.schedule_outlined,
                    color: teal,
                    size: 19,
                  ),
                ],
              ),
            ),
          if (signed && h.incomingStaffIds.contains(r.currentUser.id)) ...[
            const Divider(),
            const SizedBox(height: 14),
            if (currentAcknowledged)
              Text(
                'You acknowledged version ${h.version}.',
                style: const TextStyle(
                  color: teal,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('handover-acknowledge'),
                  onPressed: _busy
                      ? null
                      : () => _act(
                          () => r.acknowledgeHandover(
                            expectedVersion: displayedVersion,
                            expectedHandoverId: displayedHandoverId,
                          ),
                          message:
                              'Acknowledgement recorded for this signed version.',
                        ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Acknowledge version'),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Acknowledgement records receipt. It does not take charge of or close any event.',
              style: TextStyle(color: muted, fontSize: 11, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

String _documentStatus(Handover h) => switch (h.status) {
  HandoverStatus.aiDraft => 'Draft',
  HandoverStatus.reviewed => 'Reviewed',
  HandoverStatus.clinicallyValidated => 'Validated',
  HandoverStatus.signed => 'Signed',
  HandoverStatus.acknowledged => 'Acknowledged',
};

class _ShiftBanner extends StatelessWidget {
  final Handover handover;
  final String wardName;
  const _ShiftBanner({required this.handover, required this.wardName});

  @override
  Widget build(BuildContext context) {
    final outgoing = handover.outgoingShift;
    final incoming = outgoing == null
        ? null
        : Shift.at(
            outgoing.endsAt.add(const Duration(minutes: 1)),
            handover.wardId,
          );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusPill(label: wardName, color: const Color(0xff6c895c)),
        const SizedBox(height: 12),
        Text(
          '${outgoing?.label ?? handover.shift} → ${incoming?.label ?? 'Next shift'}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xff6c895c),
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          outgoing == null
              ? 'Outgoing handover · Incoming team acknowledgement'
              : 'Outgoing ${formatTime(outgoing.startsAt)}–${formatTime(outgoing.endsAt)} · Incoming ${formatTime(incoming!.startsAt)}–${formatTime(incoming.endsAt)}',
          style: const TextStyle(fontSize: 11, color: Color(0xff7e9372)),
        ),
      ],
    );
    return Container(
      key: const Key('handover-lifecycle-banner'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xfff0f4e9),
        border: Border.all(color: const Color(0xffe5ecd9)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                info,
                const SizedBox(height: 24),
                _Lifecycle(handover: handover),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              SizedBox(
                width: handover.requiresClinicalValidation ? 390 : 330,
                child: _Lifecycle(handover: handover),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Lifecycle extends StatelessWidget {
  final Handover handover;
  const _Lifecycle({required this.handover});
  @override
  Widget build(BuildContext context) {
    final labels = [
      'Draft',
      'Reviewed',
      if (handover.requiresClinicalValidation) 'Validated',
      'Signed',
      'Acknowledged',
    ];
    final current = switch (handover.status) {
      HandoverStatus.aiDraft => 0,
      HandoverStatus.reviewed => 1,
      HandoverStatus.clinicallyValidated =>
        handover.requiresClinicalValidation ? 2 : 1,
      HandoverStatus.signed => labels.length - 2,
      HandoverStatus.acknowledged => labels.length - 1,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < labels.length; index++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: index == 0
                            ? Colors.transparent
                            : const Color(0xffd9e5cd),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index <= current
                            ? const Color(0xffdfebd4)
                            : Colors.white.withValues(alpha: .45),
                        border: Border.all(color: const Color(0xffd3e1c6)),
                      ),
                      child: index < current
                          ? const Icon(
                              Icons.check,
                              size: 15,
                              color: Color(0xff6c895c),
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                color: index == current
                                    ? const Color(0xff6c895c)
                                    : const Color(0xffacb79f),
                              ),
                            ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: index == labels.length - 1
                            ? Colors.transparent
                            : const Color(0xffd9e5cd),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: index <= current
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: index <= current
                        ? const Color(0xff6c895c)
                        : const Color(0xffa2ad97),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _UrgentItems extends StatelessWidget {
  final List<CareEvent> events;
  const _UrgentItems({required this.events});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xfffff7e9),
      border: Border.all(color: const Color(0xfff2e2c5)),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.schedule_outlined, color: Color(0xff9a691d), size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${events.length} unresolved high-priority ${events.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(
                  color: Color(0xff9a691d),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'These remain active until explicitly closed. Signing the handover does not resolve them.',
                style: TextStyle(
                  color: Color(0xff9a691d),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final event in events)
                    TextButton.icon(
                      onPressed: () => context.go('/event/${event.id}'),
                      icon: const Icon(Icons.arrow_forward, size: 15),
                      label: Text(
                        '${event.type.label} · ${event.residentId ?? event.subject}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Narrative extends StatelessWidget {
  final String text;
  const _Narrative({required this.text});
  @override
  Widget build(BuildContext context) {
    const headings = {
      'Important reported events',
      'Open follow-ups',
      'Unresolved notifications',
      'Items to pass to the next shift',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final paragraph in text.split('\n'))
          if (paragraph.isEmpty)
            const SizedBox(height: 13)
          else
            Padding(
              padding: EdgeInsets.only(
                top: headings.contains(paragraph) ? 8 : 3,
                bottom: 3,
              ),
              child: SelectableText(
                paragraph,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  fontWeight: headings.contains(paragraph)
                      ? FontWeight.w800
                      : FontWeight.w400,
                  color: headings.contains(paragraph)
                      ? const Color(0xff6c895c)
                      : ink,
                ),
              ),
            ),
      ],
    );
  }
}

class _SourceReport extends StatelessWidget {
  final CareEvent event;
  final bool frozen;
  const _SourceReport({required this.event, required this.frozen});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      eventIcon(event.type),
      size: 20,
      color: priorityColor(event.priority),
    ),
    title: Text(
      '${event.type.label} · ${event.residentId ?? event.subject}',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      '${event.priority.label} · ${event.status.label}${frozen ? ' at signature' : ''}',
      style: const TextStyle(fontSize: 11),
    ),
    trailing: const Icon(Icons.arrow_outward, size: 17, color: muted),
    onTap: () => context.go('/event/${event.id}'),
  );
}

class _Attribution extends StatelessWidget {
  final String label, name;
  final DateTime? at;
  const _Attribution({required this.label, required this.name, this.at});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Text(
      '$label by $name${at == null ? '' : ' · ${formatDate(at!)} ${formatTime(at!)}'}',
      style: const TextStyle(color: muted, fontSize: 11),
    ),
  );
}

Map<String, dynamic> _versionData(RecordVersion version) {
  try {
    final result = jsonDecode(version.text);
    if (result is Map) return objectMap(result);
  } catch (_) {
    // Earlier persisted records can contain plain text.
  }
  return {
    'narrative': version.text.startsWith('Signed synthetic handover.')
        ? 'Signed handover. The narrative was not retained for this earlier record.'
        : version.text,
  };
}

class _HistoryEntry extends StatelessWidget {
  final RecordVersion version;
  final RsaRepository repository;
  const _HistoryEntry({required this.version, required this.repository});
  @override
  Widget build(BuildContext context) {
    final data = _versionData(version);
    final title = switch (data['kind']) {
      'signed' => 'Signed version',
      'amendment' => 'Amendment opened',
      'draftEdited' => 'Draft edited',
      'draftReplaced' => 'Previous draft retained',
      _ => 'Retained record',
    };
    final previous = data['narrative'] as String? ?? '';
    final updated = data['updatedNarrative'] as String?;
    final original = data['originalDraft'] as String?;
    final receipts = objectMap(data['acknowledgements'] ?? {});
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        'Version ${version.version} · $title',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${repository.staffForDisplay(version.authorId)?.name ?? version.authorId} · ${formatDate(version.createdAt)} ${formatTime(version.createdAt)}',
        style: const TextStyle(fontSize: 11, color: muted),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data['amendment'] != null) ...[
                Text(
                  data['amendment'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
              ],
              if (updated != null) ...[
                const Text(
                  'Saved text',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                _Narrative(text: updated),
                const SizedBox(height: 12),
                const Text(
                  'Previous text',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
              ],
              if (previous.isNotEmpty) _Narrative(text: previous),
              if (original != null && original != previous) ...[
                const SizedBox(height: 18),
                const Text(
                  'Original prepared draft',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _Narrative(text: original),
              ],
              for (final entry in receipts.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Acknowledged by ${repository.staffForDisplay(entry.key)?.name ?? entry.key} · ${formatTime(DateTime.parse(entry.value.toString()))}',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmendmentDialog extends StatefulWidget {
  const _AmendmentDialog();
  @override
  State<_AmendmentDialog> createState() => _AmendmentDialogState();
}

class _AmendmentDialogState extends State<_AmendmentDialog> {
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add amendment'),
    content: SizedBox(
      width: 430,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The signed record and earlier acknowledgements are preserved. This opens a new draft that must be reviewed, signed and acknowledged again.',
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('handover-amendment-note'),
              controller: _note,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Reason and additional information',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('handover-amendment-save'),
        onPressed: _note.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _note.text.trim()),
        child: const Text('Create amendment'),
      ),
    ],
  );
}

class _IncomingTeamDialog extends StatefulWidget {
  final String wardId;
  final List<StaffMember> staff;
  final List<String> selected;
  const _IncomingTeamDialog({
    required this.wardId,
    required this.staff,
    required this.selected,
  });
  @override
  State<_IncomingTeamDialog> createState() => _IncomingTeamDialogState();
}

class _IncomingTeamDialogState extends State<_IncomingTeamDialog> {
  late final _selected = widget.selected.toSet();
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Incoming team'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select the staff expected to receive and acknowledge this handover.',
            ),
            const SizedBox(height: 12),
            for (final staff in widget.staff)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(staff.name),
                subtitle: Text(staff.rolesLabelForWard(widget.wardId)),
                value: _selected.contains(staff.id),
                onChanged: (value) => setState(() {
                  value == true
                      ? _selected.add(staff.id)
                      : _selected.remove(staff.id);
                }),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _selected.toList()),
        child: const Text('Save team'),
      ),
    ],
  );
}
