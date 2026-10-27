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
}
