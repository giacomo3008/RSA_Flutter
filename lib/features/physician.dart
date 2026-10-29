import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models.dart';
import '../core/providers.dart';
import '../shared/ui.dart';

/// A physician's clinical review workspace; operational signature stays separate.
class PhysicianScreen extends ConsumerWidget {
  const PhysicianScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(rsaRepositoryProvider);
    if (!r.can(Capability.clinicalValidation)) {
      return const EmptyState(
        icon: Icons.lock_outline,
        title: 'Clinical review restricted',
        message:
            'Clinical validation requires a physician assignment in the current ward.',
      );
    }
    final h = r.handover;
    final canValidate = h.status == HandoverStatus.reviewed;
    final signed = h.signedBy != null;
    final high = r.events
        .where(
          (event) =>
              event.priority == Priority.high &&
              event.status != EventStatus.closed,
        )
        .toList();
    return ListView(
      children: [
        PageHeading(
          title: 'Clinical review',
          subtitle: '${r.activeWard.name} · Physician workspace',
        ),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_outlined, color: teal),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Clinical validation',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Review the source records and the human-reviewed handover before validating clinical content. Clinical validation, the outgoing coordinator’s signature and incoming acknowledgement are separate actions.',
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  StatusPill(label: 'Version ${h.version}'),
                  StatusPill(label: h.status.label),
                  StatusPill(
                    label: h.requiresClinicalValidation
                        ? 'Physician validation required'
                        : 'Physician validation according to ward policy',
                    color: muted,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (h.validatedBy != null)
                Text(
                  'Validated by ${r.staffForDisplay(h.validatedBy!)?.name ?? h.validatedBy}${h.validatedAt == null ? '' : ' · ${formatDate(h.validatedAt!)} ${formatTime(h.validatedAt!)}'}',
                )
              else if (signed)
                const Text(
                  'This signed version is available for consultation. A correction requires a new handover version.',
                )
              else if (!canValidate)
                const Text(
                  'Awaiting coordinator review before physician validation.',
                ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/handover'),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Open handover and sources'),
                  ),
                  if (canValidate)
                    FilledButton.icon(
                      onPressed: () => runAction(context, r.validateHandover),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Validate clinical content'),
                    ),
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
              const Text(
                'Open high-priority reports',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Consultation does not take charge of a report or close it.',
              ),
              const SizedBox(height: 12),
              if (high.isEmpty)
                const Text('No open high-priority reports in this ward.'),
              for (final event in high)
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
                    '${event.status.label} · ${formatTime(event.occurredAt)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/event/${event.id}'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Documents and ward record',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check source documents against their reviewed transcription. Confirming a transcription does not establish clinical approval.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/ocr'),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('Open document review'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/diary'),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Open ward diary'),
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
