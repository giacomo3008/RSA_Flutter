import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsa/core/database.dart';
import 'package:rsa/core/models.dart';
import 'package:rsa/core/repository.dart';

void main() {
  late RsaRepository repo;
  final clock = DateTime.utc(2026, 10, 27, 8);
  setUp(() async {
    repo = await RsaRepository.open(
      database: RsaDatabase(NativeDatabase.memory()),
      clock: () => clock,
    );
  });
  tearDown(() async => repo.close());
  EventDraft draft(String key, {EventType type = EventType.fall}) => EventDraft(
    idempotencyKey: key,
    type: type,
    residentId: 'R-014',
    place: 'Bathroom',
    occurredAt: clock,
    notes: 'Synthetic staff observation.',
  );

  test(
    'assistant report is linked across diary and handover with an optional event conversation',
    () async {
      await repo.switchPersona('assistant-1');
      final event = await repo.reportEvent(draft('flow'));
      expect(repo.events.where((e) => e.id == event.id), hasLength(1));
      expect(
        repo.conversations.any((c) => c.id == event.conversationId),
        isFalse,
      );
      await repo.openEventConversation(event.id);
      expect(
        repo.conversations.any((c) => c.id == event.conversationId),
        isTrue,
      );
      expect(repo.messagesFor(event.conversationId).single.sourceEventIds, [
        event.id,
      ]);
      expect(repo.handover.sourceEventIds, contains(event.id));
      expect(repo.notifications, isEmpty);
      await repo.switchPersona('nurse-1');
      expect(repo.notifications.any((n) => n.eventId == event.id), isTrue);
    },
  );
  test(
    'high excludes off-duty, other-ward and on-break recipients but includes busy nurse',
    () async {
      final event = await repo.reportEvent(draft('high'));
      final recipients = repo
          .eligibleRecipients(event)
          .map((s) => s.id)
          .toSet();
      expect(recipients, containsAll(['nurse-1', 'nurse-3', 'coordinator-1']));
      expect(recipients, isNot(contains('nurse-2')));
      expect(recipients, isNot(contains('nurse-4')));
      expect(recipients, isNot(contains('willow-nurse')));
      expect(recipients, isNot(contains('assistant-1')));
    },
  );
  test(
    'medium quietly targets available nurses and low never creates an alert',
    () async {
      final medium = await repo.reportEvent(
        draft('medium', type: EventType.safety),
      );
      final notification = repo.notifications.firstWhere(
        (n) => n.eventId == medium.id,
      );
      expect(notification.recipientIds, ['nurse-1']);
      final low = await repo.reportEvent(draft('low', type: EventType.hygiene));
      expect(repo.notifications.any((n) => n.eventId == low.id), isFalse);
      expect(repo.handover.sourceEventIds, contains(low.id));
    },
  );
  test(
    'attendance and availability changes alter recipient eligibility',
    () async {
      final event = repo.eventById('event-fall')!;
      await repo.toggleAttendance();
      expect(
        repo.eligibleRecipients(event).any((s) => s.id == 'nurse-1'),
        isFalse,
      );
      await repo.toggleAttendance();
      await repo.setAvailability(Availability.onBreak);
      expect(
        repo.eligibleRecipients(event).any((s) => s.id == 'nurse-1'),
        isFalse,
      );
      await repo.setAvailability(Availability.available);
      expect(
        repo.eligibleRecipients(event).any((s) => s.id == 'nurse-1'),
        isTrue,
      );
    },
  );
  test(
    'parallel duplicate submissions use one event and one notification',
    () async {
      final result = await Future.wait([
        repo.reportEvent(draft('same-key')),
        repo.reportEvent(draft('same-key')),
      ]);
      expect(result.first.id, result.last.id);
      expect(
        repo.events.where((e) => e.idempotencyKey == 'same-key'),
        hasLength(1),
      );
      expect(
        repo.notifications.where((n) => n.eventId == result.first.id),
        hasLength(1),
      );
    },
  );
  test(
    'reading conversation cannot claim event or dismiss priority alert',
    () async {
      final notification = repo.notifications.firstWhere(
        (n) => n.eventId == 'event-fall',
      );
      await repo.markConversationRead('event-event-fall');
      expect(repo.eventById('event-fall')!.status, EventStatus.unhandled);
      expect(notification.readAt, isNull);
      expect(notification.takenChargeAt, isNull);
    },
  );
  test(
    'claiming is atomic and no second nurse can take responsibility',
    () async {
      final results = await Future.wait([
        repo
            .claimEvent('event-fall')
            .then((_) => 'claimed')
            .catchError((_) => 'rejected'),
        repo
            .claimEvent('event-fall')
            .then((_) => 'claimed')
            .catchError((_) => 'rejected'),
      ]);
      expect(results, ['claimed', 'rejected']);
      await repo.switchPersona('nurse-3');
      await expectLater(
        repo.claimEvent('event-fall'),
        throwsA(isA<StateError>()),
      );
      expect(repo.eventById('event-fall')!.claimedBy, 'nurse-1');
    },
  );
  test(
    'medium reminders precede escalation and claims stop future reminders',
    () async {
      final e = await repo.reportEvent(
        draft('deadline', type: EventType.safety),
      );
      await repo.advanceTime(const Duration(minutes: 5));
      var n = repo.notifications.firstWhere((n) => n.eventId == e.id);
      expect(n.remindedAt, isNotNull);
      expect(n.escalationLevel, 0);
      await repo.advanceTime(const Duration(minutes: 5));
      n = repo.notifications.firstWhere((n) => n.eventId == e.id);
      expect(n.escalationLevel, 1);
      expect(n.recipientIds, contains('coordinator-1'));
      await repo.switchPersona('coordinator-1');
      expect(repo.canClaim(repo.eventById(e.id)!), isTrue);
      await repo.claimEvent(e.id);
      await repo.switchPersona('nurse-1');
      final claimed = await repo.reportEvent(
        draft('claimed-deadline', type: EventType.safety),
      );
      await repo.claimEvent(claimed.id);
      await repo.advanceTime(const Duration(hours: 1));
      final stopped = repo.notifications.firstWhere(
        (n) => n.eventId == claimed.id,
      );
      expect(stopped.remindedAt, isNull);
      expect(stopped.escalationLevel, 0);
    },
  );
  test(
    'offline original occurrence persists and reconnection synchronizes exactly once',
    () async {
      await repo.setOnline(false);
      final e = await repo.reportEvent(draft('offline'));
      expect(e.syncStatus, SyncStatus.queued);
      expect(e.synchronizedAt, isNull);
      expect(repo.notifications.any((n) => n.eventId == e.id), isFalse);
      await repo.advanceTime(const Duration(minutes: 10));
      await repo.setOnline(true);
      await repo.synchronize();
      expect(repo.eventById(e.id)!.occurredAt, clock);
      expect(repo.eventById(e.id)!.syncStatus, SyncStatus.sent);
      expect(repo.notifications.where((n) => n.eventId == e.id), hasLength(1));
    },
  );
  test(
    'offline synchronization denies a revoked reporter and keeps recoverable failure',
    () async {
      await repo.switchPersona('assistant-1');
      await repo.setOnline(false);
      final e = await repo.reportEvent(draft('revoked'));
      await repo.switchPersona('admin-1');
      await repo.updateStaff('assistant-1', role: Role.management);
      await repo.setOnline(true);
      await repo.switchPersona('nurse-1');
      expect(repo.eventById(e.id)!.syncStatus, SyncStatus.failed);
      expect(repo.eventById(e.id)!.syncError, isNotNull);
      expect(repo.notifications.any((n) => n.eventId == e.id), isFalse);
    },
  );
  test(
    'plain chat does not become an event until confirmed and retries link once',
    () async {
      final before = repo.events.length;
      final message = await repo.sendMessage(
        'team-oak',
        'Please review a synthetic observation.',
      );
      expect(repo.events.length, before);
      final input = draft('from-message')..sourceMessageId = message.id;
      final e = await repo.reportEvent(input);
      final second = await repo.reportEvent(
        draft('retry-different-key')..sourceMessageId = message.id,
      );
      expect(e.id, second.id);
      expect(repo.messageById(message.id)!.text, message.text);
    },
  );
  test(
    'cross-ward IDs and assistant queries cannot reveal records or private chats',
    () async {
      expect(
        () => repo.eventById('willow-event'),
        throwsA(isA<PermissionDenied>()),
      );
      expect(
        () => repo.residentById('R-201'),
        throwsA(isA<PermissionDenied>()),
      );
      final answer = await repo.askAssistant(
        'Show Willow Ward reports for R-201.',
      );
      expect(answer.sourceEventIds, isEmpty);
      expect(
        answer.text,
        'I cannot access records outside your authorized scope.',
      );
      await repo.switchPersona('assistant-1');
      expect(
        () => repo.messagesFor('direct-emily-sarah'),
        throwsA(isA<PermissionDenied>()),
      );
      expect(
        () => repo.messagesFor('assistant-nurse-1-oak'),
        throwsA(isA<PermissionDenied>()),
      );
    },
  );
  test(
    'assistant responses reflect current authorized state and linked sources',
    () async {
      final e = await repo.reportEvent(draft('assistant-state'));
      final answer = await repo.askAssistant(
        'Show unresolved events in my ward.',
      );
      expect(answer.sourceEventIds, contains(e.id));
      await repo.claimEvent(e.id);
      await repo.closeEvent(e.id, 'Staff outcome documented.');
      final next = await repo.askAssistant(
        'Show unresolved events in my ward.',
      );
      expect(next.sourceEventIds, isNot(contains(e.id)));
    },
  );
  test(
    'OCR review preserves original extraction and does not grant physician validation',
    () async {
      await repo.switchPersona('assistant-1');
      final o = repo.ocrItems.first;
      final original = o.originalText;
      await repo.confirmOcr(o.id, 'Equipment check · 08:30.');
      expect(o.originalText, original);
      expect(o.correctedText, 'Equipment check · 08:30.');
      expect(o.reviewedBy, 'assistant-1');
      expect(o.reviewedAt, clock);
      await expectLater(
        repo.validateHandover(),
        throwsA(isA<PermissionDenied>()),
      );
    },
  );
  test(
    'handover review, physician validation, signature and incoming ack remain distinct',
    () async {
      await repo.switchPersona('coordinator-1');
      await repo.amendHandover('Follow up on the unresolved report.');
      expect(repo.handover.status, HandoverStatus.aiDraft);
      await expectLater(repo.signHandover(), throwsA(isA<StateError>()));
      await repo.reviewHandover();
      await expectLater(
        repo.validateHandover(),
        throwsA(isA<PermissionDenied>()),
      );
      await repo.switchPersona('physician-1');
      await repo.validateHandover();
      await expectLater(repo.signHandover(), throwsA(isA<PermissionDenied>()));
      await repo.switchPersona('coordinator-1');
      await repo.signHandover();
      expect(repo.handover.signedBy, 'coordinator-1');
      expect(repo.handover.validatedBy, 'physician-1');
      await expectLater(
        repo.acknowledgeHandover(),
        throwsA(isA<PermissionDenied>()),
      );
      await repo.switchPersona('nurse-1');
      await repo.acknowledgeHandover();
      expect(
        repo.handover.acknowledgements['nurse-1'],
        clock.toIso8601String(),
      );
    },
  );
  test(
    'signed handover amendments retain signed snapshot and require a new review',
    () async {
      final count = repo.handover.versions.length;
      final version = repo.handover.version;
      await repo.switchPersona('coordinator-1');
      await repo.amendHandover('Correction to staff contribution.');
      expect(repo.handover.version, version + 1);
      expect(repo.handover.versions.length, greaterThan(count));
      expect(repo.handover.signedBy, isNull);
      expect(repo.handover.status, HandoverStatus.aiDraft);
      expect(
        repo.handover.versions.any((v) => v.text.contains('coordinator-1')),
        isTrue,
      );
    },
  );
  test(
    'diary amendments never overwrite the original staff observation',
    () async {
      final e = repo.eventById('event-fall')!;
      final original = e.notes;
      await repo.amendEvent(
        e.id,
        'Occurrence place clarified by reporting staff.',
      );
      expect(e.notes, original);
      expect(e.versions, hasLength(2));
      expect(e.versions.first.text, original);
      expect(e.versions.last.authorId, 'nurse-1');
    },
  );
  test(
    'management aggregates and administrator metadata do not grant clinical access',
    () async {
      await repo.switchPersona('management-1');
      expect(repo.aggregateCounts()['events'], greaterThan(0));
      expect(() => repo.events, throwsA(isA<PermissionDenied>()));
      expect(() => repo.residents, throwsA(isA<PermissionDenied>()));
      expect(() => repo.conversations, throwsA(isA<PermissionDenied>()));
      await expectLater(
        repo.reportEvent(draft('management')),
        throwsA(isA<PermissionDenied>()),
      );
      await repo.switchPersona('admin-1');
      expect(repo.audit, isNotEmpty);
      await repo.updateStaff(
        'technician-1',
        skills: ['Equipment', 'Safety inspection'],
      );
      expect(
        repo.staffById('technician-1')!.skills,
        contains('Safety inspection'),
      );
      expect(() => repo.events, throwsA(isA<PermissionDenied>()));
      await expectLater(repo.signHandover(), throwsA(isA<PermissionDenied>()));
    },
  );
  test(
    'private message media cannot be retrieved by a different ward member',
    () async {
      final media = await repo.saveMedia(
        bytes: [1, 2, 3],
        mimeType: 'audio/wav',
        label: 'Synthetic sample',
        synthetic: true,
      );
      await repo.sendMessage(
        'direct-emily-sarah',
        'Private sample',
        mediaId: media.id,
      );
      await repo.switchPersona('assistant-1');
      expect(() => repo.mediaById(media.id), throwsA(isA<PermissionDenied>()));
      await repo.switchPersona('coordinator-1');
      expect(repo.mediaById(media.id)!.bytes, [1, 2, 3]);
    },
  );
  test(
    'drafts, outbox, chat and media survive a real SQLite close and reopen',
    () async {
      await repo.close();
      final dir = await Directory.systemTemp.createTemp('rsa-persistence-');
      final file = File('${dir.path}/demo.sqlite');
      final durable = await RsaRepository.open(
        database: RsaDatabase(NativeDatabase(file)),
        clock: () => clock,
      );
      await durable.setOnline(false);
      await durable.saveDraft(draft('saved-draft'));
      final queued = await durable.reportEvent(draft('durable-queue'));
      await durable.saveDraft(draft('next-draft'));
      final media = await durable.saveMedia(
        bytes: [4, 5, 6],
        mimeType: 'image/png',
        label: 'Synthetic photo',
        synthetic: true,
      );
      await durable.saveChatDraft('team-oak', 'Unsent text', mediaId: media.id);
      await durable.close();
      final restored = await RsaRepository.open(
        database: RsaDatabase(NativeDatabase(file)),
        clock: () => clock,
      );
      expect(restored.draft!.idempotencyKey, 'next-draft');
      expect(restored.eventById(queued.id)!.syncStatus, SyncStatus.queued);
      expect(restored.mediaById(media.id)!.bytes, [4, 5, 6]);
      expect(restored.chatDraftFor('team-oak')!['text'], 'Unsent text');
      await restored.close();
      await dir.delete(recursive: true);
    },
  );
  test(
    'Europe/Rome shift boundaries use UTC instants and exact local transitions',
    () {
      final morning = Shift.at(DateTime.utc(2026, 10, 27, 6), 'oak');
      expect(morning.label, 'Morning');
      expect(morning.startsAt, DateTime.utc(2026, 10, 27, 6));
      expect(morning.endsAt, DateTime.utc(2026, 10, 27, 13));
      expect(
        Shift.at(DateTime.utc(2026, 10, 27, 13), 'oak').label,
        'Afternoon',
      );
      expect(Shift.at(DateTime.utc(2026, 10, 27, 20), 'oak').label, 'Night');
      expect(
        Shift.at(DateTime.utc(2026, 10, 27, 5, 59, 59), 'oak').label,
        'Night',
      );
      expect(morning.contains(morning.startsAt), isTrue);
      expect(morning.contains(morning.endsAt), isFalse);
      expect(Shift.fromJson(morning.toJson()).toJson(), morning.toJson());
    },
  );
  test(
    'overnight shifts include the Europe/Rome spring and autumn DST changes',
    () {
      final spring = Shift.at(DateTime.utc(2026, 3, 28, 22), 'oak');
      expect(spring.label, 'Night');
      expect(spring.startsAt, DateTime.utc(2026, 3, 28, 20));
      expect(spring.endsAt, DateTime.utc(2026, 3, 29, 5));
      expect(
        spring.endsAt.difference(spring.startsAt),
        const Duration(hours: 9),
      );
      final autumn = Shift.at(DateTime.utc(2026, 10, 24, 22), 'oak');
      expect(autumn.startsAt, DateTime.utc(2026, 10, 24, 19));
      expect(autumn.endsAt, DateTime.utc(2026, 10, 25, 6));
      expect(
        autumn.endsAt.difference(autumn.startsAt),
        const Duration(hours: 11),
      );
    },
  );
  test(
    'typed operational views share records, attendance and rules without independent fixtures',
    () async {
      expect(repo.currentShift.contains(clock), isTrue);
      expect(
        repo.shifts.map((s) => s.label),
        containsAll(['Morning', 'Afternoon', 'Night']),
      );
      final presence = repo.attendance.firstWhere(
        (a) => a.staffId == 'nurse-1',
      );
      expect(presence.shiftId, repo.currentShift.id);
      expect(presence.checkedInAt, isNotNull);
      await repo.toggleAttendance();
      expect(
        repo.attendance.firstWhere((a) => a.staffId == 'nurse-1').onDuty,
        isFalse,
      );
      expect(repo.diaryEntries.length, repo.events.length);
      final entry = repo.diaryEntries.firstWhere(
        (d) => d.eventId == 'event-fall',
      );
      expect(entry.id, repo.eventById('event-fall')!.diaryId);
      expect(DiaryEntry.fromJson(entry.toJson()).toJson(), entry.toJson());
      expect(repo.staffSummaries.first.handoverId, repo.handover.id);
      expect(() => repo.routingRules, throwsA(isA<PermissionDenied>()));
      await repo.switchPersona('coordinator-1');
      final medium = repo.routingRules.firstWhere(
        (r) => r.priority == Priority.medium,
      );
      expect(medium.initialRoles, [Role.nurse]);
      expect(medium.quiet, isTrue);
      expect(medium.reminderAfter, const Duration(minutes: 5));
      expect(RoutingRule.fromJson(medium.toJson()).toJson(), medium.toJson());
    },
  );
  test(
    'required clinical validation cannot be bypassed by an outgoing coordinator signature',
    () async {
      await repo.switchPersona('coordinator-1');
      repo.handover.requiresClinicalValidation = true;
      expect(
        Handover.fromJson(repo.handover.toJson()).requiresClinicalValidation,
        isTrue,
      );
      await repo.amendHandover('Clinical content requiring physician review.');
      await repo.reviewHandover();
      await expectLater(repo.signHandover(), throwsA(isA<StateError>()));
      await repo.switchPersona('physician-1');
      await repo.validateHandover();
      await repo.switchPersona('coordinator-1');
      await repo.signHandover();
      expect(repo.handover.signedBy, 'coordinator-1');
      expect(repo.handover.validatedBy, 'physician-1');
    },
  );
  test(
    'ward role assignments grant combined capabilities only in the explicitly assigned ward',
    () async {
      await repo.switchPersona('admin-1');
      await repo.updateAssignments('physician-1', const [
        WardRoleAssignment(wardId: 'oak', role: Role.physician),
        WardRoleAssignment(wardId: 'oak', role: Role.coordinator),
        WardRoleAssignment(wardId: 'willow', role: Role.nurse),
      ]);
      await repo.updateStaff(
        'physician-1',
        skills: ['Nursing', 'Clinical validation'],
      );
      await repo.switchPersona('physician-1');
      expect(repo.can(Capability.clinicalValidation), isTrue);
      expect(repo.can(Capability.signHandover), isTrue);
      final serialized = StaffMember.fromJson(repo.currentUser.toJson());
      expect(serialized.can(Capability.clinicalValidation, 'oak'), isTrue);
      expect(serialized.can(Capability.clinicalValidation, 'willow'), isFalse);
      await repo.amendHandover(
        'Explicit combined roles can review this draft.',
      );
      repo.handover.requiresClinicalValidation = true;
      await repo.reviewHandover();
      await repo.validateHandover();
      await repo.signHandover();
      await repo.selectWard('willow');
      expect(repo.can(Capability.care), isTrue);
      expect(repo.can(Capability.clinicalValidation), isFalse);
      expect(repo.can(Capability.signHandover), isFalse);
      await expectLater(
        repo.validateHandover(),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(repo.signHandover(), throwsA(isA<PermissionDenied>()));
      // A nurse role in Willow must not make this person a coordinator there.
      final medium = await repo.reportEvent(
        EventDraft(
          idempotencyKey: 'ward-scoped-routing',
          type: EventType.safety,
          subject: 'Equipment',
          place: 'Corridor',
          occurredAt: clock,
        ),
      );
      expect(
        repo.eligibleRecipients(medium).map((s) => s.id),
        contains('physician-1'),
      );
      await repo.switchPersona('admin-1');
      await repo.updateAssignments('physician-1', const [
        WardRoleAssignment(wardId: 'oak', role: Role.coordinator),
        WardRoleAssignment(wardId: 'willow', role: Role.management),
      ]);
      await repo.switchPersona('physician-1');
      expect(
        () => repo.eventById('willow-event'),
        throwsA(isA<PermissionDenied>()),
      );
      expect(
        () => repo.messagesFor('team-willow'),
        throwsA(isA<PermissionDenied>()),
      );
      expect(
        () => repo.aggregateCounts(wardId: 'oak'),
        throwsA(isA<PermissionDenied>()),
      );
      expect(repo.aggregateCounts(wardId: 'willow')['events'], greaterThan(0));
    },
  );
  test('legacy staff JSON retains compatible explicit ward assignments', () {
    final legacy = repo.currentUser.toJson()..remove('assignments');
    final restored = StaffMember.fromJson(legacy);
    expect(restored.hasRole(Role.nurse, 'oak'), isTrue);
    expect(restored.can(Capability.clinicalValidation, 'oak'), isFalse);
    expect(restored.can(Capability.care, 'willow'), isFalse);
  });
  test(
    'queued mutations reject changed persona context before execution',
    () async {
      final queuedSwitch = repo.switchPersona('assistant-1');
      final staleReport = repo.reportEvent(draft('stale-context'));
      final rejection = expectLater(
        staleReport,
        throwsA(isA<PermissionDenied>()),
      );
      await queuedSwitch;
      await rejection;
      expect(repo.currentUser.id, 'assistant-1');
      expect(
        repo.events.any((e) => e.idempotencyKey == 'stale-context'),
        isFalse,
      );
    },
  );
}
