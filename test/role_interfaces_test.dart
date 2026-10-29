import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rsa/app/app.dart';
import 'package:rsa/core/database.dart';
import 'package:rsa/core/models.dart';
import 'package:rsa/core/providers.dart';
import 'package:rsa/core/repository.dart';
import 'package:rsa/features/physician.dart';
import 'package:rsa/features/workspace.dart';
import 'package:rsa/shared/ui.dart';

void main() {
  late RsaRepository repository;
  setUp(() async {
    await initializeDateFormatting('en_GB');
    await loadTranslations();
    repository = await RsaRepository.open(
      database: RsaDatabase(NativeDatabase.memory()),
      clock: () => DateTime.utc(2026, 10, 27, 8),
    );
  });
  tearDown(() async => repository.close());

  for (final account in <(String, String, Type)>[
    ('nurse-1', '/home', HomeScreen),
    ('assistant-1', '/home', HomeScreen),
    ('technician-1', '/home', HomeScreen),
    ('physician-1', '/clinical', PhysicianScreen),
    ('coordinator-1', '/coordination', CoordinationScreen),
    ('management-1', '/management', ManagementScreen),
    ('admin-1', '/admin', AdminScreen),
  ]) {
    testWidgets(
      'the ${account.$1} account can open its professional workspace',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() => repository.switchPersona(account.$1));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              rsaRepositoryProvider.overrideWith((ref) => repository),
            ],
            child: RsaApp(initialLocation: account.$2),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(account.$3), findsOneWidget);
        expect(
          find.byKey(const Key('open-report')),
          repository.can(Capability.report) ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(
            repository.currentUser.rolesLabelForWard(repository.activeWard.id),
          ),
          findsWidgets,
        );
        expect(find.text('Demo persona'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(repository.close);
      },
    );
  }

  test(
    'coordinator manages ward operations without assigning professional access',
    () async {
      await repository.switchPersona('coordinator-1');
      await repository.updateStaff(
        'technician-1',
        skills: ['Equipment checks'],
        onDuty: false,
      );
      expect(repository.staffById('technician-1')!.skills, [
        'Equipment checks',
      ]);
      expect(repository.staffById('technician-1')!.onDuty, isFalse);
      await expectLater(
        repository.updateStaff('technician-1', role: Role.administrator),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(
        repository.updateStaff('willow-nurse', onDuty: false),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(
        repository.updateAssignments('coordinator-1', const [
          WardRoleAssignment(wardId: 'willow', role: Role.coordinator),
        ]),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(
        repository.configureRouting(
          highMinutes: 3,
          reminderMinutes: 4,
          escalationMinutes: 8,
        ),
        throwsA(isA<PermissionDenied>()),
      );
    },
  );

  test(
    'ward configuration requires explicitly assigned management scope',
    () async {
      await expectLater(
        repository.renameWard('oak', 'Oak North'),
        throwsA(isA<PermissionDenied>()),
      );
      await repository.switchPersona('admin-1');
      await repository.updateAssignments('management-1', const [
        WardRoleAssignment(wardId: 'oak', role: Role.management),
      ]);
      await repository.switchPersona('management-1');
      await repository.renameWard('oak', 'Oak North');
      expect(repository.activeWard.name, 'Oak North');
      await expectLater(
        repository.renameWard('willow', 'Willow North'),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(repository.renameWard('oak', ' '), throwsStateError);
      expect(() => repository.events, throwsA(isA<PermissionDenied>()));
      expect(() => repository.conversations, throwsA(isA<PermissionDenied>()));
    },
  );

  test(
    'administrator updates validated routing and multiple independent ward roles',
    () async {
      await repository.switchPersona('admin-1');
      final oldHigh = repository.highTimeoutMinutes;
      await expectLater(
        repository.configureRouting(
          highMinutes: 0,
          reminderMinutes: 8,
          escalationMinutes: 4,
        ),
        throwsStateError,
      );
      expect(repository.highTimeoutMinutes, oldHigh);
      await repository.configureRouting(
        highMinutes: 3,
        reminderMinutes: 6,
        escalationMinutes: 12,
      );
      expect(repository.highTimeoutMinutes, 3);
      expect(repository.mediumReminderMinutes, 6);
      expect(repository.mediumEscalationMinutes, 12);
      await repository.updateAssignments('physician-1', const [
        WardRoleAssignment(wardId: 'oak', role: Role.physician),
        WardRoleAssignment(wardId: 'oak', role: Role.coordinator),
        WardRoleAssignment(wardId: 'willow', role: Role.physician),
      ]);
      final person = repository.staffById('physician-1')!;
      expect(person.can(Capability.coordination, 'oak'), isTrue);
      expect(person.can(Capability.clinicalValidation, 'willow'), isTrue);
      expect(person.can(Capability.coordination, 'willow'), isFalse);
      expect(person.rolesLabelForWard('oak'), 'Physician, Coordinator');
      expect(person.rolesLabelForWard('willow'), 'Physician');
      expect(
        person.rolesLabelForWard('unassigned'),
        'No role assigned in this ward',
      );
      expect(() => repository.events, throwsA(isA<PermissionDenied>()));
    },
  );

  testWidgets(
    'coordinator attendance editor dismisses without disposing live fields',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => repository.switchPersona('coordinator-1'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [rsaRepositoryProvider.overrideWith((ref) => repository)],
          child: const MaterialApp(home: Scaffold(body: CoordinationScreen())),
        ),
      );
      await tester.pumpAndSettle();
      final edit = find.byTooltip('Manage attendance and skills').first;
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Safe edited skills');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
        repository.staff.first.skills,
        isNot(contains('Safe edited skills')),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repository.close);
    },
  );

  testWidgets(
    'nurse cannot mount coordinator, management, admin or physician workspaces',
    (tester) async {
      for (final screen in const <Widget>[
        CoordinationScreen(),
        ManagementScreen(),
        AdminScreen(),
        PhysicianScreen(),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              rsaRepositoryProvider.overrideWith((ref) => repository),
            ],
            child: MaterialApp(home: Scaffold(body: screen)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(EmptyState), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repository.close);
    },
  );
}
