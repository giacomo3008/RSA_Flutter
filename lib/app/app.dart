import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/repository.dart';
import '../features/chat.dart';
import '../features/account.dart';
import '../features/events.dart';
import '../features/workspace.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/ui.dart';
import 'theme.dart';
import 'environment.dart';

/// A new navigation scope prevents retained tabs from exposing a previous persona.
class RsaApp extends ConsumerStatefulWidget {
  final String? initialLocation;
  const RsaApp({super.key, this.initialLocation});
  @override
  ConsumerState<RsaApp> createState() => _RsaRootState();
}

class _RsaRootState extends ConsumerState<RsaApp> {
  String? previousIdentity;
  bool initial = true;
  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(
      rsaRepositoryProvider.select(
        (r) => '${r.currentUser.id}:${r.activeWard.id}',
      ),
    );
    final changed = previousIdentity != null && previousIdentity != identity;
    if (changed) initial = false;
    previousIdentity = identity;
    return RsaSessionApp(
      key: ValueKey(identity),
      initialLocation: initial ? widget.initialLocation : '/',
    );
  }
}

class RsaSessionApp extends ConsumerStatefulWidget {
  final String? initialLocation;
  const RsaSessionApp({super.key, this.initialLocation});
  @override
  ConsumerState<RsaSessionApp> createState() => _RsaAppState();
}

