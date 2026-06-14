import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/screens/shells/admin_shell.dart';
import 'package:ppn/screens/shells/manager_shell.dart';
import 'package:ppn/screens/shells/marketer_shell.dart';
import 'package:ppn/screens/shells/partner_shell.dart';
import 'package:ppn/screens/shells/buyer_shell.dart';
import 'package:ppn/screens/manager/manager_dashboard_screen.dart';
import 'package:ppn/screens/manager/manager_team_screen.dart';
import 'package:ppn/screens/manager/manager_leads_screen.dart';
import 'package:ppn/screens/shared/daily_reports_screen.dart';
import 'package:ppn/screens/marketer/marketer_dashboard_screen.dart';
import 'package:ppn/screens/marketer/marketer_leads_screen.dart';
import 'package:ppn/screens/marketer/marketer_followups_screen.dart';
import 'package:ppn/screens/auth/login_screen.dart';
import 'package:ppn/screens/auth/signup_screen.dart';
import 'package:ppn/screens/auth/awaiting_approval_screen.dart';
import 'package:ppn/screens/auth/profile_completion_screen.dart';
import 'package:ppn/screens/auth/onboarding_screen.dart';
import 'package:ppn/screens/admin/company_profile_screen.dart';
import 'package:ppn/screens/admin/admin_settings_screen.dart';
import 'package:ppn/screens/admin/billing_screen.dart';
import 'package:ppn/screens/platform/platform_dashboard_screen.dart';
import 'package:ppn/screens/auth/suspended_screen.dart';
import 'package:ppn/screens/admin/admin_dashboard_screen.dart';
import 'package:ppn/screens/admin/admin_properties_screen.dart';
import 'package:ppn/screens/admin/property_form_screen.dart';
import 'package:ppn/screens/shared/property_detail_screen.dart';
import 'package:ppn/screens/shared/notifications_screen.dart';
import 'package:ppn/screens/placeholders/placeholder_screen.dart';
import 'package:ppn/screens/admin/partner_list_screen.dart';
import 'package:ppn/screens/admin/partner_detail_screen.dart';
import 'package:ppn/screens/partner/partner_profile_screen.dart';
import 'package:ppn/screens/admin/lead_list_screen.dart';
import 'package:ppn/screens/admin/lead_detail_screen.dart';
import 'package:ppn/screens/admin/manual_lead_screen.dart';
import 'package:ppn/screens/admin/lead_import_screen.dart';
import 'package:ppn/screens/admin/lead_export_screen.dart';
import 'package:ppn/screens/partner/partner_lead_screen.dart';
import 'package:ppn/screens/buyer/buyer_inspections_screen.dart';
import 'package:ppn/screens/buyer/book_inspection_screen.dart';
import 'package:ppn/screens/buyer/inspection_confirmation_screen.dart';
import 'package:ppn/screens/admin/admin_inspections_screen.dart';
import 'package:ppn/screens/partner/partner_inspections_screen.dart';
import 'package:ppn/screens/partner/earnings_screen.dart';
import 'package:ppn/screens/admin/admin_commissions_screen.dart';
import 'package:ppn/screens/admin/admin_withdrawals_screen.dart';
import 'package:ppn/screens/admin/staff_invite_screen.dart';
import 'package:ppn/screens/partner/partner_dashboard_screen.dart';
import 'package:ppn/screens/buyer/buyer_home_screen.dart';
import 'package:ppn/screens/campaign/campaign_generator_screen.dart';
import 'package:ppn/screens/campaign/campaign_history_screen.dart';
import 'package:ppn/screens/admin/goal_setting_screen.dart';
import 'package:ppn/screens/admin/goal_detail_screen.dart';
import 'package:ppn/screens/admin/analytics_dashboard_screen.dart';
import 'package:ppn/screens/admin/block_performance_screen.dart';
import 'package:ppn/screens/admin/document_generator_screen.dart';
import 'package:ppn/screens/admin/document_preview_screen.dart';
import 'package:ppn/screens/admin/document_list_screen.dart';



