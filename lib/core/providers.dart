import 'package:flutter_riverpod/legacy.dart';
import 'repository.dart';
import 'session.dart';

final accessSessionProvider = ChangeNotifierProvider<AccessSession>(
  (ref) => AccessSession(),
);

final rsaRepositoryProvider = ChangeNotifierProvider<RsaRepository>((ref) {
  throw StateError(
    'Initialize and override the RSA repository before starting the app.',
  );
});
