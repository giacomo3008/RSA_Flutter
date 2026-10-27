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
                subtitle: Text(user.role.label),
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
      ],
    );
  }
}