/// Navigation key for the root navigator (used by full-screen routes like auth).
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Navigation keys for each role-based shell's nested navigator.
final _adminShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'admin');
final _managerShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'manager');
final _marketerShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'marketer');
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
      return '/admin/dashboard';
    case UserRole.manager:
      return '/manager/dashboard';
    case UserRole.marketer:
      return '/marketer/dashboard';
    case UserRole.platformAdmin:
      return '/platform/dashboard';
    case UserRole.partner:
      return '/partner/dashboard';
    case UserRole.buyer:
      return '/buyer/browse';
  }
}

/// Provider to store onboarding completion status
final onboardingCompletedProvider = Provider<bool>((ref) => false);

/// Provides the application's [GoRouter] instance via Riverpod.
final routerProvider = Provider<GoRouter>((ref) {
  final onboardingCompleted = ref.watch(onboardingCompletedProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: onboardingCompleted ? '/login' : '/onboarding',
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authProvider.notifier).stream,
    ),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/onboarding';

      // ── Redirect to login if not authenticated ──
      if (!authState.isAuthenticated) {
        final isPropertyDetail = state.matchedLocation.startsWith('/properties/');
        return (loggingIn || isPropertyDetail) ? null : '/login';
      }

      final profile = authState.profile;
      if (profile == null) {
        return null;
      }

      // ── Redirect suspended accounts ──
      if (profile.status == PartnerStatus.suspended) {
        if (state.matchedLocation != '/suspended') {
          return '/suspended';
        }
        return null;
      }

      if (state.matchedLocation == '/suspended') {
        return _getDefaultRouteForRole(profile.role);
      }

      // ── Redirect pending approvals ──
      if (profile.status == PartnerStatus.pending) {
        if (state.matchedLocation != '/partner/awaiting-approval') {
          return '/partner/awaiting-approval';
        }
        return null;
      }

      if (state.matchedLocation == '/partner/awaiting-approval') {
        return _getDefaultRouteForRole(profile.role);
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

       // ── If already logged in, prevent going to auth screens ──
      if (loggingIn) {
        return _getDefaultRouteForRole(profile.role);
      }

      // ── Guard role-based paths ──
      final location = state.matchedLocation;
      if (location.startsWith('/platform') && profile.role != UserRole.platformAdmin) {
        return _getDefaultRouteForRole(profile.role);
      }
      if (location.startsWith('/admin')) {
        final isAdminOrPlatform = profile.role == UserRole.admin || profile.role == UserRole.platformAdmin;
        final isManagerBilling = profile.role == UserRole.manager && location == '/admin/billing';
        if (!isAdminOrPlatform && !isManagerBilling) {
          return _getDefaultRouteForRole(profile.role);
        }
      }
      if (location.startsWith('/manager') && profile.role != UserRole.manager) {
        return _getDefaultRouteForRole(profile.role);
      }
      if (location.startsWith('/marketer') && profile.role != UserRole.marketer) {
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
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
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
      GoRoute(
        path: '/suspended',
        name: 'suspended',
        builder: (context, state) => const SuspendedScreen(),
      ),
      GoRoute(
        path: '/platform/dashboard',
        name: 'platformDashboard',
        builder: (context, state) => const PlatformDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/company-profile',
        name: 'adminCompanyProfile',
        builder: (context, state) => const CompanyProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const AdminSettingsScreen(),
      ),
      GoRoute(
        path: '/admin/settings',
        name: 'adminSettings',
        builder: (context, state) => const AdminSettingsScreen(),
      ),
      GoRoute(
        path: '/admin/billing',
        name: 'adminBilling',
        builder: (context, state) => const BillingScreen(),
      ),
      GoRoute(
        path: '/partner/profile',
        name: 'partnerProfile',
        builder: (context, state) => const PartnerProfileScreen(),
      ),
      GoRoute(
        path: '/properties/:id',
        name: 'propertyDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final refCode = state.uri.queryParameters['ref'];
          final campId = state.uri.queryParameters['camp'];
          return PropertyDetailScreen(
            propertyId: id,
            referralCode: refCode,
            campaignId: campId,
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/admin/inspections',
        name: 'adminInspections',
        builder: (context, state) => const AdminInspectionsScreen(),
      ),
      GoRoute(
        path: '/admin/commissions',
        name: 'adminCommissions',
        builder: (context, state) => const AdminCommissionsScreen(),
      ),
      GoRoute(
        path: '/admin/withdrawals',
        name: 'adminWithdrawals',
        builder: (context, state) => const AdminWithdrawalsScreen(),
      ),
      GoRoute(
        path: '/admin/invite-staff',
        name: 'adminInviteStaff',
        builder: (context, state) => const StaffInviteScreen(),
      ),
      GoRoute(
        path: '/admin/reports',
        name: 'adminReports',
        builder: (context, state) => const DailyReportsScreen(),
      ),
      GoRoute(
        path: '/admin/documents',
        name: 'adminDocuments',
        builder: (context, state) => const DocumentListScreen(),
      ),
      GoRoute(
        path: '/admin/documents/generate',
        name: 'adminDocumentGenerate',
        builder: (context, state) {
          final leadId = state.uri.queryParameters['leadId']!;
          return DocumentGeneratorScreen(leadId: leadId);
        },
      ),
      GoRoute(
        path: '/admin/documents/preview',
        name: 'adminDocumentPreview',
        builder: (context, state) {
          final url = state.uri.queryParameters['url']!;
          final title = state.uri.queryParameters['title']!;
          return DocumentPreviewScreen(fileUrl: url, title: title);
        },
      ),
      GoRoute(
        path: '/admin/campaigns',
        name: 'adminCampaigns',
        builder: (context, state) => const CampaignHistoryScreen(),
      ),
      GoRoute(
        path: '/admin/campaigns/generator',
        name: 'adminCampaignGenerator',
        builder: (context, state) {
          final propId = state.uri.queryParameters['propertyId'];
          return CampaignGeneratorScreen(propertyId: propId);
        },
      ),
      GoRoute(
        path: '/admin/campaigns/performance',
        name: 'adminCampaignPerformance',
        builder: (context, state) => const BlockPerformanceScreen(),
      ),
      GoRoute(
        path: '/admin/goals',
        name: 'adminGoals',
        builder: (context, state) => const GoalSettingScreen(),
      ),
      GoRoute(
        path: '/admin/goals/:id',
        name: 'adminGoalDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return GoalDetailScreen(goalId: id);
        },
      ),
      GoRoute(
        path: '/admin/analytics',
        name: 'adminAnalytics',
        builder: (context, state) => const AnalyticsDashboardScreen(),
      ),
      GoRoute(
        path: '/manager/analytics',
        name: 'managerAnalytics',
        builder: (context, state) => const AnalyticsDashboardScreen(),
      ),

      GoRoute(
        path: '/manager/campaigns',
        name: 'managerCampaigns',
        builder: (context, state) => const CampaignHistoryScreen(),
      ),
      GoRoute(
        path: '/manager/campaigns/generator',
        name: 'managerCampaignGenerator',
        builder: (context, state) {
          final propId = state.uri.queryParameters['propertyId'];
          return CampaignGeneratorScreen(propertyId: propId);
        },
      ),
      GoRoute(
        path: '/manager/goals',
        name: 'managerGoals',
        builder: (context, state) => const GoalSettingScreen(),
      ),
      GoRoute(
        path: '/manager/goals/:id',
        name: 'managerGoalDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return GoalDetailScreen(goalId: id);
        },
      ),

      GoRoute(
        path: '/marketer/campaigns/generator',
        name: 'marketerCampaignGenerator',
        builder: (context, state) {
          final propId = state.uri.queryParameters['propertyId'];
          return CampaignGeneratorScreen(propertyId: propId);
        },
      ),
      GoRoute(
        path: '/marketer/campaigns',
        name: 'marketerCampaigns',
        builder: (context, state) => const CampaignHistoryScreen(),
      ),
      GoRoute(
        path: '/partner/inspections',
        name: 'partnerInspections',
        builder: (context, state) => const PartnerInspectionsScreen(),
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
                builder: (context, state) => const AdminDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/properties',
                name: 'adminProperties',
                builder: (context, state) => const AdminPropertiesScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    name: 'adminPropertyAdd',
                    builder: (context, state) => const PropertyFormScreen(),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    name: 'adminPropertyEdit',
                    builder: (context, state) => PropertyFormScreen(
                      propertyId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/partners',
                name: 'adminPartners',
                builder: (context, state) => const PartnerListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'adminPartnerDetail',
                    builder: (context, state) => PartnerDetailScreen(
                      partnerId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/leads',
                name: 'adminLeads',
                builder: (context, state) {
                  final stage = state.uri.queryParameters['stage'];
                  return LeadListScreen(initialStageFilter: stage);
                },
                routes: [
                  GoRoute(
                    path: 'add',
                    name: 'adminLeadAdd',
                    builder: (context, state) => const ManualLeadScreen(),
                  ),
                  GoRoute(
                    path: 'import',
                    name: 'adminLeadImport',
                    builder: (context, state) => const LeadImportScreen(),
                  ),
                  GoRoute(
                    path: 'export',
                    name: 'adminLeadExport',
                    builder: (context, state) => const LeadExportScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'adminLeadDetail',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return LeadDetailScreen(leadId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── Manager shell ────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ManagerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _managerShellNavigatorKey,
            routes: [
              GoRoute(
                path: '/manager/dashboard',
                name: 'managerDashboard',
                builder: (context, state) => const ManagerDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/manager/team',
                name: 'managerTeam',
                builder: (context, state) => const ManagerTeamScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/manager/leads',
                name: 'managerLeads',
                builder: (context, state) {
                  final stage = state.uri.queryParameters['stage'];
                  return LeadListScreen(initialStageFilter: stage);
                },
                routes: [
                  GoRoute(
                    path: 'add',
                    name: 'managerLeadAdd',
                    builder: (context, state) => const ManualLeadScreen(),
                  ),
                  GoRoute(
                    path: 'import',
                    name: 'managerLeadImport',
                    builder: (context, state) => const LeadImportScreen(),
                  ),
                  GoRoute(
                    path: 'export',
                    name: 'managerLeadExport',
                    builder: (context, state) => const LeadExportScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'managerLeadDetail',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return LeadDetailScreen(leadId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/manager/reports',
                name: 'managerReports',
                builder: (context, state) => const DailyReportsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Marketer shell ───────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MarketerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _marketerShellNavigatorKey,
            routes: [
              GoRoute(
                path: '/marketer/dashboard',
                name: 'marketerDashboard',
                builder: (context, state) => const MarketerDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/marketer/leads',
                name: 'marketerLeads',
                builder: (context, state) {
                  final stage = state.uri.queryParameters['stage'];
                  return LeadListScreen(initialStageFilter: stage);
                },
                routes: [
                  GoRoute(
                    path: 'add',
                    name: 'marketerLeadAdd',
                    builder: (context, state) => const ManualLeadScreen(),
                  ),
                  GoRoute(
                    path: 'import',
                    name: 'marketerLeadImport',
                    builder: (context, state) => const LeadImportScreen(),
                  ),
                  GoRoute(
                    path: 'export',
                    name: 'marketerLeadExport',
                    builder: (context, state) => const LeadExportScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'marketerLeadDetail',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return LeadDetailScreen(leadId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/marketer/followups',
                name: 'marketerFollowups',
                builder: (context, state) => const MarketerFollowupsScreen(),
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
                builder: (context, state) => const PartnerDashboardScreen(),
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
                builder: (context, state) {
                  final stage = state.uri.queryParameters['stage'];
                  return PartnerLeadScreen(initialStageFilter: stage);
                },
                routes: [
                  GoRoute(
                    path: 'add',
                    name: 'partnerLeadAdd',
                    builder: (context, state) => const ManualLeadScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partner/earnings',
                name: 'partnerEarnings',
                builder: (context, state) => const EarningsScreen(),
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
                builder: (context, state) => const BuyerHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/buyer/inspections',
                name: 'buyerInspections',
                builder: (context, state) => const BuyerInspectionsScreen(),
                routes: [
                  GoRoute(
                    path: 'book',
                    name: 'buyerInspectionBook',
                    builder: (context, state) {
                      final propertyId = state.uri.queryParameters['propertyId']!;
                      return BookInspectionScreen(propertyId: propertyId);
                    },
                  ),
                  GoRoute(
                    path: 'confirm',
                    name: 'buyerInspectionConfirm',
                    builder: (context, state) {
                      final date = state.uri.queryParameters['date']!;
                      final time = state.uri.queryParameters['time']!;
                      final propTitle = state.uri.queryParameters['propTitle']!;
                      return InspectionConfirmationScreen(
                        date: date,
                        time: time,
                        propTitle: propTitle,
                      );
                    },
                  ),
                ],
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
