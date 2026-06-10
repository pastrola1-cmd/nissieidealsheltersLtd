import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/constants/app_strings.dart';

/// Shell screen for Buyer users.
///
/// Wraps a [StatefulNavigationShell] with a bottom [NavigationBar] containing
/// three tabs: Browse, Inspections, and Profile.
class BuyerShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const BuyerShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.accent.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded, color: AppColors.accent),
            label: AppStrings.browse,
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded, color: AppColors.accent),
            label: AppStrings.inspections,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.accent),
            label: AppStrings.profile,
          ),
        ],
      ),
    );
  }
}