class _RsaAppState extends ConsumerState<RsaSessionApp>
    with WidgetsBindingObserver {
  late final GoRouter router;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final r = ref.read(rsaRepositoryProvider);
    router = GoRouter(
      initialLocation: widget.initialLocation,
      refreshListenable: r,
      redirect: (context, state) {
        final path = state.uri.path;
        final care = r.can(Capability.care);
        final landing = care
            ? '/home'
            : r.can(Capability.management)
            ? '/management'
            : '/admin';
        if (path == '/') return landing;
        if (path == '/settings') return null;
        if (path == '/development') {
          return developmentToolsEnabled ? null : landing;
        }
        if (!care && !['/management', '/admin'].contains(path)) return landing;
        if (path == '/management' && !r.can(Capability.management)) {
          return landing;
        }
        if (path == '/admin' && !r.can(Capability.administration)) {
          return landing;
        }
        if (path == '/coordination' && !r.can(Capability.coordination)) {
          return landing;
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', redirect: (context, state) => '/home'),
        // Retired workspace: old bookmarks return to the role's landing page.
        GoRoute(path: '/ocr', redirect: (context, state) => '/'),
        GoRoute(
          path: '/report',
          builder: (context, state) => ReportScreen(
            sourceMessageId: state.uri.queryParameters['source'],
            initialDraft: state.extra is EventDraft
                ? state.extra as EventDraft
                : null,
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              WorkspaceShell(shell: shell, path: state.uri.path),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chat',
                  builder: (context, state) => const ChatScreen(),
                  routes: [
                    GoRoute(
                      path: ':conversationId',
                      builder: (context, state) => ChatScreen(
                        conversationId: state.pathParameters['conversationId'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/inbox',
                  builder: (context, state) => const InboxScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/more',
                  builder: (context, state) => const MoreScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/diary',
                  builder: (context, state) => const DiaryScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/handover',
                  builder: (context, state) => const HandoverScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/shift',
                  builder: (context, state) => const ShiftScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/coordination',
                  builder: (context, state) => const CoordinationScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/management',
                  builder: (context, state) => const ManagementScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin',
                  builder: (context, state) => const AdminScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) => const AccountScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/development',
                  builder: (context, state) => developmentToolsEnabled
                      ? const SettingsScreen()
                      : const AccountScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              initialLocation: '/event/event-fall',
              routes: [
                GoRoute(
                  path: '/event/:id',
                  builder: (context, state) =>
                      EventDetailScreen(eventId: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: EmptyState(
            icon: Icons.lock_outline,
            title: tr(context, 'accessDenied'),
            message: tr(context, 'accessDeniedMessage'),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      runAction(
        context,
        () => ref.read(rsaRepositoryProvider).advanceTime(Duration.zero),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'RSA',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    routerConfig: router,
  );
}

class WorkspaceShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  final String path;
  const WorkspaceShell({super.key, required this.shell, required this.path});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(rsaRepositoryProvider);
    final care = r.can(Capability.care);
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 1000;
        final compact = c.maxWidth < 700;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (wide) _Sidebar(path: path, repo: r),
                Expanded(
                  child: Column(
                    children: [
                      _Header(repo: r, path: path, compact: compact),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 18 : 32,
                            compact ? 24 : 32,
                            compact ? 18 : 32,
                            0,
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1440),
                              child: shell,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide || !care
              ? null
              : _CompactNavigation(
                  path: path,
                  hasUnread: r.conversations.any(
                    (c) => r.unreadCount(c.id) > 0,
                  ),
                ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String path;
  final RsaRepository repo;
  const _Sidebar({required this.path, required this.repo});
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('expanded-navigation'),
    width: 234,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: Color(0xffe2e9e5))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 30, 24, 38),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              const Text(
                'RSA',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 26, bottom: 16),
          child: Text(
            tr(context, 'workspace'),
            style: const TextStyle(
              color: muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              if (repo.can(Capability.care)) ...[
                _nav(context, Icons.grid_view_outlined, 'overview', '/home'),
                _nav(
                  context,
                  Icons.chat_bubble_outline,
                  'chat',
                  '/chat',
                  badge:
                      '${repo.conversations.fold<int>(0, (sum, c) => sum + repo.unreadCount(c.id))}',
                ),
                _nav(
                  context,
                  Icons.inbox_outlined,
                  'inbox',
                  '/inbox',
                  badge:
                      '${repo.notifications.where((n) => n.takenChargeAt == null && n.closedAt == null).length}',
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 18),
                _nav(context, Icons.menu_book_outlined, 'wardDiary', '/diary'),
                _nav(
                  context,
                  Icons.swap_horiz_rounded,
                  'shiftHandover',
                  '/handover',
                ),
                _nav(context, Icons.badge_outlined, 'myShift', '/shift'),
              ],
              if (repo.can(Capability.coordination))
                _nav(
                  context,
                  Icons.people_outline,
                  'coordination',
                  '/coordination',
                ),
              if (repo.can(Capability.management))
                _nav(
                  context,
                  Icons.bar_chart_outlined,
                  'management',
                  '/management',
                ),
              if (repo.can(Capability.administration))
                _nav(
                  context,
                  Icons.settings_outlined,
                  'administration',
                  '/admin',
                ),
            ],
          ),
        ),
        if (repo.can(Capability.report))
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('open-report'),
                onPressed: () => context.push('/report'),
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'reportEvent')),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: canvas,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'currentWard'),
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.apartment_outlined, size: 17, color: teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        repo.activeWard.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (developmentToolsEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
            child: TextButton.icon(
              onPressed: () => context.go('/development'),
              icon: const Icon(Icons.code, size: 16, color: muted),
              label: Text(
                tr(context, 'developmentTools'),
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ),
          ),
      ],
    ),
  );
  Widget _nav(
    BuildContext context,
    IconData icon,
    String key,
    String route, {
    String? badge,
  }) {
    final active = path == route || path.startsWith('$route/');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: active ? const Color(0xffe8f2ed) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
            child: Row(
              children: [
                Icon(icon, size: 20, color: active ? teal : muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(context, key),
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? teal : muted,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null && badge != '0')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: active ? Colors.white : canvas,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 10,
                        color: teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final RsaRepository repo;
  final String path;
  final bool compact;
  const _Header({
    required this.repo,
    required this.path,
    required this.compact,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 32, vertical: 16),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xffe2e9e5))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: compact ? 10 : 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (compact) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: teal,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
                const Text(
                  'RSA',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ] else ...[
                Text(
                  tr(context, 'currentWorkspace'),
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                Text(
                  repo.activeWard.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!compact) ...[
          Text(
            formatDate(repo.now),
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: tr(context, 'accountSettings'),
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.tune, size: 20, color: muted),
          ),
        ],
        const SizedBox(width: 8),
        Semantics(
          label: tr(context, 'accountSettings'),
          button: true,
          child: InkWell(
            onTap: () => context.go('/settings'),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Avatar(repo.currentUser.initials, size: 36),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          repo.currentUser.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          repo.currentUser.role.label,
                          style: const TextStyle(fontSize: 9, color: muted),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CompactNavigation extends StatelessWidget {
  final String path;
  final bool hasUnread;
  const _CompactNavigation({required this.path, required this.hasUnread});
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      key: const Key('compact-navigation'),
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 5),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xffe2e9e5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _item(context, Icons.grid_view_outlined, 'home', '/home'),
          _item(
            context,
            Icons.chat_bubble_outline,
            'chat',
            '/chat',
            badge: hasUnread,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 64,
                  height: 58,
                  child: Tooltip(
                    message: tr(context, 'reportEvent'),
                    child: FilledButton(
                      key: const Key('open-report'),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => context.push('/report'),
                      child: const Icon(Icons.add, size: 29),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tr(context, 'reportEvent'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: teal,
                  ),
                ),
              ],
            ),
          ),
          _item(context, Icons.inbox_outlined, 'inbox', '/inbox'),
          _item(context, Icons.more_horiz, 'more', '/more'),
        ],
      ),
    ),
  );
  Widget _item(
    BuildContext context,
    IconData icon,
    String key,
    String route, {
    bool badge = false,
  }) => Expanded(
    child: InkWell(
      onTap: () => context.go(route),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge)
              Badge(
                smallSize: 6,
                child: Icon(
                  icon,
                  color: path.startsWith(route) ? teal : muted,
                  size: 23,
                ),
              )
            else
              Icon(
                icon,
                color: path.startsWith(route) ? teal : muted,
                size: 23,
              ),
            const SizedBox(height: 8),
            Text(
              tr(context, key),
              style: TextStyle(
                fontSize: 10,
                color: path.startsWith(route) ? teal : muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
