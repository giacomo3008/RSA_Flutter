import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsa/core/database.dart';
import 'package:rsa/core/models.dart';
import 'package:rsa/core/repository.dart';

void main() {
  late RsaRepository repository;
  final clock = DateTime.utc(2026, 10, 27, 8);
  setUp(() async {
    repository = await RsaRepository.open(
      database: RsaDatabase(NativeDatabase.memory()),
      clock: () => clock,
    );
  });
  tearDown(() => repository.close());

  test(
    'incoming nurse can acknowledge but cannot edit, prepare or amend',
    () async {
      await expectLater(
        repository.prepareHandoverDraft(),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(
        repository.saveHandoverDraft('Changed text'),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(
        repository.amendHandover('Additional information'),
        throwsA(isA<PermissionDenied>()),
      );
      final initialEventState = repository.events.map((e) => e.status).toList();
      await repository.acknowledgeHandover();
      expect(
        repository.handover.acknowledgements['nurse-1'],
        clock.toIso8601String(),
      );
      expect(repository.events.map((e) => e.status), initialEventState);
    },
  );

  test(
    'source draft, human correction, review and exact signed content remain traceable',
    () async {
      await repository.switchPersona('coordinator-1');
      await repository.amendHandover('Add the next shift follow-up.');
      await repository.prepareHandoverDraft();
      final original = repository.handover.originalDraftText!;
      final corrected =
          '$original\nHuman review: contact the coordinator for the unresolved item.';
      await repository.saveHandoverDraft(corrected);
      expect(repository.handover.originalDraftText, original);
      expect(repository.handover.editedBy, 'coordinator-1');
      await repository.reviewHandover();
      await repository.signHandover();
      final signed =
          jsonDecode(repository.handover.versions.last.text)
              as Map<String, dynamic>;
      expect(signed['narrative'], corrected);
      expect(signed['originalDraft'], original);
      expect(signed['signedBy'], 'coordinator-1');
      expect((signed['sourceSnapshots'] as List), isNotEmpty);
      await expectLater(
        repository.saveHandoverDraft('Overwrite signed content'),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'editing a reviewed and clinically validated draft clears both approvals',
    () async {
      await repository.switchPersona('coordinator-1');
      await repository.amendHandover(
        'Clinical information needs confirmation.',
      );
      repository.handover.requiresClinicalValidation = true;
      await repository.reviewHandover();
      await repository.switchPersona('physician-1');
      await repository.validateHandover();
      expect(repository.handover.validatedBy, 'physician-1');
      await repository.saveHandoverDraft(
        '${repository.handoverText()}\nPhysician correction.',
      );
      expect(repository.handover.status, HandoverStatus.aiDraft);
      expect(repository.handover.reviewedBy, isNull);
      expect(repository.handover.validatedBy, isNull);
      await repository.switchPersona('coordinator-1');
      await expectLater(repository.signHandover(), throwsA(isA<StateError>()));
    },
  );

  test(
    'signed sources and narrative do not change when the live event is closed',
    () async {
      final narrative = repository.handoverText();
      final signedSnapshots = jsonEncode(repository.handover.sourceSnapshots);
      await repository.claimEvent('event-fall');
      await repository.closeEvent(
        'event-fall',
        'Assessment and follow-up completed.',
      );
      expect(repository.eventById('event-fall')!.status, EventStatus.closed);
      expect(repository.handoverText(), narrative);
      expect(jsonEncode(repository.handover.sourceSnapshots), signedSnapshots);
      expect(
        repository.handover.sourceSnapshots.firstWhere(
          (e) => e['id'] == 'event-fall',
        )['status'],
        'unhandled',
      );
    },
  );

  test(
    'amendments retain earlier receipt and signed narrative and require new receipt',
    () async {
      await repository.acknowledgeHandover();
      final oldVersion = repository.handover.version;
      final oldText = repository.handoverText();
      await repository.switchPersona('coordinator-1');
      await repository.amendHandover(
        'Changed follow-up for the incoming team.',
      );
      expect(repository.handover.version, oldVersion + 1);
      expect(repository.handover.acknowledgements, isEmpty);
      expect(repository.handover.signedBy, isNull);
      expect(
        repository.handoverText(),
        contains('Changed follow-up for the incoming team.'),
      );
      final archived =
          jsonDecode(repository.handover.versions.last.text)
              as Map<String, dynamic>;
      expect(archived['narrative'], oldText);
      expect(archived['acknowledgements']['nurse-1'], clock.toIso8601String());
      expect(archived['signedBy'], 'coordinator-1');
      await expectLater(
        repository.amendHandover('Another amendment'),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'new contribution invalidates review until the draft is refreshed or explicitly edited',
    () async {
      await repository.switchPersona('coordinator-1');
      await repository.amendHandover('Start reviewed version.');
      await repository.reviewHandover();
      await repository.switchPersona('assistant-1');
      await repository.contributeSummary(
        'Wheelchair brake inspection still needs follow-up.',
      );
      expect(repository.handover.needsDraftUpdate, isTrue);
      expect(repository.handover.status, HandoverStatus.aiDraft);
      await repository.switchPersona('coordinator-1');
      await expectLater(
        repository.reviewHandover(),
        throwsA(isA<StateError>()),
      );
      await repository.prepareHandoverDraft();
      expect(repository.handover.needsDraftUpdate, isFalse);
      expect(
        repository.handoverText(),
        contains('Wheelchair brake inspection still needs follow-up.'),
      );
      await repository.reviewHandover();
    },
  );

  test(
    'a receipt cannot acknowledge a newer signed version or a different record',
    () async {
      final oldVersion = repository.handover.version;
      final id = repository.handover.id;
      await repository.switchPersona('coordinator-1');
      await repository.amendHandover(
        'New signed information for the next team.',
      );
      await repository.reviewHandover();
      await repository.signHandover();
      await repository.switchPersona('nurse-1');
      await expectLater(
        repository.acknowledgeHandover(
          expectedVersion: oldVersion,
          expectedHandoverId: id,
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repository.acknowledgeHandover(
          expectedVersion: repository.handover.version,
          expectedHandoverId: 'another-record',
        ),
        throwsA(isA<StateError>()),
      );
      expect(repository.handover.acknowledgements, isEmpty);
      await repository.acknowledgeHandover(
        expectedVersion: repository.handover.version,
        expectedHandoverId: id,
      );
      expect(repository.handover.acknowledgements, contains('nurse-1'));
    },
  );

  test(
    'ward and shift selection creates a separate record with explicit incoming assignments',
    () async {
      final original = repository.handover;
      final nextShift = Shift.at(
        original.outgoingShift!.endsAt.add(const Duration(minutes: 1)),
        'oak',
      );
      await expectLater(
        repository.selectHandoverShift(nextShift),
        throwsA(isA<PermissionDenied>()),
      );
      await repository.switchPersona('coordinator-1');
      await repository.selectHandoverShift(nextShift);
      expect(repository.handover.id, isNot(original.id));
      expect(repository.handover.outgoingShift!.id, nextShift.id);
      expect(repository.handover.incomingStaffIds, isEmpty);
      expect(repository.handover.sourceEventIds, contains('event-fall'));
      expect(
        repository.handover.sourceEventIds,
        isNot(contains('event-refusal')),
      );
      await expectLater(
        repository.assignHandoverIncomingStaff(['willow-nurse']),
        throwsA(isA<PermissionDenied>()),
      );
      await repository.assignHandoverIncomingStaff(['nurse-1', 'assistant-1']);
      expect(repository.handover.incomingStaffIds, ['nurse-1', 'assistant-1']);
      await repository.selectHandover(original.id);
      expect(repository.handover.signedBy, 'coordinator-1');
    },
  );

  test(
    'late event belongs to its own shift instead of changing a different signed handover',
    () async {
      final original = repository.handover;
      final event = await repository.reportEvent(
        EventDraft(
          idempotencyKey: 'previous-shift-report',
          type: EventType.hygiene,
          residentId: 'R-014',
          place: 'Room 101',
          occurredAt: clock.subtract(const Duration(hours: 8)),
          notes: 'Late entry for care provided on the previous shift.',
        ),
      );
      expect(original.signedBy, 'coordinator-1');
      expect(original.sourceEventIds, isNot(contains(event.id)));
      final linked = repository.handovers.singleWhere(
        (h) => h.sourceEventIds.contains(event.id),
      );
      expect(linked.outgoingShift!.contains(event.occurredAt), isTrue);
    },
  );

  test(
    'new handover fields round trip and legacy signed text is not reconstructed from live records',
    () async {
      final json = repository.handover.toJson();
      final copy = Handover.fromJson(json);
      expect(copy.toJson(), json);
      final legacy = Map<String, dynamic>.of(json)
        ..remove('outgoingShift')
        ..remove('draftText')
        ..remove('originalDraftText')
        ..remove('sourceSnapshots')
        ..remove('needsDraftUpdate');
      final old = Handover.fromJson(legacy);
      expect(old.outgoingShift, isNull);
      expect(old.sourceSnapshots, isEmpty);
      expect(
        repository.handoverText(old),
        contains('not available for this earlier record'),
      );
      expect(repository.handoverText(old), isNot(contains('synthetic')));
    },
  );
}
