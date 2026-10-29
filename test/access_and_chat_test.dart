import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rsa/app/app.dart';
import 'package:rsa/core/database.dart';
import 'package:rsa/core/providers.dart';
import 'package:rsa/core/repository.dart';
import 'package:rsa/core/session.dart';
import 'package:rsa/features/access.dart';
import 'package:rsa/features/account.dart';
import 'package:rsa/features/workspace.dart';
import 'package:rsa/shared/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RsaRepository repository;
  setUp(() async {
    await loadTranslations();
    repository = await RsaRepository.open(
      database: RsaDatabase(NativeDatabase.memory()),
      clock: () => DateTime.utc(2026, 10, 29, 8),
    );
  });
  tearDown(() => repository.close());

  Future<void> show(
    WidgetTester tester, {
    String location = '/',
    Size size = const Size(1440, 1000),
    double textScale = 1,
    AccessSession? session,
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
          if (session != null)
            accessSessionProvider.overrideWith((ref) => session),
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

  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first));

  Future<void> drain(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 150; i++) {
      await tester.pump();
      if (ready()) {
        await tester.pumpAndSettle();
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    fail('The persisted action did not finish.');
  }

  Future<void> finish(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
  }

  testWidgets('a fresh application starts at login without the care shell', (
    tester,
  ) async {
    await show(tester);
    expect(find.byType(AccessScreen), findsOneWidget);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(router(tester).routeInformationProvider.value.uri.path, '/login');
    expect(find.byType(WorkspaceShell), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    await finish(tester);
  });

  testWidgets('signed-out deep links and unknown paths return to login', (
    tester,
  ) async {
    await show(tester, location: '/chat/direct-emily-sarah');
    for (final path in [
      '/home',
      '/settings',
      '/event/event-fall',
      '/documents',
      '/admin',
      '/unknown',
    ]) {
      router(tester).go(path);
      await tester.pumpAndSettle();
      expect(router(tester).routeInformationProvider.value.uri.path, '/login');
      expect(find.byType(AccessScreen), findsOneWidget);
      expect(find.byType(WorkspaceShell), findsNothing);
    }
    await finish(tester);
  });

  testWidgets(
    'empty login enters Emily in Oak even after a different saved account',
    (tester) async {
      await tester.runAsync(() async {
        await repository.switchPersona('admin-1');
        await repository.selectWard('willow');
      });
      await show(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('login-email')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.tap(find.byKey(const Key('login-submit')));
      await drain(tester, () => find.byType(HomeScreen).evaluate().isNotEmpty);
      expect(repository.currentUser.id, 'nurse-1');
      expect(repository.activeWard.id, 'oak');
      expect(find.byType(AccessScreen), findsNothing);
      expect(find.byIcon(Icons.tune), findsNothing);
      expect(find.byKey(const Key('account-menu')), findsOneWidget);
      await finish(tester);
    },
  );

  testWidgets(
    'old registration links return to login without signup controls',
    (tester) async {
      await show(tester, location: '/register');
      expect(find.text('Registration'), findsNothing);
      expect(find.byKey(const Key('register-name')), findsNothing);
      expect(find.byType(WorkspaceShell), findsNothing);
      expect(router(tester).routeInformationProvider.value.uri.path, '/login');
      expect(find.byKey(const Key('login-submit')), findsOneWidget);
      await finish(tester);
    },
  );

  testWidgets(
    'logout requires confirmation and removes retained protected navigation',
    (tester) async {
      final session = AccessSession(signedIn: true);
      await show(tester, location: '/settings', session: session);
      final logOut = find.byKey(const Key('account-log-out'));
      await tester.ensureVisible(logOut);
      await tester.tap(logOut);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('logout-confirmation')), findsOneWidget);
      await tester.tap(find.byKey(const Key('logout-cancel')));
      await tester.pumpAndSettle();
      expect(session.isSignedIn, isTrue);
      expect(find.byType(AccountScreen), findsOneWidget);
      await tester.tap(logOut);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logout-confirm')));
      await tester.pumpAndSettle();
      expect(session.isSignedIn, isFalse);
      expect(find.byType(AccessScreen), findsOneWidget);
      expect(find.byType(WorkspaceShell), findsNothing);
      expect(find.byType(AccountScreen), findsNothing);
      expect(router(tester).canPop(), isFalse);
      router(tester).go('/settings');
      await tester.pumpAndSettle();
      expect(router(tester).routeInformationProvider.value.uri.path, '/login');
      await tester.tap(find.byKey(const Key('login-submit')));
      await drain(tester, () => find.byType(HomeScreen).evaluate().isNotEmpty);
      expect(session.isSignedIn, isTrue);
      await finish(tester);
    },
  );

  testWidgets('login fits a phone with larger text', (tester) async {
    await show(
      tester,
      location: '/login',
      size: const Size(320, 720),
      textScale: 1.3,
    );
    final action = find.byKey(const Key('login-submit'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    expect(action.hitTestable(), findsOneWidget);
    await finish(tester);
  });

  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets(
      'first conversation opens without a route or initial-scroll animation at ${size.width}px',
      (tester) async {
        await tester.runAsync(() async {
          for (var i = 0; i < 30; i++) {
            await repository.sendMessage(
              'direct-emily-sarah',
              'Chat regression observation $i.',
            );
          }
        });
        await show(
          tester,
          location: '/chat',
          size: size,
          session: AccessSession(signedIn: true),
        );
        final title = find.text('Sarah Mitchell');
        await tester.tap(title.first);
        await tester.pump();
        final messages = find.byKey(const Key('conversation-messages'));
        expect(messages, findsOneWidget);
        expect(tester.widget<ListView>(messages).reverse, isTrue);
        final position = tester.widget<ListView>(messages).controller!.position;
        expect(position.pixels, position.minScrollExtent);
        expect(
          find
              .descendant(
                of: messages,
                matching: find.text('Chat regression observation 29.'),
              )
              .hitTestable(),
          findsOneWidget,
        );
        final pages = tester
            .widgetList<Navigator>(find.byType(Navigator))
            .expand((navigator) => navigator.pages)
            .whereType<NoTransitionPage>();
        expect(pages.length, greaterThanOrEqualTo(2));
        await tester.pump(const Duration(milliseconds: 150));
        expect(position.pixels, position.minScrollExtent);
        await drain(
          tester,
          () =>
              repository.unreadCount('direct-emily-sarah') == 0 &&
              (size.width < 700 || repository.unreadCount('team-oak') == 0),
        );
        await finish(tester);
      },
    );
  }
}
