import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../shared/ui.dart';

class AccessScreen extends ConsumerStatefulWidget {
  const AccessScreen({super.key});
  @override
  ConsumerState<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends ConsumerState<AccessScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    try {
      await ref
          .read(accessSessionProvider)
          .login(ref.read(rsaRepositoryProvider));
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(accessSessionProvider).isSigningIn;
    return Scaffold(
      key: const Key('access-screen'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 950;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(constraints.maxWidth < 600 ? 20 : 40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1060 : 480),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (wide) const Expanded(child: _AccessBrand()),
                      if (wide) const SizedBox(width: 64),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(
                            constraints.maxWidth < 600 ? 24 : 36,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xffdfe8e3)),
                            boxShadow: [
                              BoxShadow(
                                color: ink.withValues(alpha: .035),
                                blurRadius: 35,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _AccessLogo(),
                              const SizedBox(height: 30),
                              const Text(
                                'Welcome back',
                                style: TextStyle(
                                  fontSize: 29,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Login to keep your team and your shift in view.',
                                style: TextStyle(color: muted, height: 1.6),
                              ),
                              const SizedBox(height: 26),
                              TextField(
                                key: const Key('login-email'),
                                controller: _email,
                                enabled: !busy,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Work email',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                key: const Key('login-password'),
                                controller: _password,
                                enabled: !busy,
                                obscureText: !_showPassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: busy ? null : (_) => _login(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _showPassword
                                        ? 'Hide password'
                                        : 'Show password',
                                    onPressed: busy
                                        ? null
                                        : () => setState(
                                            () =>
                                                _showPassword = !_showPassword,
                                          ),
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  key: const Key('login-submit'),
                                  onPressed: busy ? null : _login,
                                  icon: busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.arrow_forward,
                                          size: 19,
                                        ),
                                  label: const Text('Login'),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    size: 17,
                                    color: muted,
                                  ),
                                  SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      'Your professional role and ward access are assigned by your organisation.',
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AccessLogo extends StatelessWidget {
  const _AccessLogo();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: teal,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 29),
      ),
      const SizedBox(width: 13),
      const Text(
        'RSA',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
        ),
      ),
    ],
  );
}

class _AccessBrand extends StatelessWidget {
  const _AccessBrand();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xffe7f0e9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.spa_outlined, size: 52, color: teal),
        ),
        const SizedBox(height: 30),
        const Text(
          'Your care workspace',
          style: TextStyle(
            fontSize: 40,
            letterSpacing: -1.6,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'The people, information and handovers you need for the next shift.',
          style: TextStyle(color: muted, fontSize: 17, height: 1.7),
        ),
        const SizedBox(height: 36),
        for (final item in const [
          (Icons.groups_outlined, 'Your ward and your team'),
          (Icons.assignment_outlined, 'Reports and shared records'),
          (Icons.swap_horiz_rounded, 'Continuity across shifts'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              children: [
                Icon(item.$1, color: teal, size: 21),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
