import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rsa/app/app.dart';
import 'package:rsa/core/database.dart';
import 'package:rsa/core/models.dart';
import 'package:rsa/core/providers.dart';
import 'package:rsa/core/repository.dart';
import 'package:rsa/features/events.dart';
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

  tearDown(() async {
    await repository.close();
  });

  Future<void> showApp(
    WidgetTester tester, {
    Size size = const Size(360, 800),
    double textScale = 1,
    String location = '/',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rsaRepositoryProvider.overrideWith((ref) => repository)],
        child: RsaApp(initialLocation: location),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'compact shell keeps reporting one tap away at large text scale',
    (tester) async {
      await showApp(tester, textScale: 1.3);
      expect(find.byKey(const Key('compact-navigation')), findsOneWidget);
      expect(find.byKey(const Key('expanded-navigation')), findsNothing);
      final report = find.byKey(const Key('open-report'));
      expect(report, findsOneWidget);
      await tester.tap(report);
      await tester.pumpAndSettle();
      expect(find.byType(ReportScreen), findsOneWidget);
      expect(find.byKey(const Key('report-submit')), findsOneWidget);
    },
  );

  testWidgets('expanded shell uses its own console navigation', (tester) async {
    await showApp(tester, size: const Size(1440, 1000));
    expect(find.byKey(const Key('expanded-navigation')), findsOneWidget);
    expect(find.byKey(const Key('compact-navigation')), findsNothing);
    expect(find.byKey(const Key('open-report')), findsOneWidget);
  });

  testWidgets('a narrow report submits one linked event using the visible form', (
    tester,
  ) async {
    await tester.runAsync(() => repository.switchPersona('assistant-1'));
    final before = repository.events.length;
    await showApp(tester, textScale: 1.3, location: '/report');
    final resident = repository.residents.first;
    final picker = find.byKey(const Key('resident-picker'));
    await tester.scrollUntilVisible(
      picker,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text(resident.name).last);
    await tester.pumpAndSettle();
    final notes = find.byKey(const Key('report-notes'));
    await tester.scrollUntilVisible(
      notes,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      notes,
      'Synthetic fall report from the widget test.',
    );
    tester.testTextInput.hide();
    await tester.runAsync(
      () => tester.tap(find.byKey(const Key('report-submit'))),
    );
    // Drift transactions cross the real event loop. Alternate real IO and frames
    // rather than advancing FakeAsync while the sending indicator is active.
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump();
      if (repository.events.length == before + 1 &&
          find.byKey(const Key('report-submit')).evaluate().isEmpty) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pumpAndSettle();

    expect(repository.events.length, before + 1);
    final event = repository.events.firstWhere(
      (event) => event.notes == 'Synthetic fall report from the widget test.',
    );
    expect(event.type, EventType.fall);
    expect(event.priority, Priority.high);
    expect(event.residentId, resident.id);
    expect(event.syncStatus, SyncStatus.sent);
    expect(repository.handover.sourceEventIds, contains(event.id));
    expect(
      repository.conversations.any((thread) => thread.eventId == event.id),
      isTrue,
    );
  });

  testWidgets('management cannot open a clinical deep link', (tester) async {
    await tester.runAsync(() => repository.switchPersona('management-1'));
    await showApp(tester, location: '/report');
    expect(find.byType(ReportScreen), findsNothing);
    expect(find.byKey(const Key('open-report')), findsNothing);
    expect(repository.can(Capability.report), isFalse);
  });

  testWidgets('administrator cannot access a guessed event route', (
    tester,
  ) async {
    await tester.runAsync(() => repository.switchPersona('admin-1'));
    await showApp(tester, location: '/event/event-fall');
    expect(find.byType(EventDetailScreen), findsNothing);
    expect(find.byKey(const Key('open-report')), findsNothing);
    final scaffold = find.byType(Scaffold).first;
    final location = GoRouter.of(
      tester.element(scaffold),
    ).routeInformationProvider.value.uri.path;
    expect(location, isNot(startsWith('/event/')));
  });
  testWidgets('switching to management clears previously opened care screens', (
    tester,
  ) async {
    await showApp(tester, location: '/event/event-fall');
    expect(find.byType(EventDetailScreen), findsOneWidget);
    await tester.runAsync(() => repository.switchPersona('management-1'));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsNothing);
    expect(find.byKey(const Key('open-report')), findsNothing);
  });

  Future<void> drainUpdates(WidgetTester tester, bool Function() ready) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump();
      if (ready() &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pumpAndSettle();
    expect(
      ready(),
      isTrue,
      reason: 'The persisted UI action did not complete.',
    );
  }

  for (final size in [const Size(360, 950), const Size(1440, 1000)]) {
    testWidgets('home is free of demo controls at ${size.width}px', (
      tester,
    ) async {
      await showApp(tester, size: size, textScale: size.width < 500 ? 1.3 : 1);
      expect(find.text('Demo data'), findsNothing);
      expect(find.text('Demo controls'), findsNothing);
      expect(find.text('Connected'), findsNothing);
      expect(find.text('A connected shift. A shared picture.'), findsNothing);
      expect(find.textContaining('Demo workspace'), findsNothing);
      expect(find.byTooltip('Open demo controls'), findsNothing);
      expect(repository.currentUser.onDuty, isTrue);
      expect(repository.currentUser.availability, Availability.available);
      final card = find.byKey(const Key('shift-attendance-card'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.text(repository.activeWard.name),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text(repository.currentUser.role.label),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining(
            formatTime(repository.currentShift.startsAt),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining(
            formatTime(repository.currentShift.endsAt),
          ),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'home availability and attendance controls update shared routing state',
    (tester) async {
      await showApp(tester, size: const Size(1440, 1000));
      final card = find.byKey(const Key('shift-attendance-card'));
      final event = repository.eventById('event-fall')!;
      for (final availability in [
        Availability.busy,
        Availability.onBreak,
        Availability.available,
      ]) {
        await tester.runAsync(
          () =>
              tester.tap(find.byKey(Key('availability-${availability.name}'))),
        );
        await drainUpdates(
          tester,
          () => repository.currentUser.availability == availability,
        );
        if (availability == Availability.onBreak) {
          expect(
            repository
                .eligibleRecipients(event)
                .any((s) => s.id == repository.currentUser.id),
            isFalse,
          );
        }
      }
      expect(repository.currentUser.onDuty, isTrue);
      await tester.runAsync(
        () => tester.tap(find.byKey(const Key('shift-toggle-attendance'))),
      );
      await drainUpdates(tester, () => !repository.currentUser.onDuty);
      expect(
        find.descendant(of: card, matching: find.text('Check in')),
        findsOneWidget,
      );
      expect(
        repository
            .eligibleRecipients(event)
            .any((s) => s.id == repository.currentUser.id),
        isFalse,
      );
      await tester.runAsync(
        () => tester.tap(find.byKey(const Key('shift-toggle-attendance'))),
      );
      await drainUpdates(tester, () => repository.currentUser.onDuty);
      expect(
        find.descendant(of: card, matching: find.text('Check out')),
        findsOneWidget,
      );
      expect(
        repository
            .eligibleRecipients(event)
            .any((s) => s.id == repository.currentUser.id),
        isTrue,
      );
    },
  );

  testWidgets('attendance remains a single action while its save is pending', (
    tester,
  ) async {
    late _DelayedAttendanceRepository delayed;
    await tester.runAsync(() async {
      await repository.close();
      delayed = _DelayedAttendanceRepository(
        RsaDatabase(NativeDatabase.memory()),
      );
      await delayed.initialize();
      repository = delayed;
    });
    addTearDown(() {
      if (!delayed.saveGate.isCompleted) delayed.saveGate.complete();
    });
    await showApp(tester, size: const Size(1440, 1000));
    final button = find.byKey(const Key('shift-toggle-attendance'));
    await tester.runAsync(() => tester.tap(button));
    await tester.pump();
    expect(delayed.toggleCalls, 1);
    expect(repository.currentUser.onDuty, isTrue);
    await tester.runAsync(() => tester.tap(button));
    await tester.runAsync(
      () => tester.tap(find.byKey(const Key('availability-busy'))),
    );
    await tester.pump();
    expect(delayed.toggleCalls, 1);
    expect(repository.currentUser.availability, Availability.available);
    delayed.saveGate.complete();
    await drainUpdates(tester, () => !repository.currentUser.onDuty);
  });

  testWidgets('saving a correction preserves the report and dismisses safely', (
    tester,
  ) async {
    final original = repository.eventById('event-fall')!;
    final notes = original.notes;
    final versions = original.versions.length;
    await showApp(
      tester,
      size: const Size(1440, 1100),
      location: '/event/event-fall',
    );
    final correctionButton = find.text('Add correction');
    await tester.scrollUntilVisible(
      correctionButton,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(correctionButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Correction: the location was the corridor.',
    );
    await tester.tap(find.text('Save correction'));
    await drainUpdates(
      tester,
      () =>
          repository.eventById('event-fall')!.versions.length == versions + 1 &&
          find.text('Correction added to history.').evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.eventById('event-fall')!.notes, notes);
    expect(
      repository.eventById('event-fall')!.versions.last.text,
      'Correction: the location was the corridor.',
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Version history'));
    await tester.pumpAndSettle();
    expect(
      find.text('Correction: the location was the corridor.'),
      findsWidgets,
    );
    expect(find.text(notes), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
  });

  testWidgets('cancelling a correction leaves its report unchanged', (
    tester,
  ) async {
    final count = repository.eventById('event-fall')!.versions.length;
    await showApp(
      tester,
      size: const Size(1440, 1100),
      location: '/event/event-fall',
    );
    final button = find.text('Add correction');
    await tester.scrollUntilVisible(
      button,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Unsubmitted draft');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.eventById('event-fall')!.versions.length, count);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
  });

  testWidgets('closing an event records its outcome and dismisses safely', (
    tester,
  ) async {
    await showApp(
      tester,
      size: const Size(1440, 1100),
      location: '/event/event-skin',
    );
    final button = find.text('Close event');
    await tester.scrollUntilVisible(
      button,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Follow-up documented by staff.',
    );
    await tester.runAsync(
      () => tester.tap(
        find.widgetWithText(FilledButton, 'Save outcome and close'),
      ),
    );
    await drainUpdates(
      tester,
      () =>
          repository.eventById('event-skin')!.status == EventStatus.closed &&
          find.text('Event closed').evaluate().isNotEmpty,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      repository.eventById('event-skin')!.outcome,
      'Follow-up documented by staff.',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
  });

  testWidgets(
    'account settings do not expose role switching or development tools',
    (tester) async {
      await showApp(tester, location: '/settings');
      expect(find.text('Demo persona'), findsNothing);
      expect(find.text('Reset demo data'), findsNothing);
      expect(find.text(repository.currentUser.name), findsWidgets);
      expect(find.text(repository.activeWard.name), findsWidgets);
      expect(find.text('Europe/Rome'), findsWidgets);
    },
  );

  testWidgets(
    'development controls cannot be opened through a default-build deep link',
    (tester) async {
      await showApp(tester, location: '/development');
      expect(find.text('Demo persona'), findsNothing);
      expect(find.text('Reset demo data'), findsNothing);
      final location = GoRouter.of(
        tester.element(find.byType(Scaffold).first),
      ).routeInformationProvider.value.uri.path;
      expect(location, isNot('/development'));
    },
  );
}

class _DelayedAttendanceRepository extends RsaRepository {
  final saveGate = Completer<void>();
  int toggleCalls = 0;
  _DelayedAttendanceRepository(super.database)
    : super(clock: () => DateTime.utc(2026, 10, 27, 8));
  @override
  Future<void> toggleAttendance() async {
    toggleCalls++;
    await saveGate.future;
    await super.toggleAttendance();
  }
}
