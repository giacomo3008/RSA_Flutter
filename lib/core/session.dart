import 'package:flutter/foundation.dart';

import 'repository.dart';

/// Frontend navigation session. A backend adapter will supply verified identity.
/// Nothing is persisted: a fresh application load starts at the access page.
class AccessSession extends ChangeNotifier {
  bool _signedIn;
  bool _signingIn = false;
  int _revision = 0;
  int _attempt = 0;
  AccessSession({bool signedIn = false}) : _signedIn = signedIn;

  bool get isSignedIn => _signedIn;
  bool get isSigningIn => _signingIn;
  int get revision => _revision;

  Future<void> login(RsaRepository repository) async {
    if (_signingIn || _signedIn) return;
    final attempt = ++_attempt;
    _signingIn = true;
    notifyListeners();
    try {
      // Temporary frontend entry requested for reviewing the application.
      // These local fixture operations do not authenticate a real account.
      await repository.switchPersona('nurse-1');
      await repository.selectWard('oak');
      if (attempt == _attempt) {
        _signedIn = true;
        _revision++;
      }
    } finally {
      if (attempt == _attempt) {
        _signingIn = false;
        notifyListeners();
      }
    }
  }

  void logout() {
    _attempt++;
    _signedIn = false;
    _signingIn = false;
    _revision++;
    notifyListeners();
  }
}
