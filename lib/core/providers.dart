import 'package:flutter_riverpod/legacy.dart';
import 'repository.dart';

final rsaRepositoryProvider = ChangeNotifierProvider<RsaRepository>((ref) {
  throw StateError(
    'Initialize and override the RSA repository before starting the app.',
  );
});
