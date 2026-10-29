import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/models.dart';
import '../shared/ui.dart';

/// Current account context without a privilege-switching control.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(rsaRepositoryProvider);
    final user = repository.currentUser;
    final wards = repository.wards;
    return ListView(
      children: [
        PageHeading(
          title: tr(context, 'accountSettings'),
          subtitle: tr(context, 'accountSubtitle'),
        ),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(user.initials, size: 48),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined, color: teal),
                title: Text(tr(context, 'professionalRole')),
                subtitle: Text(
                  user.rolesLabelForWard(repository.activeWard.id),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.apartment_outlined, color: teal),
                title: Text(tr(context, 'assignedWards')),
                subtitle: Text(wards.map((ward) => ward.name).join(', ')),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined, color: teal),
                title: Text(tr(context, 'accountTimeZone')),
                subtitle: const Text('Europe/Rome'),
              ),
              if (wards.length > 1) ...[
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  key: ValueKey(repository.activeWard.id),
                  initialValue: repository.activeWard.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: tr(context, 'currentWard'),
                  ),
                  items: [
                    for (final ward in wards)
                      DropdownMenuItem(value: ward.id, child: Text(ward.name)),
                  ],
                  onChanged: (id) {
                    if (id != null) {
                      runAction(context, () => repository.selectWard(id));
                    }
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your workspace access',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 12),
              for (final assignment in user.assignments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.verified_user_outlined,
                    color: teal,
                  ),
                  title: Text(assignment.role.label),
                  subtitle: Text(
                    wards
                            .where((ward) => ward.id == assignment.wardId)
                            .firstOrNull
                            ?.name ??
                        assignment.wardId,
                  ),
                ),
              const Divider(),
              const Text(
                'Professional roles and ward access are assigned to your corporate account. Changing the current ward uses your existing assignments; it does not grant additional permissions.',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Account session',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 10),
              const Text(
                'Log out to return to the login page.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                key: const Key('account-log-out'),
                icon: const Icon(Icons.logout_outlined),
                label: const Text('Log out'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      key: const Key('logout-confirmation'),
                      title: const Text('Log out?'),
                      content: const Text(
                        'You will return to the login page. You can log in again to open your workspace.',
                      ),
                      actions: [
                        TextButton(
                          key: const Key('logout-cancel'),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Stay signed in'),
                        ),
                        FilledButton(
                          key: const Key('logout-confirm'),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Log out'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    ref.read(accessSessionProvider).logout();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
