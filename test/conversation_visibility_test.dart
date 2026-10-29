import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsa/core/database.dart';
import 'package:rsa/core/models.dart';
import 'package:rsa/core/repository.dart';

void main() {
  late RsaRepository repository;
  final instant = DateTime.utc(2026, 10, 28, 10);

  setUp(() async {
    repository = await RsaRepository.open(
      database: RsaDatabase(NativeDatabase.memory()),
      clock: () => instant,
    );
  });
  tearDown(() => repository.close());

  test('event discussions appear only after this account opens them', () async {
    expect(
      repository.conversations.where((c) => c.kind == ConversationKind.event),
      isEmpty,
    );
    final original = repository.eventById('event-fall')!;
    final conversation = await repository.openEventConversation(original.id);
    expect(
      repository.conversations.map((c) => c.id),
      contains(conversation.id),
    );
    expect(repository.messagesFor(conversation.id).first.sourceEventIds, [
      original.id,
    ]);
    expect(repository.eventById(original.id)!.status, original.status);

    final same = await repository.openEventConversation(original.id);
    expect(same.id, conversation.id);
    expect(
      repository.conversations.where((c) => c.id == conversation.id),
      hasLength(1),
    );
  });

  test(
    'creating a report does not subscribe its author or recipients',
    () async {
      final event = await repository.reportEvent(
        EventDraft(
          idempotencyKey: 'unopened-event',
          type: EventType.fall,
          residentId: 'R-014',
          place: 'Bathroom',
          occurredAt: instant,
          notes: 'A staff observation.',
        ),
      );
      expect(
        repository.conversations.map((c) => c.id),
        isNot(contains(event.conversationId)),
      );
      await repository.switchPersona('coordinator-1');
      expect(
        repository.conversations.map((c) => c.id),
        isNot(contains(event.conversationId)),
      );
      expect(repository.eventById(event.id), isNotNull);
    },
  );

  test(
    'event list preferences are personal while the discussion is shared',
    () async {
      final discussion = await repository.openEventConversation('event-fall');
      await repository.sendMessage(
        discussion.id,
        'Please review this observation.',
      );
      await repository.switchPersona('assistant-1');
      expect(
        repository.conversations.map((c) => c.id),
        isNot(contains(discussion.id)),
      );
      // Event authorization remains shared within the ward; list membership is a preference.
      expect(
        repository.messagesFor(discussion.id).last.text,
        'Please review this observation.',
      );
      final joined = await repository.openEventConversation('event-fall');
      expect(joined.id, discussion.id);
      expect(
        repository.conversations.map((c) => c.id),
        contains(discussion.id),
      );
      await repository.switchPersona('nurse-1');
      expect(
        repository.conversations.map((c) => c.id),
        contains(discussion.id),
      );
    },
  );

  test(
    'new direct conversations reuse the existing pair in either direction',
    () async {
      final first = await repository.startDirectConversation('technician-1');
      final second = await repository.startDirectConversation('technician-1');
      expect(second.id, first.id);
      expect(repository.conversationTitle(first), 'Alex Morgan');
      await repository.switchPersona('technician-1');
      final reverse = await repository.startDirectConversation('nurse-1');
      expect(reverse.id, first.id);
      expect(repository.conversationTitle(reverse), 'Emily Carter');
      await repository.switchPersona('assistant-1');
      expect(
        repository.conversations.map((c) => c.id),
        isNot(contains(first.id)),
      );
      expect(
        () => repository.messagesFor(first.id),
        throwsA(isA<PermissionDenied>()),
      );
    },
  );

  test(
    'existing direct conversations show the other person to both accounts',
    () async {
      final existing = await repository.startDirectConversation(
        'coordinator-1',
      );
      expect(existing.id, 'direct-emily-sarah');
      expect(repository.conversationTitle(existing), 'Sarah Mitchell');
      await repository.switchPersona('coordinator-1');
      expect(repository.conversationTitle(existing), 'Emily Carter');
    },
  );

  test(
    'contacts and starts reject other wards, nonclinical accounts, and self',
    () async {
      final contacts = repository.conversationContacts.map((s) => s.id);
      expect(
        contacts,
        contains('nurse-2'),
      ); // Off-duty colleagues remain addressable.
      expect(contacts, isNot(contains('willow-nurse')));
      expect(contacts, isNot(contains('admin-1')));
      expect(contacts, isNot(contains('nurse-1')));
      for (final id in ['willow-nurse', 'admin-1', 'nurse-1', 'missing']) {
        await expectLater(
          repository.startDirectConversation(id),
          throwsA(isA<PermissionDenied>()),
        );
      }
      await repository.switchPersona('willow-nurse');
      await expectLater(
        repository.openEventConversation('event-fall'),
        throwsA(isA<PermissionDenied>()),
      );
      await repository.switchPersona('admin-1');
      expect(
        () => repository.conversationContacts,
        throwsA(isA<PermissionDenied>()),
      );
    },
  );

  test(
    'opened event discussions and direct conversations survive SQLite reopen',
    () async {
      await repository.close();
      final directory = await Directory.systemTemp.createTemp(
        'rsa-conversations-',
      );
      final file = File('${directory.path}/workspace.sqlite');
      RsaRepository? durable;
      try {
        durable = await RsaRepository.open(
          database: RsaDatabase(NativeDatabase(file)),
          clock: () => instant,
        );
        final event = await durable.openEventConversation('event-skin');
        final direct = await durable.startDirectConversation('technician-1');
        await durable.close();
        durable = await RsaRepository.open(
          database: RsaDatabase(NativeDatabase(file)),
          clock: () => instant,
        );
        expect(
          durable.conversations.map((c) => c.id),
          containsAll([event.id, direct.id]),
        );
        expect(
          durable.conversations.where((c) => c.kind == ConversationKind.event),
          hasLength(1),
        );
        await durable.switchPersona('assistant-1');
        expect(
          durable.conversations.map((c) => c.id),
          isNot(contains(event.id)),
        );
      } finally {
        await durable?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
