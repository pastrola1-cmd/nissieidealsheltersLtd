import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ppn/screens/shells/admin_shell.dart';
import 'package:ppn/screens/shells/partner_shell.dart';
import 'package:ppn/screens/shells/buyer_shell.dart';
import 'package:ppn/screens/auth/login_screen.dart';
import 'package:ppn/screens/auth/signup_screen.dart';
import 'package:ppn/screens/placeholders/placeholder_screen.dart';

/// Navigation key for the root navigator (used by full-screen routes like auth).
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Navigation keys for each role-based shell's nested navigator.
final _adminShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'admin');
final _partnerShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'partner');
final _buyerShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'buyer');

/// Provides the application's [GoRouter] instance via Riverpod.
///
/// Route structure:
/// - `/login` and `/signup` — authentication screens (no shell)
/// - `/admin/*` — admin role shell with bottom navigation
/// - `/partner/*` — partner role shell with bottom navigation
/// - `/buyer/*` — buyer role shell with bottom navigation
///
/// Redirect logic is intentionally omitted; the initial location is `/login`.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
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
