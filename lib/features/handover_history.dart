import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/repository.dart';
import '../shared/ui.dart';

Map<String, dynamic> handoverVersionData(RecordVersion record) {
  try {
    final decoded = jsonDecode(record.text);
    if (decoded is Map) return objectMap(decoded);
  } catch (_) {
    // Earlier retained records may be plain text.
  }
  return {
    'narrative': record.text.startsWith('Signed synthetic handover.')
        ? 'The narrative was not retained for this earlier signed record.'
        : record.text,
  };
}

class HandoverVersionHistory extends StatelessWidget {
  final Handover handover;
  final RsaRepository repository;
  final int? viewedVersion;
  final ValueChanged<int?> onViewVersion;
  const HandoverVersionHistory({
    super.key,
    required this.handover,
    required this.repository,
    required this.viewedVersion,
    required this.onViewVersion,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <int, List<RecordVersion>>{};
    for (final record in handover.versions) {
      groups.putIfAbsent(record.version, () => []).add(record);
    }
    groups.putIfAbsent(handover.version, () => []);
    final numbers = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history_rounded, color: teal, size: 21),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Version history',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'A signed version is kept as a permanent record. An amendment opens the next version for review and signature.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 5),
        const Text(
          'Saving draft edits records activity within the same version.',
          style: TextStyle(color: muted, fontSize: 11, height: 1.6),
        ),
        if (numbers.length == 1) ...[
          const SizedBox(height: 10),
          const Text(
            'No earlier versions yet.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
        for (final number in numbers) ...[
          const SizedBox(height: 16),
          _VersionCard(
            number: number,
            handover: handover,
            records: groups[number]!,
            previousRecords: groups[number - 1] ?? [],
            repository: repository,
            viewedVersion: viewedVersion,
            onViewVersion: onViewVersion,
          ),
        ],
      ],
    );
  }
}

class _VersionCard extends StatelessWidget {
  final int number;
  final Handover handover;
  final List<RecordVersion> records, previousRecords;
  final RsaRepository repository;
  final int? viewedVersion;
  final ValueChanged<int?> onViewVersion;
  const _VersionCard({
    required this.number,
    required this.handover,
    required this.records,
    required this.previousRecords,
    required this.repository,
    required this.viewedVersion,
    required this.onViewVersion,
  });

  @override
  Widget build(BuildContext context) {
    final current = number == handover.version;
    final signedRecords = records.where((r) {
      final d = handoverVersionData(r);
      return d['signedBy'] != null || d['kind'] == 'signed';
    }).toList();
    final signedRecord = signedRecords.lastOrNull;
    final data = signedRecord == null
        ? <String, dynamic>{}
        : handoverVersionData(signedRecord);
    final signer =
        (current ? handover.signedBy : null) ?? data['signedBy'] as String?;
    final signedAt =
        (current ? handover.signedAt : null) ??
        DateTime.tryParse(data['signedAt']?.toString() ?? '') ??
        signedRecord?.createdAt;
    final isSigned = signer != null || signedRecord != null;
    final selected = (viewedVersion ?? handover.version) == number;
    final reasons = previousRecords
        .map(handoverVersionData)
        .where((d) => d['kind'] == 'amendment' && d['amendment'] != null)
        .toList();
    final reason = reasons.lastOrNull?['amendment']?.toString();
    final receipts = current
        ? handover.acknowledgements
        : objectMap(data['acknowledgements'] ?? {});
    final editCount = records
        .where((r) => handoverVersionData(r)['kind'] == 'draftEdited')
        .length;
    final color = current ? teal : muted;
    final status = current
        ? isSigned
              ? 'Current · Signed'
              : 'Current · ${_status(handover.status)}'
        : isSigned
        ? 'Previous · Signed'
        : 'Previous · Saved draft';
    return Container(
      key: ValueKey('handover-history-version-$number'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: current ? const Color(0xfff1f7f4) : canvas,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: selected
              ? teal.withValues(alpha: .4)
              : const Color(0xffdfe7e3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'V$number',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Version $number',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        StatusPill(
                          label: status,
                          color: color,
                          icon: isSigned
                              ? Icons.verified_outlined
                              : Icons.edit_note_outlined,
                        ),
                        if (selected)
                          const StatusPill(
                            label: 'Viewing',
                            icon: Icons.visibility_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isSigned
                ? 'Signed by ${signer == null ? 'recorded staff member' : repository.staffForDisplay(signer)?.name ?? signer}${signedAt == null ? '' : ' · ${formatDate(signedAt)} ${formatTime(signedAt)}'}'
                : 'Draft in progress. It becomes official after review and coordinator signature.',
            style: const TextStyle(color: muted, fontSize: 11, height: 1.6),
          ),
          if (reason != null) ...[
            const SizedBox(height: 10),
            const Text(
              'Why this version was opened',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(reason, style: const TextStyle(fontSize: 12, height: 1.6)),
          ],
          if (editCount > 0 || receipts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (editCount > 0)
                  Text(
                    '$editCount saved draft ${editCount == 1 ? 'edit' : 'edits'}',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                if (receipts.isNotEmpty)
                  Text(
                    '${receipts.length} recorded acknowledgements',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!selected && (isSigned || current))
                OutlinedButton.icon(
                  key: ValueKey('handover-view-version-$number'),
                  onPressed: () => onViewVersion(current ? null : number),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(
                    current ? 'Back to current version' : 'View signed version',
                  ),
                ),
              if (records.isNotEmpty)
                TextButton.icon(
                  key: ValueKey('handover-version-activity-$number'),
                  onPressed: () => _showActivity(context),
                  icon: const Icon(Icons.timeline_outlined, size: 17),
                  label: const Text('View activity'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showActivity(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text('Version $number · Activity'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in records)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _action(handoverVersionData(r)['kind']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${repository.staffForDisplay(r.authorId)?.name ?? r.authorId} · ${formatDate(r.createdAt)} ${formatTime(r.createdAt)}',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                    if (handoverVersionData(r)['amendment'] != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Reason for the following version: ${handoverVersionData(r)['amendment']}',
                        style: const TextStyle(fontSize: 12, height: 1.6),
                      ),
                    ],
                    if (handoverVersionData(r)['kind'] == 'draftEdited')
                      TextButton(
                        onPressed: () =>
                            _showEdit(context, handoverVersionData(r)),
                        child: const Text('View saved edit'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  void _showEdit(BuildContext context, Map<String, dynamic> data) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Saved draft edit'),
          content: SizedBox(
            width: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Before',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                SelectableText(data['narrative']?.toString() ?? ''),
                const SizedBox(height: 22),
                const Text(
                  'Saved text',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                SelectableText(data['updatedNarrative']?.toString() ?? ''),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
}

String _status(HandoverStatus status) => switch (status) {
  HandoverStatus.aiDraft => 'Draft',
  HandoverStatus.reviewed => 'Reviewed',
  HandoverStatus.clinicallyValidated => 'Clinically validated',
  HandoverStatus.signed => 'Signed',
  HandoverStatus.acknowledged => 'Acknowledged',
};

String _action(Object? kind) => switch (kind) {
  'signed' => 'Version signed',
  'amendment' => 'Following version opened',
  'draftEdited' => 'Draft edit saved',
  'draftReplaced' => 'Draft refreshed from sources',
  _ => 'Record retained',
};
