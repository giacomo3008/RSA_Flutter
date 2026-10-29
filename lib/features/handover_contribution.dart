import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/providers.dart';
import '../shared/ui.dart';

class HandoverContributionCard extends ConsumerStatefulWidget {
  final bool editingDocument;
  const HandoverContributionCard({super.key, this.editingDocument = false});
  @override
  ConsumerState<HandoverContributionCard> createState() => _ContributionState();
}

class _ContributionState extends ConsumerState<HandoverContributionCard> {
  final _text = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_saving || _text.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final r = ref.read(rsaRepositoryProvider);
    final h = r.handover;
    final signed = h.signedBy != null;
    final id = h.id;
    final version = h.version;
    setState(() => _saving = true);
    try {
      await r.contributeSummary(
        _text.text,
        expectedHandoverId: id,
        expectedVersion: version,
      );
      if (!mounted) return;
      _text.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            signed
                ? 'Update sent for coordinator review. The signed version is preserved.'
                : 'Contribution saved. Include it in the draft before review.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _include() async {
    final r = ref.read(rsaRepositoryProvider);
    final id = r.handover.id;
    final version = r.handover.version;
    setState(() => _saving = true);
    try {
      await r.includePendingHandoverUpdates(
        expectedHandoverId: id,
        expectedVersion: version,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Updates included in the draft. Review and sign the new content.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(rsaRepositoryProvider);
    final h = r.handover;
    final signed = h.signedBy != null;
    return SectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note_outlined, size: 20, color: teal),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Your shift contribution',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Leave facts, updates and outstanding tasks for the next team.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 14),
          if (signed) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffedf4ef),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 17, color: teal),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This handover is signed. You can still send an update: the coordinator reviews it before adding it to a new version.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            key: const Key('handover-contribution'),
            controller: _text,
            enabled: !_saving,
            minLines: 4,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: signed ? 'Your update' : 'Shift notes',
              alignLabelWithHint: true,
              hintText: 'What should the next team know?',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('handover-add-contribution'),
              onPressed: _saving || _text.text.trim().isEmpty ? null : _send,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined, size: 17),
              label: Text(signed ? 'Send update' : 'Add contribution'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            signed
                ? 'Your update is retained with your name and time. It does not change the signed handover or close an event.'
                : 'Your contribution becomes a source for the handover. The coordinator reviews the final document before signing.',
            style: const TextStyle(color: muted, fontSize: 11, height: 1.6),
          ),
          if (h.pendingContributions.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Updates awaiting review (${h.pendingContributions.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'These updates are separate from the official document.',
              style: TextStyle(color: muted, fontSize: 11, height: 1.5),
            ),
            for (final update in h.pendingContributions)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfffff7e9),
                  border: Border.all(color: const Color(0xffefdfbf)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      update.text,
                      style: const TextStyle(fontSize: 12, height: 1.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${r.staffForDisplay(update.authorId)?.name ?? update.authorId} · ${formatDate(update.createdAt)} ${formatTime(update.createdAt)}',
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    const StatusPill(
                      label: 'Awaiting coordinator review',
                      color: Color(0xff9a691d),
                    ),
                  ],
                ),
              ),
            if (r.can(Capability.coordination)) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('handover-include-updates'),
                  onPressed: _saving || widget.editingDocument
                      ? null
                      : _include,
                  icon: const Icon(Icons.playlist_add_check, size: 18),
                  label: Text(
                    signed
                        ? 'Include in a new version'
                        : 'Include updates in draft',
                  ),
                ),
              ),
              if (widget.editingDocument)
                const Text(
                  'Save or cancel your draft edit before including updates.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
