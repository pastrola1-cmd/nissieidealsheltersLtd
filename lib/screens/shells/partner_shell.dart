import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/constants/app_strings.dart';

/// Shell screen for Partner users.
///
/// Wraps a [StatefulNavigationShell] with a bottom [NavigationBar] containing
/// four tabs: Dashboard, Properties, Leads, and Earnings.
class PartnerShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const PartnerShell({super.key, required this.navigationShell});

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
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.accent),
            label: AppStrings.dashboard,
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment_rounded, color: AppColors.accent),
            label: AppStrings.properties,
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up_rounded, color: AppColors.accent),
            label: AppStrings.leads,
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: AppColors.accent),
            label: AppStrings.earnings,
          ),
        ],
      ),
    );
  }
}
