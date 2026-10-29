import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../shared/ui.dart';

const _sage = Color(0xff5e8876);
const _cardBackground = Color(0xffedf4f0);
const _cardBorder = Color(0xffdce9e2);

/// The current ward and shift, with attendance and routing availability controls.
class ShiftAttendanceCard extends ConsumerStatefulWidget {
  const ShiftAttendanceCard({super.key});

  @override
  ConsumerState<ShiftAttendanceCard> createState() =>
      _ShiftAttendanceCardState();
}

class _ShiftAttendanceCardState extends ConsumerState<ShiftAttendanceCard> {
  bool _pending = false;

  Future<void> _perform(Future<void> Function() operation) async {
    if (_pending) return;
    setState(() => _pending = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(rsaRepositoryProvider);
    final staff = repository.currentUser;
    final shift = repository.currentShift;
    return Material(
      key: const Key('shift-attendance-card'),
      color: _cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final wide = constraints.maxWidth >= 800 * textScale;
            final identity = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xfffafffc),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.monitor_heart_outlined,
                    size: 28,
                    color: _sage,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Wrap(
                    spacing: 28,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            repository.activeWard.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff3f6156),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr(context, 'shiftCardSchedule', {
                              'shift': shift.label,
                              'start': formatTime(shift.startsAt),
                              'end': formatTime(shift.endsAt),
                            }),
                            style: const TextStyle(color: _sage, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xfffafffc),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: _cardBorder),
                        ),
                        child: Text(
                          staff.rolesLabelForWard(repository.activeWard.id),
                          style: const TextStyle(color: _sage, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final controls = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: staff.onDuty ? const Color(0xff4b9b7a) : muted,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        tr(context, staff.onDuty ? 'checkedIn' : 'checkedOut'),
                        style: TextStyle(
                          color: staff.onDuty ? _sage : muted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('shift-toggle-attendance'),
                      onPressed: _pending
                          ? null
                          : () => _perform(repository.toggleAttendance),
                      style: TextButton.styleFrom(
                        foregroundColor: _sage,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: _pending
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              staff.onDuty ? Icons.logout : Icons.login,
                              size: 18,
                            ),
                      label: Text(
                        tr(context, staff.onDuty ? 'checkOut' : 'checkIn'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _AvailabilityControl(
                  selected: staff.availability,
                  enabled: staff.onDuty && !_pending,
                  onChanged: (availability) =>
                      _perform(() => repository.setAvailability(availability)),
                ),
              ],
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 28),
                  SizedBox(width: 370 * textScale, child: controls),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 20),
                const Divider(color: _cardBorder),
                const SizedBox(height: 8),
                controls,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AvailabilityControl extends StatelessWidget {
  final Availability selected;
  final bool enabled;
  final ValueChanged<Availability> onChanged;
  const _AvailabilityControl({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  Color _color(Availability value) => switch (value) {
    Availability.available => const Color(0xff52957c),
    Availability.busy => const Color(0xffc19a49),
    Availability.onBreak => const Color(0xff8d8b9e),
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xffe7f0ea),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: _cardBorder, width: 1.5),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = (constraints.maxWidth / (112 * scale)).floor().clamp(
          1,
          3,
        );
        final width = (constraints.maxWidth - (columns - 1) * 4) / columns;
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final availability in Availability.values)
              SizedBox(
                width: width,
                child: Semantics(
                  selected: selected == availability,
                  enabled: enabled,
                  button: true,
                  child: Material(
                    color: selected == availability
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    elevation: selected == availability ? 1 : 0,
                    shadowColor: _cardBorder.withValues(alpha: .35),
                    child: InkWell(
                      key: Key('availability-${availability.name}'),
                      onTap: enabled ? () => onChanged(availability) : null,
                      borderRadius: BorderRadius.circular(6),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: enabled ? _color(availability) : muted,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  tr(
                                    context,
                                    'availability${availability.name}',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: enabled ? _sage : muted,
                                    fontWeight: selected == availability
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
