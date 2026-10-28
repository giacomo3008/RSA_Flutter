import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rsa/app/app.dart';
import 'package:rsa/core/models.dart';
import 'package:rsa/core/providers.dart';
import 'package:rsa/core/repository.dart';
import 'package:rsa/features/events.dart';
import 'package:rsa/shared/ui.dart';

/// Run in an isolated test app/browser profile: this resets synthetic demo data.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('report → inbox → take charge → diary → handover', (
    tester,
  ) async {
    final frameworkErrors = <String>[];
    binding.reportData = {'frameworkErrors': frameworkErrors};
    final originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      frameworkErrors.add(details.toString());
      originalErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalErrorHandler);
    await loadTranslations();
    final repository = await RsaRepository.open();
    addTearDown(repository.close);
    await repository.reset();
    await repository.switchPersona('assistant-1');
    final resident = repository.residents.first;
    final note =
        'Synthetic integration report ${repository.now.toIso8601String()}';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rsaRepositoryProvider.overrideWith((ref) => repository)],
        child: const RsaApp(initialLocation: '/report'),
      ),
    );
    await tester.pumpAndSettle();
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
    await tester.enterText(notes, note);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('report-submit')));
    await _waitUntil(
      tester,
      () =>
          repository.events.any((entry) => entry.notes == note) &&
          find.byKey(const Key('report-submit')).evaluate().isEmpty,
      'the report is persisted and the form displays its result',
    );

    final event = repository.events.singleWhere((entry) => entry.notes == note);
    expect(event.status, EventStatus.unhandled);
    expect(event.syncStatus, SyncStatus.sent);
    expect(repository.messagesFor(event.conversationId).first.text, note);
    await repository.switchPersona('nurse-1');
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/inbox');
    await tester.pumpAndSettle();
    expect(find.byType(InboxScreen), findsOneWidget);
    expect(repository.inboxEvents.map((entry) => entry.id), contains(event.id));
    // Opening the thread must not claim operational responsibility.
    await repository.openEventConversation(event.id);
    router.go('/chat/${event.conversationId}');
    await tester.pumpAndSettle();
    expect(repository.eventById(event.id)!.claimedBy, isNull);
    router.go('/event/${event.id}');
    await tester.pumpAndSettle();
    final takeCharge = find.text('Take charge');
    await tester.ensureVisible(takeCharge.first);
    await tester.tap(takeCharge.first);
    await _waitUntil(
      tester,
      () => repository.eventById(event.id)!.claimedBy == 'nurse-1',
      'the explicit claim is recorded',
    );
    expect(repository.eventById(event.id)!.claimedBy, 'nurse-1');
    final correction = 'Follow-up correction to the original observation.';
    final originalNotes = repository.eventById(event.id)!.notes;
    final originalVersions = repository.eventById(event.id)!.versions.length;
    final addCorrection = find.text('Add correction');
    await tester.scrollUntilVisible(
      addCorrection,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(addCorrection);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, correction);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('Save correction'));
    await _waitUntil(
      tester,
      () =>
          repository.eventById(event.id)!.versions.length ==
              originalVersions + 1 &&
          find.byType(AlertDialog).evaluate().isEmpty,
      'the correction is saved and its dialog safely closes',
    );
    expect(repository.eventById(event.id)!.notes, originalNotes);
    expect(repository.eventById(event.id)!.versions.last.text, correction);
    router.go('/diary');
    await tester.pumpAndSettle();
    expect(find.byType(DiaryScreen), findsOneWidget);
    expect(repository.events.any((entry) => entry.id == event.id), isTrue);
    router.go('/handover');
    await tester.pumpAndSettle();
    expect(repository.handover.sourceEventIds, contains(event.id));
    // The original signature remains a historical version; new sources need review.
    expect(repository.handover.status, HandoverStatus.aiDraft);
    expect(repository.handover.versions, isNotEmpty);
  });
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() predicate,
  String description,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting until $description.');
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}
