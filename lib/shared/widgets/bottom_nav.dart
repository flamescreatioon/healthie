/// The persistent bottom navigation with a raised quick-log action.
///
/// Material's `NavigationBar` cannot host a raised centre action, so the bar
/// is composed by hand: five destinations and one action, in six equal slots.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_typography.dart';

/// One destination in the bottom bar.
class NavDestination {
  const NavDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  /// The route this destination opens.
  final String path;

  /// The label under the icon.
  final String label;

  /// The icon when the destination is not selected.
  final IconData icon;

  /// The icon when the destination is selected.
  final IconData selectedIcon;
}

/// The app's destinations, in bar order.
const List<NavDestination> kNavDestinations = [
  NavDestination(
    path: '/home',
    label: 'Home',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
  ),
  NavDestination(
    path: '/track',
    label: 'Track',
    icon: Icons.monitor_heart_outlined,
    selectedIcon: Icons.monitor_heart_rounded,
  ),
  NavDestination(
    path: '/analytics',
    label: 'Analytics',
    icon: Icons.insert_chart_outlined,
    selectedIcon: Icons.insert_chart_rounded,
  ),
  NavDestination(
    path: '/history',
    label: 'History',
    icon: Icons.history_outlined,
    selectedIcon: Icons.history_rounded,
  ),
  NavDestination(
    path: '/profile',
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

/// The bottom navigation bar.
class HealthieBottomNav extends StatelessWidget {
  const HealthieBottomNav({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onQuickLog,
    super.key,
  });

  /// The index of the selected destination.
  final int currentIndex;

  /// Called with the index of the newly selected destination.
  final ValueChanged<int> onDestinationSelected;

  /// Called when the raised quick-log action is pressed.
  final VoidCallback onQuickLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavSlot(
                icon: kNavDestinations[0].icon,
                selectedIcon: kNavDestinations[0].selectedIcon,
                label: kNavDestinations[0].label,
                selected: currentIndex == 0,
                onTap: () => onDestinationSelected(0),
              ),
              _NavSlot(
                icon: kNavDestinations[1].icon,
                selectedIcon: kNavDestinations[1].selectedIcon,
                label: kNavDestinations[1].label,
                selected: currentIndex == 1,
                onTap: () => onDestinationSelected(1),
              ),
              Expanded(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -12),
                    child: Semantics(
                      button: true,
                      label: 'Quick log a measurement',
                      child: Material(
                        color: theme.colorScheme.primary,
                        shape: const CircleBorder(),
                        elevation: 6,
                        shadowColor:
                            theme.colorScheme.primary.withValues(alpha: 0.4),
                        child: InkWell(
                          onTap: onQuickLog,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 54,
                            height: 54,
                            child: Icon(
                              Icons.add_rounded,
                              size: 28,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _NavSlot(
                icon: kNavDestinations[2].icon,
                selectedIcon: kNavDestinations[2].selectedIcon,
                label: kNavDestinations[2].label,
                selected: currentIndex == 2,
                onTap: () => onDestinationSelected(2),
              ),
              _NavSlot(
                icon: kNavDestinations[3].icon,
                selectedIcon: kNavDestinations[3].selectedIcon,
                label: kNavDestinations[3].label,
                selected: currentIndex == 3,
                onTap: () => onDestinationSelected(3),
              ),
              _NavSlot(
                icon: kNavDestinations[4].icon,
                selectedIcon: kNavDestinations[4].selectedIcon,
                label: kNavDestinations[4].label,
                selected: currentIndex == 4,
                onTap: () => onDestinationSelected(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, size: 24, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.labelMicro.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navigates to a top-level destination, keeping the shell's back stack sane.
void goToTab(BuildContext context, int index) {
  if (index < 0 || index >= kNavDestinations.length) return;
  final destination = kNavDestinations[index];
  GoRouter.of(context).go(destination.path);
}
