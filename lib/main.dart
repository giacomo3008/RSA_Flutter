import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/theme.dart';
import 'core/providers.dart';
import 'core/repository.dart';
import 'shared/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadTranslations();
  try {
    final repository = await RsaRepository.open();
    runApp(
      ProviderScope(
        overrides: [rsaRepositoryProvider.overrideWith((ref) => repository)],
        child: const RsaApp(),
      ),
    );
  } catch (error) {
    runApp(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EmptyState(
                        icon: Icons.storage_outlined,
                        title: tr(context, 'storageErrorTitle'),
                        message: tr(context, 'storageErrorMessage'),
                      ),
                      SelectableText(
                        error.toString(),
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: main,
                        child: Text(tr(context, 'retry')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
