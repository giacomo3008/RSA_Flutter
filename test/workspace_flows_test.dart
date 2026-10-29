import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rsa/app/app.dart';
import 'package:rsa/core/database.dart';
import 'package:rsa/core/models.dart';
import 'package:rsa/core/providers.dart';
import 'package:rsa/core/session.dart';
import 'package:rsa/core/repository.dart';
import 'package:rsa/shared/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RsaRepository repository;

  setUp(() async {
    await loadTranslations();
    repository = await RsaRepository.open(
      database: RsaDatabase(NativeDatabase.memory()),
      clock: () => DateTime.utc(2026, 10, 27, 8),
    );
  });

  tearDown(() async => repository.close());

  Future<void> showApp(
    WidgetTester tester, {
    required String location,
    Size size = const Size(1440, 1100),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rsaRepositoryProvider.overrideWith((ref) => repository),
          accessSessionProvider.overrideWith(
            (ref) => AccessSession(signedIn: true),
          ),
        ],
        child: RsaApp(initialLocation: location),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repository.close);
    });
  }

  Future<void> drain(WidgetTester tester, bool Function() ready) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (ready()) {
        await tester.pumpAndSettle();
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    fail('The visible workflow did not finish.');
  }

  Future<void> finish(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
  }

  testWidgets('event conversations appear only after Open chat is selected', (
    tester,
  ) async {
    expect(
      repository.conversations.where((c) => c.kind == ConversationKind.event),
      isEmpty,
    );
    final event = repository.eventById('event-fall')!;
    final originalStatus = event.status;
    await showApp(tester, location: '/event/${event.id}');
    final open = find.byKey(const Key('open-event-chat'));
    await tester.scrollUntilVisible(
      open,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(open);
    await drain(
      tester,
      () =>
          repository.conversations.any((c) => c.eventId == event.id) &&
          find.byKey(const Key('new-conversation')).evaluate().isNotEmpty,
    );
    expect(repository.eventById(event.id)!.status, originalStatus);
    expect(
      repository.conversations.where((c) => c.kind == ConversationKind.event),
      hasLength(1),
    );
    expect(find.text('Conversations'), findsOneWidget);
    await finish(tester);
  });

  testWidgets(
    'the plus chooser starts a conversation with eligible ward staff',
    (tester) async {
      await showApp(tester, location: '/chat');
      await tester.tap(find.byKey(const Key('new-conversation')));
      await tester.pumpAndSettle();
      final search = find.byKey(const Key('conversation-contact-search'));
      await tester.enterText(search, 'Alex Morgan');
      await tester.pumpAndSettle();
      final colleague = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ListTile, 'Alex Morgan'),
      );
      expect(colleague, findsOneWidget);
      expect(find.text('Lucas Bennett'), findsNothing);
      await tester.tap(colleague);
      await drain(
        tester,
        () =>
            repository.conversations.any(
              (c) =>
                  c.kind == ConversationKind.direct &&
                  c.memberIds.contains('technician-1'),
            ) &&
            find.byType(AlertDialog).evaluate().isEmpty,
      );
      expect(find.text('Alex Morgan'), findsWidgets);
      expect(
        GoRouter.of(
          tester.element(find.byType(Scaffold).first),
        ).routeInformationProvider.value.uri.path,
        startsWith('/chat/'),
      );
      await finish(tester);
    },
  );

  testWidgets('choosing an existing colleague reopens the same direct chat', (
    tester,
  ) async {
    final before = repository.conversations
        .where((c) => c.kind == ConversationKind.direct)
        .length;
    await showApp(tester, location: '/chat');
    await tester.tap(find.byKey(const Key('new-conversation')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('conversation-contact-search')),
      'Sarah Mitchell',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ListTile, 'Sarah Mitchell'),
      ),
    );
    await drain(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
    expect(
      repository.conversations.where((c) => c.kind == ConversationKind.direct),
      hasLength(before),
    );
    await finish(tester);
  });

  testWidgets(
    'document review requires explicit confirmation and retains extraction',
    (tester) async {
      final document = repository.ocrItems.first;
      final original = document.originalText;
      await showApp(tester, location: '/documents');
      expect(find.text('Source image unavailable'), findsOneWidget);
      expect(find.text('Unvalidated extraction'), findsOneWidget);
      final confirm = find.byKey(const Key('confirm-document-review'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      final text = find.byKey(const Key('document-transcription'));
      await tester.ensureVisible(text);
      await tester.enterText(text, 'Equipment check at 08:30, source checked.');
      tester.testTextInput.hide();
      await tester.scrollUntilVisible(
        find.byKey(const Key('document-review-confirmation')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('document-review-confirmation')));
      await tester.pump();
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await drain(
        tester,
        () =>
            document.reviewedAt != null &&
            find.text('Transcription confirmed').evaluate().isNotEmpty,
      );
      expect(document.originalText, original);
      expect(
        document.correctedText,
        'Equipment check at 08:30, source checked.',
      );
      expect(document.reviewedBy, repository.currentUser.id);
      expect(repository.can(Capability.clinicalValidation), isFalse);
      expect(find.byKey(const Key('document-transcription')), findsNothing);
      await finish(tester);
    },
  );

  testWidgets(
    'a confirmed transcription correction adds another attributable version',
    (tester) async {
      final document = repository.ocrItems.first;
      final original = document.originalText;
      await tester.runAsync(
        () =>
            repository.confirmOcr(document.id, 'First reviewed transcription.'),
      );
      final before = document.versions.length;
      await showApp(tester, location: '/documents');
      final correction = find.text('Add correction');
      await tester.scrollUntilVisible(
        correction,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(correction);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('document-transcription')),
        'Corrected reviewed transcription.',
      );
      tester.testTextInput.hide();
      await tester.scrollUntilVisible(
        find.byKey(const Key('document-review-confirmation')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('document-review-confirmation')));
      await tester.pump();
      final confirm = find.byKey(const Key('confirm-document-review'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await drain(
        tester,
        () =>
            document.versions.length == before + 1 &&
            find.text('Transcription confirmed').evaluate().isNotEmpty,
      );
      expect(document.originalText, original);
      expect(document.versions.first.text, 'First reviewed transcription.');
      expect(document.versions.last.text, 'Corrected reviewed transcription.');
      await finish(tester);
    },
  );

  testWidgets('a signed handover is read only for the incoming nurse', (
    tester,
  ) async {
    await showApp(tester, location: '/handover');
    expect(find.byKey(const Key('handover-add-amendment')), findsNothing);
    expect(find.byKey(const Key('handover-edit-draft')), findsNothing);
    expect(find.byKey(const Key('handover-sign')), findsNothing);
    expect(find.byKey(const Key('handover-prepare-draft')), findsNothing);
    expect(find.text('Signed handover'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('coordinator amendment and editing require a fresh review', (
    tester,
  ) async {
    await tester.runAsync(() => repository.switchPersona('coordinator-1'));
    final oldVersion = repository.handover.version;
    await showApp(tester, location: '/handover');
    await tester.tap(find.byKey(const Key('handover-add-amendment')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('handover-amendment-note')),
      'Updated care information for the incoming team.',
    );
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.byKey(const Key('handover-amendment-save')));
    await drain(
      tester,
      () =>
          repository.handover.version == oldVersion + 1 &&
          find
              .text(
                'New draft version opened. The signed version is preserved.',
              )
              .evaluate()
              .isNotEmpty,
    );
    expect(repository.handover.signedBy, isNull);
    final edit = find.byKey(const Key('handover-edit-draft'));
    final handoverScroll = find
        .descendant(
          of: find.byKey(const Key('handover-screen')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(edit, 350, scrollable: handoverScroll);
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('handover-draft-editor')),
      'Reviewed observations and outstanding follow-up for the next team.',
    );
    tester.testTextInput.hide();
    final save = find.byKey(const Key('handover-save-draft'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await drain(
      tester,
      () =>
          find.byKey(const Key('handover-draft-editor')).evaluate().isEmpty &&
          repository.handover.draftText ==
              'Reviewed observations and outstanding follow-up for the next team.' &&
          tester
                  .widget<OutlinedButton>(
                    find.byKey(const Key('handover-mark-reviewed')),
                  )
                  .onPressed !=
              null,
    );
    final review = find.byKey(const Key('handover-mark-reviewed'));
    await tester.ensureVisible(review);
    await tester.pumpAndSettle();
    await tester.tap(review);
    await drain(
      tester,
      () =>
          repository.handover.status == HandoverStatus.reviewed &&
          tester.widget<OutlinedButton>(edit).onPressed != null,
    );
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('handover-draft-editor')),
      'Further corrected observations before signing.',
    );
    tester.testTextInput.hide();
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await drain(
      tester,
      () =>
          repository.handover.status == HandoverStatus.aiDraft &&
          find.byKey(const Key('handover-draft-editor')).evaluate().isEmpty,
    );
    expect(repository.handover.reviewedBy, isNull);
    expect(repository.handover.validatedBy, isNull);
    expect(repository.handover.versions, isNotEmpty);
    await finish(tester);
  });

  testWidgets(
    'viewing an older signed handover cannot acknowledge the current version',
    (tester) async {
      await tester.runAsync(() async {
        await repository.switchPersona('coordinator-1');
        await repository.amendHandover(
          'Updated information for the next team.',
        );
        await repository.reviewHandover();
        await repository.signHandover();
        await repository.switchPersona('nurse-1');
      });
      final currentVersion = repository.handover.version;
      await showApp(tester, location: '/handover');
      expect(find.byKey(const Key('handover-acknowledge')), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Version ${currentVersion - 1} · Signed').last,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('handover-acknowledge')), findsNothing);
      expect(repository.handover.acknowledgements, isEmpty);
      final back = find.byKey(const Key('handover-back-to-current'));
      await tester.ensureVisible(back);
      await tester.pumpAndSettle();
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('handover-acknowledge')), findsOneWidget);
      expect(repository.handover.version, currentVersion);
      await finish(tester);
    },
  );

  testWidgets(
    'retained ward records display after their authors leave the ward',
    (tester) async {
      await tester.runAsync(() async {
        await repository.switchPersona('coordinator-1');
        await repository.confirmOcr(
          'ocr-oak',
          'Reviewed before ward reassignment.',
        );
        await repository.switchPersona('admin-1');
        await repository.updateAssignments('coordinator-1', const [
          WardRoleAssignment(wardId: 'willow', role: Role.coordinator),
        ]);
        await repository.updateAssignments('assistant-1', const [
          WardRoleAssignment(wardId: 'willow', role: Role.assistant),
        ]);
        await repository.switchPersona('nurse-1');
      });
      await showApp(tester, location: '/handover');
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      expect(find.textContaining('coordinator-1'), findsWidgets);
      expect(tester.takeException(), isNull);
      for (final route in [
        '/event/event-fall',
        '/documents',
        '/chat/team-oak',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Lucas Bennett'), findsNothing);
        expect(find.text('Willow Ward'), findsNothing);
        if (route == '/event/event-fall') {
          expect(find.text('assistant-1'), findsWidgets);
        } else if (route == '/documents') {
          expect(find.textContaining('coordinator-1'), findsWidgets);
        } else {
          expect(find.text('coordinator-1'), findsWidgets);
          expect(find.text('assistant-1'), findsWidgets);
        }
      }
      expect(repository.eventById('event-fall')!.authorId, 'assistant-1');
      expect(repository.handover.signedBy, 'coordinator-1');
      expect(repository.ocrItems.first.reviewedBy, 'coordinator-1');
      // The chat records its read position after the first frame. Let that
      // asynchronous transaction finish before closing this test database.
      await drain(tester, () => repository.unreadCount('team-oak') == 0);
      await finish(tester);
    },
  );

  for (final target in [
    ('/chat', 'nurse-1'),
    ('/documents', 'nurse-1'),
    ('/handover', 'nurse-1'),
    ('/coordination', 'coordinator-1'),
    ('/clinical', 'physician-1'),
    ('/management', 'management-1'),
    ('/admin', 'admin-1'),
  ]) {
    testWidgets('${target.$1} remains usable on a phone with enlarged text', (
      tester,
    ) async {
      await tester.runAsync(() => repository.switchPersona(target.$2));
      await showApp(
        tester,
        location: target.$1,
        size: const Size(360, 800),
        textScale: 1.3,
      );
      // Lazily built content must also lay out without horizontal overflow.
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 8; i++) {
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await finish(tester);
    });
  }
}
