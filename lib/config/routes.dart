import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/screens/shells/admin_shell.dart';
import 'package:ppn/screens/shells/partner_shell.dart';
import 'package:ppn/screens/shells/buyer_shell.dart';
import 'package:ppn/screens/auth/login_screen.dart';
import 'package:ppn/screens/auth/signup_screen.dart';
import 'package:ppn/screens/auth/awaiting_approval_screen.dart';
import 'package:ppn/screens/auth/profile_completion_screen.dart';
import 'package:ppn/screens/placeholders/placeholder_screen.dart';

/// Navigation key for the root navigator (used by full-screen routes like auth).
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Navigation keys for each role-based shell's nested navigator.
final _adminShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'admin');
final _partnerShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'partner');
final _buyerShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'buyer');

/// Helper class to bridge Stream changes to GoRouter's refreshListenable.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Helper function to route authenticated users to their default dashboard.
String _getDefaultRouteForRole(UserRole role) {
  switch (role) {
    case UserRole.admin:
    case UserRole.platformAdmin:
      return '/admin/dashboard';
    case UserRole.partner:
      return '/partner/dashboard';
    case UserRole.buyer:
      return '/buyer/browse';
  }
}

/// Provides the application's [GoRouter] instance via Riverpod.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authProvider.notifier).stream,
    ),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      // ── Redirect to login if not authenticated ──
      if (!authState.isAuthenticated) {
        return loggingIn ? null : '/login';
      }

      final profile = authState.profile;
      if (profile == null) {
        return null;
      }

      // ── Redirect to profile completion if details are missing ──
      final needName = profile.fullName == null || profile.fullName!.isEmpty;
      final needPhone = profile.phone == null || profile.phone!.isEmpty;
      if (needName || needPhone) {
        if (state.matchedLocation != '/profile-completion') {
          return '/profile-completion';
        }
        return null;
      }

      // If they are fully completed but on profile completion page, send them to dashboard
      if (state.matchedLocation == '/profile-completion') {
        return _getDefaultRouteForRole(profile.role);
      }

      // ── Redirect pending partners to awaiting approval screen ──
      if (profile.role == UserRole.partner &&
          profile.status == PartnerStatus.pending) {
        if (state.matchedLocation != '/partner/awaiting-approval') {
          return '/partner/awaiting-approval';
        }
        return null;
      }

      // ── Redirect approved partners away from awaiting approval ──
      if (profile.role == UserRole.partner &&
          profile.status == PartnerStatus.approved &&
          state.matchedLocation == '/partner/awaiting-approval') {
        return '/partner/dashboard';
      }

      // ── If already logged in, prevent going to auth screens ──
      if (loggingIn) {
        return _getDefaultRouteForRole(profile.role);
      }

      // ── Guard role-based paths ──
      final location = state.matchedLocation;
      if (location.startsWith('/admin') &&
          profile.role != UserRole.admin &&
          profile.role != UserRole.platformAdmin) {
        return _getDefaultRouteForRole(profile.role);
      }
      if (location.startsWith('/partner') && profile.role != UserRole.partner) {
        return _getDefaultRouteForRole(profile.role);
      }
      if (location.startsWith('/buyer') && profile.role != UserRole.buyer) {
        return _getDefaultRouteForRole(profile.role);
      }

      return null;
    },
    routes: [
      // ── Auth routes (no shell) ──────────────────────────────────────────
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/partner/awaiting-approval',
        name: 'awaitingApproval',
        builder: (context, state) => const AwaitingApprovalScreen(),
      ),
      GoRoute(
        path: '/profile-completion',
        name: 'profileCompletion',
        builder: (context, state) => const ProfileCompletionScreen(),
      ),

      // ── Admin shell ─────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _adminShellNavigatorKey,
            routes: [
              GoRoute(
                path: '/admin/dashboard',
                name: 'adminDashboard',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Admin Dashboard'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/properties',
                name: 'adminProperties',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Admin Properties'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/partners',
                name: 'adminPartners',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Admin Partners'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/leads',
                name: 'adminLeads',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Admin Leads'),
              ),
            ],
          ),
        ],
      ),

      // ── Partner shell ───────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            PartnerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _partnerShellNavigatorKey,
            routes: [
              GoRoute(
                path: '/partner/dashboard',
                name: 'partnerDashboard',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Partner Dashboard'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partner/properties',
                name: 'partnerProperties',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Partner Properties'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partner/leads',
                name: 'partnerLeads',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Partner Leads'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partner/earnings',
                name: 'partnerEarnings',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Partner Earnings'),
              ),
            ],
          ),
        ],
      ),

      // ── Buyer shell ─────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            BuyerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _buyerShellNavigatorKey,
            routes: [
              GoRoute(
                path: '/buyer/browse',
                name: 'buyerBrowse',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Browse Properties'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/buyer/inspections',
                name: 'buyerInspections',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'My Inspections'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/buyer/profile',
                name: 'buyerProfile',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'My Profile'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
