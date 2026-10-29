import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsa/core/database.dart';
import 'package:rsa/core/models.dart';
import 'package:rsa/core/repository.dart';

void main() {
  late RsaRepository repository;
  final clock = DateTime.utc(2026, 10, 27, 8);
  final image = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  setUp(() async {
    repository = await RsaRepository.open(
      database: RsaDatabase(NativeDatabase.memory()),
      clock: () => clock,
    );
  });
  tearDown(() => repository.close());

  test(
    'a captured image remains unextracted until a reviewed manual transcription is confirmed',
    () async {
      final media = await repository.saveMedia(
        bytes: image,
        mimeType: 'image/png',
        label: 'Equipment document',
      );
      final item = await repository.createDocumentFromMedia(media.id);

      expect(item.sourceMediaId, media.id);
      expect(item.sourceFingerprint, sha256.convert(image).toString());
      expect(item.createdAt, clock);
      expect(item.hasExtraction, isFalse);
      expect(item.isReviewed, isFalse);
      expect(item.originalText, isEmpty);
      expect(item.versions, isEmpty);

      await repository.confirmOcr(item.id, 'Equipment check at 08:30.');
      expect(item.originalText, isEmpty);
      expect(item.correctedText, 'Equipment check at 08:30.');
      expect(item.isReviewed, isTrue);
      expect(item.reviewedBy, 'nurse-1');
      expect(item.versions.single.text, item.correctedText);
      expect(item.versions.single.createdAt, clock);
      await expectLater(
        repository.confirmOcr(item.id, 'Overwrite'),
        throwsA(isA<StateError>()),
      );
      expect(item.versions, hasLength(1));
      expect(repository.can(Capability.clinicalValidation), isFalse);
    },
  );

  test(
    'corrections append attributable versions and preserve the original extraction',
    () async {
      final item = repository.ocrItems.first;
      final extraction = item.originalText;
      await repository.confirmOcr(item.id, 'First reviewed transcription.');
      await repository.switchPersona('assistant-1');
      await repository.appendOcrCorrection(
        item.id,
        'Corrected reviewed transcription.',
      );

      final updated = repository.ocrItems.firstWhere((o) => o.id == item.id);
      expect(updated.originalText, extraction);
      expect(updated.correctedText, 'Corrected reviewed transcription.');
      expect(updated.versions.map((v) => v.version), [1, 2]);
      expect(updated.versions.map((v) => v.authorId), [
        'nurse-1',
        'assistant-1',
      ]);
      expect(updated.versions.first.text, 'First reviewed transcription.');
      expect(updated.reviewedBy, 'assistant-1');

      final roundTrip = OcrItem.fromJson(updated.toJson());
      expect(roundTrip.originalText, extraction);
      expect(roundTrip.uncertainSegments, ['0[8?]:30']);
      expect(
        roundTrip.versions.map((v) => v.text),
        updated.versions.map((v) => v.text),
      );
    },
  );

  test(
    'ward document images are shared only with authorized clinical ward users',
    () async {
      final media = await repository.saveMedia(
        bytes: image,
        mimeType: 'image/png',
        label: 'Ward document',
      );
      final item = await repository.createDocumentFromMedia(media.id);
      await repository.switchPersona('assistant-1');
      expect(repository.mediaById(media.id)?.id, media.id);
      expect(repository.ocrItems.any((o) => o.id == item.id), isTrue);

      await repository.switchPersona('willow-nurse');
      expect(repository.ocrItems.any((o) => o.id == item.id), isFalse);
      expect(
        () => repository.mediaById(media.id),
        throwsA(isA<PermissionDenied>()),
      );
      await expectLater(
        repository.confirmOcr(item.id, 'Denied'),
        throwsA(isA<PermissionDenied>()),
      );

      for (final account in ['management-1', 'admin-1']) {
        await repository.switchPersona(account);
        expect(() => repository.ocrItems, throwsA(isA<PermissionDenied>()));
        await expectLater(
          repository.confirmOcr(item.id, 'Denied'),
          throwsA(isA<PermissionDenied>()),
        );
      }
    },
  );

  test(
    'empty text, unreviewed corrections and non-image source records are rejected',
    () async {
      final item = repository.ocrItems.first;
      await expectLater(
        repository.confirmOcr(item.id, '  '),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repository.appendOcrCorrection(item.id, 'Premature correction'),
        throwsA(isA<StateError>()),
      );
      final audio = await repository.saveMedia(
        bytes: [1, 2],
        mimeType: 'audio/wav',
        label: 'Audio',
      );
      await expectLater(
        repository.createDocumentFromMedia(audio.id),
        throwsA(isA<PermissionDenied>()),
      );
      expect(repository.ocrItems, hasLength(1));
      expect(repository.ocrItems.first.reviewedAt, isNull);
    },
  );

  test(
    'legacy reviewed documents retain their first review when a correction is appended',
    () async {
      final item = repository.ocrItems.first;
      item.correctedText = 'Legacy reviewed text';
      item.reviewedBy = 'nurse-1';
      item.reviewedAt = clock.subtract(const Duration(days: 1));
      await repository.appendOcrCorrection(item.id, 'New corrected text');
      expect(item.versions, hasLength(2));
      expect(item.versions.first.text, 'Legacy reviewed text');
      expect(
        item.versions.first.createdAt,
        clock.subtract(const Duration(days: 1)),
      );
      expect(item.versions.last.text, 'New corrected text');
    },
  );
}
