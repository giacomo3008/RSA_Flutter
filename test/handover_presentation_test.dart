import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsa/app/app.dart';
import 'package:rsa/core/database.dart';
import 'package:rsa/core/models.dart';
import 'package:rsa/core/providers.dart';
import 'package:rsa/core/session.dart';
import 'package:rsa/core/repository.dart';
import 'package:rsa/features/handover_history.dart';
import 'package:rsa/features/handover_record_content.dart';
import 'package:rsa/shared/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RsaRepository r;
  final clock = DateTime.utc(2026, 10, 29, 8);
  setUp(() async {
    await loadTranslations();
    r = await RsaRepository.open(
      database: RsaDatabase(NativeDatabase.memory()),
      clock: () => clock,
    );
  });
  tearDown(() => r.close());

  String signedFields(Handover h) {
    final json = h.toJson()..remove('pendingContributions');
    return jsonEncode(json);
  }

  test(
    'a late staff update preserves the complete signed version and receipts',
    () async {
      await r.acknowledgeHandover();
      final before = signedFields(r.handover);
      await r.contributeSummary(
        'The wheelchair inspection still needs follow-up.',
      );
      expect(signedFields(r.handover), before);
      expect(r.handover.pendingContributions.single.authorId, 'nurse-1');
      expect(r.handover.pendingContributions.single.createdAt, clock);
      await expectLater(
        r.includePendingHandoverUpdates(
          expectedHandoverId: r.handover.id,
          expectedVersion: r.handover.version,
        ),
        throwsA(isA<PermissionDenied>()),
      );
      expect(signedFields(r.handover), before);
    },
  );

  test(
    'coordinator inclusion opens a reviewed-source draft and retains authorship',
    () async {
      await r.acknowledgeHandover();
      final oldVersion = r.handover.version;
      final oldText = r.handoverText();
      await r.contributeSummary('New factual information for the next team.');
      await r.switchPersona('coordinator-1');
      await r.includePendingHandoverUpdates(
        expectedHandoverId: r.handover.id,
        expectedVersion: oldVersion,
      );
      expect(r.handover.version, oldVersion + 1);
      expect(r.handover.signedBy, isNull);
      expect(r.handover.reviewedBy, isNull);
      expect(r.handover.acknowledgements, isEmpty);
      expect(r.handover.pendingContributions, isEmpty);
      expect(r.handover.contributions.last.authorId, 'nurse-1');
      expect(
        r.handoverText(),
        contains('New factual information for the next team.'),
      );
      final archive = handoverVersionData(r.handover.versions.last);
      expect(archive['narrative'], oldText);
      expect(archive['acknowledgements']['nurse-1'], clock.toIso8601String());
      await expectLater(r.signHandover(), throwsStateError);
      await r.reviewHandover();
      await r.signHandover();
      expect(r.handover.signedBy, 'coordinator-1');
    },
  );

  test('updates reject a stale document selection or version', () async {
    await expectLater(
      r.contributeSummary('Wrong version', expectedVersion: 99),
      throwsStateError,
    );
    await expectLater(
      r.contributeSummary('Wrong record', expectedHandoverId: 'other-record'),
      throwsStateError,
    );
    expect(r.handover.pendingContributions, isEmpty);
    final roundTrip = Handover.fromJson(
      r.handover.toJson()..remove('pendingContributions'),
    );
    expect(roundTrip.pendingContributions, isEmpty);
  });

  test('pending updates survive a real SQLite close and reopen', () async {
    await r.close();
    final dir = await Directory.systemTemp.createTemp('rsa-handover-updates-');
    final file = File('${dir.path}/state.sqlite');
    var stored = await RsaRepository.open(
      database: RsaDatabase(NativeDatabase(file)),
      clock: () => clock,
    );
    try {
      await stored.contributeSummary('Persist this late update.');
      await stored.close();
      stored = await RsaRepository.open(
        database: RsaDatabase(NativeDatabase(file)),
        clock: () => clock,
      );
      expect(
        stored.handover.pendingContributions.single.text,
        'Persist this late update.',
      );
      expect(stored.handover.version, 1);
      expect(stored.handover.signedBy, 'coordinator-1');
    } finally {
      await stored.close();
      await dir.delete(recursive: true);
    }
  });

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rsaRepositoryProvider.overrideWith((ref) => r),
          accessSessionProvider.overrideWith(
            (ref) => AccessSession(signedIn: true),
          ),
        ],
        child: const RsaApp(initialLocation: '/handover'),
      ),
    );
    await tester.pumpAndSettle();
  }

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
    fail('The persisted UI action did not finish.');
  }

  Future<void> finish(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(r.close);
  }

  testWidgets(
    'signed handover accepts a late update without reopening the document',
    (tester) async {
      await show(tester);
      final input = find.byKey(const Key('handover-contribution'));
      await tester.ensureVisible(input);
      await tester.enterText(input, 'Follow up on the equipment check.');
      tester.testTextInput.hide();
      final send = find.byKey(const Key('handover-add-contribution'));
      await tester.ensureVisible(send);
      await tester.pumpAndSettle();
      await tester.tap(send);
      await drain(
        tester,
        () =>
            r.handover.pendingContributions.length == 1 &&
            tester.widget<FilledButton>(send).onPressed == null,
      );
      expect(r.handover.version, 1);
      expect(r.handover.signedBy, 'coordinator-1');
      expect(find.byKey(const Key('handover-include-updates')), findsNothing);
      expect(find.text('Awaiting coordinator review'), findsOneWidget);
      await finish(tester);
    },
  );

  testWidgets(
    'coordinator includes pending updates through the visible action',
    (tester) async {
      await tester.runAsync(() async {
        await r.contributeSummary('Equipment follow-up is still required.');
        await r.contributeSummary('Leave an additional factual note.');
        await r.switchPersona('coordinator-1');
      });
      await show(tester);
      final include = find.byKey(const Key('handover-include-updates'));
      await tester.ensureVisible(include);
      await tester.pumpAndSettle();
      await tester.tap(include);
      await drain(
        tester,
        () =>
            r.handover.version == 2 &&
            r.handover.pendingContributions.isEmpty &&
            find.text('Send update').evaluate().isEmpty,
      );
      expect(r.handover.signedBy, isNull);
      expect(r.handover.reviewedBy, isNull);
      expect(
        r.handoverText(),
        contains('Equipment follow-up is still required.'),
      );
      expect(r.handover.contributions.last.authorId, 'nurse-1');
      await finish(tester);
    },
  );

  testWidgets(
    'history groups signature and amendment activity into one card per version',
    (tester) async {
      await tester.runAsync(() async {
        await r.switchPersona('coordinator-1');
        await r.amendHandover('Updated incoming-team follow-up.');
        await r.saveHandoverDraft('Human-reviewed handover text.');
        await r.reviewHandover();
        await r.signHandover();
      });
      await show(tester);
      expect(find.byType(HandoverRecordContent), findsOneWidget);
      final history = find.byType(HandoverVersionHistory);
      await tester.ensureVisible(history);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('handover-history-version-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('handover-history-version-2')),
        findsOneWidget,
      );
      expect(find.text('Current · Signed'), findsOneWidget);
      expect(find.text('Previous · Signed'), findsOneWidget);
      expect(find.text('Human-reviewed handover text.'), findsOneWidget);
      final view = find.byKey(const ValueKey('handover-view-version-1'));
      await tester.ensureVisible(view);
      await tester.pumpAndSettle();
      await tester.tap(view);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('handover-contribution')), findsNothing);
      expect(find.byKey(const Key('handover-acknowledge')), findsNothing);
      await finish(tester);
    },
  );

  testWidgets(
    'event cards display the facts and status preserved at signature',
    (tester) async {
      await tester.runAsync(() async {
        await r.claimEvent('event-fall');
        await r.closeEvent('event-fall', 'Resolved after signature.');
      });
      await show(tester);
      final card = find.byKey(const ValueKey('handover-report-event-fall'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Not taken charge')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('High priority')),
        findsOneWidget,
      );
      expect(find.byType(HandoverEventCard), findsWidgets);
      await finish(tester);
    },
  );
}
