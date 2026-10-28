import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsa/core/database.dart';
import 'package:rsa/core/models.dart';
import 'package:rsa/core/repository.dart';

void main() {
  test(
    'retained actor references survive a move without exposing their profile',
    () async {
      final repository = await RsaRepository.open(
        database: RsaDatabase(NativeDatabase.memory()),
        clock: () => DateTime.utc(2026, 10, 27, 8),
      );
      addTearDown(repository.close);
      await repository.switchPersona('coordinator-1');
      await repository.confirmOcr('ocr-oak', 'Equipment inspection at 08:30.');
      await repository.switchPersona('admin-1');
      await repository.updateAssignments('coordinator-1', const [
        WardRoleAssignment(wardId: 'willow', role: Role.coordinator),
      ]);
      await repository.updateAssignments('assistant-1', const [
        WardRoleAssignment(wardId: 'willow', role: Role.assistant),
      ]);
      await repository.switchPersona('nurse-1');

      expect(
        () => repository.staffById('coordinator-1'),
        throwsA(isA<PermissionDenied>()),
      );
      expect(repository.staffForDisplay('coordinator-1'), isNull);
      expect(repository.staffForDisplay('assistant-1'), isNull);
      expect(repository.staffForDisplay('willow-nurse'), isNull);
      expect(repository.handover.signedBy, 'coordinator-1');
      expect(repository.eventById('event-fall')!.authorId, 'assistant-1');
      expect(repository.ocrItems.first.reviewedBy, 'coordinator-1');
      expect(
        repository.ocrItems.first.versions.single.authorId,
        'coordinator-1',
      );
      expect(
        repository
            .messagesFor('team-oak')
            .any((m) => m.authorId == 'coordinator-1'),
        isTrue,
      );
      expect(repository.staffForDisplay('nurse-1')!.name, 'Emily Carter');
    },
  );
}
