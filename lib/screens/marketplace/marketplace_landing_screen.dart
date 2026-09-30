import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/constants/app_strings.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/marketplace_provider.dart';
import 'package:nissie_ideal_shelters/providers/wallet_provider.dart';
import 'package:nissie_ideal_shelters/screens/marketplace/widgets/marketplace_property_card.dart';
import 'package:nissie_ideal_shelters/screens/marketplace/widgets/my_inspections_modal.dart';
import 'package:nissie_ideal_shelters/screens/wallet/renter_wallet_modal.dart';
import 'package:nissie_ideal_shelters/screens/wallet/agent_withdrawal_modal.dart';
import 'package:nissie_ideal_shelters/screens/marketplace/widgets/agent_pin_verification_modal.dart';
import 'package:nissie_ideal_shelters/screens/marketplace/widgets/contact_modal.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nissie_ideal_shelters/core/utils/navigation_helpers.dart';

class MarketplaceLandingScreen extends ConsumerStatefulWidget {
  const MarketplaceLandingScreen({super.key});

  @override
  ConsumerState<MarketplaceLandingScreen> createState() => _MarketplaceLandingScreenState();
}

class _MarketplaceLandingScreenState extends ConsumerState<MarketplaceLandingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _launchExternalUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }


  void _showPolicyDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Text(content, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155))),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marketplaceState = ref.watch(marketplaceProvider);
    final notifier = ref.read(marketplaceProvider.notifier);
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.isAuthenticated && authState.profile != null;

    final filter = marketplaceState.filter;
    final properties = marketplaceState.filteredProperties;

    final isWide = MediaQuery.of(context).size.width > 900;
    final isTablet = MediaQuery.of(context).size.width > 600 && !isWide;

    return DoubleBackExitScope(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.chat_bubble_rounded),
        label: const Text(
          'Chat / Inquire',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: () => ContactModal.show(context),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── App Header / Navigation Bar ──
          SliverAppBar(
            pinned: true,
            elevation: 1,
            backgroundColor: Colors.white,
            automaticallyImplyLeading: false,
            toolbarHeight: 68,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/logo.jpg',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 38,
                      height: 38,
                      color: AppColors.primary,
                      child: const Icon(Icons.apartment, color: Colors.white, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (isWide || isTablet) ? 'NISSIE IDEAL SHELTERS' : 'NISSIE SHELTERS',
                        style: TextStyle(
                          fontSize: (isWide || isTablet) ? 15 : 13.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (isWide || isTablet)
                        const Text(
                          'Verified Properties • Rent & Sale',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // About Us Button
              if (isWide || isTablet)
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.info_outline, size: 17),
                    label: const Text('About Us', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    onPressed: () => context.push('/about'),
                  ),
                ),

              // Contact Us Button
              if (isWide || isTablet)
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.support_agent_outlined, size: 17),
                    label: const Text('Contact', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    onPressed: () => context.push('/contact'),
                  ),
                ),

              // List Property Button
              if (isWide || isTablet)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.add_home_outlined, size: 18),
                    label: const Text('List Property', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () => context.push('/list-property'),
                  ),
                )
              else
                IconButton(
                  tooltip: 'List Property',
                  icon: const Icon(Icons.add_home_outlined, color: Color(0xFF334155), size: 22),
                  onPressed: () => context.push('/list-property'),
                ),

              // Auth Actions
              if (isAuthenticated) ...[
                // If logged in as Renter/Buyer
                if (authState.profile?.role == UserRole.buyer) ...[
                  // My Inspections button
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Builder(builder: (context) {
                      final count = ref.watch(marketplaceProvider.notifier).getBookingsForUser(
                        userId: authState.profile?.id,
                        email: authState.profile?.email,
                        phone: authState.profile?.phone,
                      ).length;

                      if (isWide || isTablet) {
                        return OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                          label: Text(
                            count > 0 ? 'My Inspections ($count)' : 'My Inspections',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          onPressed: () => MyInspectionsModal.show(context),
                        );
                      } else {
                        return IconButton(
                          tooltip: 'My Inspections',
                          icon: Badge(
                            isLabelVisible: count > 0,
                            label: Text('$count'),
                            child: const Icon(Icons.calendar_month, color: AppColors.primary, size: 22),
                          ),
                          onPressed: () => MyInspectionsModal.show(context),
                        );
                      }
                    }),
                  ),

                  // Wallet button
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Builder(builder: (context) {
                      final balance = ref.watch(walletProvider).wallet.balance;
                      if (isWide || isTablet) {
                        return OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.green),
                          label: Text(
                            'Wallet: ₦${NumberFormat('#,##0').format(balance)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          onPressed: () => RenterWalletModal.show(context),
                        );
                      } else {
                        return IconButton(
                          tooltip: 'Digital Wallet',
                          icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.green, size: 22),
                          onPressed: () => RenterWalletModal.show(context),
                        );
                      }
                    }),
                  ),

                  // User Account Menu
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: PopupMenuButton<String>(
                      tooltip: 'My Account',
                      offset: const Offset(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                (authState.profile?.fullName ?? 'U').isNotEmpty
                                    ? (authState.profile!.fullName![0].toUpperCase())
                                    : 'U',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (isWide) ...[
                              const SizedBox(width: 8),
                              Text(
                                (authState.profile?.fullName ?? 'User').split(' ').first,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                              const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                            ],
                          ],
                        ),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'dashboard',
                          child: Row(
                            children: [
                              Icon(Icons.dashboard_outlined, size: 18, color: Color(0xFF0F172A)),
                              SizedBox(width: 10),
                              Text('My Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'inspections',
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                              SizedBox(width: 10),
                              Text('My Inspections & PINs'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'wallet',
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.green),
                              SizedBox(width: 10),
                              Text('Digital Wallet & Deposits'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'about',
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: Color(0xFF475569)),
                              SizedBox(width: 10),
                              Text('About Nissie (RC: 7867098)'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'contact',
                          child: Row(
                            children: [
                              Icon(Icons.support_agent_outlined, size: 18, color: Color(0xFF475569)),
                              SizedBox(width: 10),
                              Text('Contact & Inquiries'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, size: 18, color: Colors.redAccent),
                              SizedBox(width: 10),
                              Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (val) {
                        if (val == 'dashboard') {
                          context.push('/buyer/browse');
                        } else if (val == 'inspections') {
                          MyInspectionsModal.show(context);
                        } else if (val == 'wallet') {
                          RenterWalletModal.show(context);
                        } else if (val == 'verify_pin') {
                          AgentPinVerificationModal.show(context);
                        } else if (val == 'withdraw') {
                          AgentWithdrawalModal.show(context);
                        } else if (val == 'about') {
                          context.push('/about');
                        } else if (val == 'contact') {
                          context.push('/contact');
                        } else if (val == 'logout') {
                          ref.read(authProvider.notifier).logout();
                        }
                      },
                    ),
                  ),
                ] else ...[
                  // Staff / Partner / Landlord Dashboard Button
                  Padding(
                    padding: EdgeInsets.only(right: (isWide || isTablet) ? 16.0 : 8.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: (isWide || isTablet) ? 14 : 9,
                          vertical: (isWide || isTablet) ? 10 : 7,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(Icons.dashboard_outlined, size: (isWide || isTablet) ? 16 : 14),
                      label: Text(
                        (isWide || isTablet) ? 'My Dashboard' : 'Dashboard',
                        style: TextStyle(
                          fontSize: (isWide || isTablet) ? 13 : 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        final role = authState.profile!.role;
                        switch (role) {
                          case UserRole.landlord:
                            context.push('/landlord/dashboard');
                            break;
                          case UserRole.buyer:
                            context.go('/buyer/browse');
                            break;
                          case UserRole.platformAdmin:
                            context.go('/platform/dashboard');
                            break;
                          default:
                            context.go('/${role.value}/dashboard');
                        }
                      },
                    ),
                  ),
                ],
              ] else ...[
                // Unauthenticated Actions
                if (isWide || isTablet) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => context.push('/login'),
                      child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () => context.push('/signup'),
                      child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
                // Popup Menu for Staff Portal & Mobile Login
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: PopupMenuButton<String>(
                    tooltip: 'More Options',
                    offset: const Offset(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    icon: const Icon(Icons.more_vert, color: Color(0xFF475569)),
                    itemBuilder: (context) => [
                      if (!isWide && !isTablet) ...[
                        const PopupMenuItem(
                          value: 'login',
                          child: Row(
                            children: [
                              Icon(Icons.login, size: 18, color: AppColors.primary),
                              SizedBox(width: 10),
                              Text('Sign In (Renter / Buyer)'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'signup',
                          child: Row(
                            children: [
                              Icon(Icons.person_add_outlined, size: 18, color: AppColors.primary),
                              SizedBox(width: 10),
                              Text('Create Free Account'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                      ],
                      const PopupMenuItem(
                        value: 'staff_login',
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 18, color: Color(0xFF475569)),
                            SizedBox(width: 10),
                            Text('Staff & Partner Portal'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'list_prop',
                        child: Row(
                          children: [
                            Icon(Icons.add_home_outlined, size: 18, color: Color(0xFF475569)),
                            SizedBox(width: 10),
                            Text('List Property (Agent / Owner)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'about',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Color(0xFF475569)),
                            SizedBox(width: 10),
                            Text('About Nissie (RC: 7867098)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'contact',
                        child: Row(
                          children: [
                            Icon(Icons.support_agent_outlined, size: 18, color: Color(0xFF475569)),
                            SizedBox(width: 10),
                            Text('Contact Us & Inquiries'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'verify_pin',
                        child: Row(
                          children: [
                            Icon(Icons.pin_outlined, size: 18, color: AppColors.primary),
                            SizedBox(width: 10),
                            Text('Field Agent: Verify 4-Digit PIN'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'wallet',
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.green),
                            SizedBox(width: 10),
                            Text('Digital Wallet & Deposits'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (val) {
                      if (val == 'login') {
                        context.push('/login');
                      } else if (val == 'signup') {
                        context.push('/signup');
                      } else if (val == 'staff_login') {
                        context.push('/login');
                      } else if (val == 'about') {
                        context.push('/about');
                      } else if (val == 'contact') {
                        context.push('/contact');
                      } else if (val == 'list_prop') {
                        context.push('/list-property');
                      } else if (val == 'verify_pin') {
                        AgentPinVerificationModal.show(context);
                      } else if (val == 'wallet') {
                        RenterWalletModal.show(context);
                      }
                    },
                  ),
                ),
              ],
            ],
          ),

          // ── Hero Banner Section ──
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 48.0 : 20.0,
                vertical: 36.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Nigeria\'s Verified & Protected Property Portal',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      Text(
                        'Find Verified Homes for Rent & Sale in Abuja & Lagos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isWide ? 34 : 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        'Say goodbye to fake agents and wasted inspection fees. Book verified physical inspections for only ₦10,000 protected until you inspect.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF94A3B8),
                          fontSize: isWide ? 15 : 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Search & Filter Box ──
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // 1. Listing Type Selector Tabs (scrollable on phones)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                _buildListingTypeTab(
                                  label: 'All Listings',
                                  type: 'all',
                                  current: filter.listingType,
                                  onTap: () => notifier.setListingType('all'),
                                ),
                                const SizedBox(width: 8),
                                _buildListingTypeTab(
                                  label: 'For Rent 🏠',
                                  type: 'rent',
                                  current: filter.listingType,
                                  onTap: () => notifier.setListingType('rent'),
                                ),
                                const SizedBox(width: 8),
                                _buildListingTypeTab(
                                  label: 'For Sale 🏷️',
                                  type: 'sale',
                                  current: filter.listingType,
                                  onTap: () => notifier.setListingType('sale'),
                                ),
                                const SizedBox(width: 8),
                                _buildListingTypeTab(
                                  label: 'Nissie Estates 👑',
                                  type: 'nissie_estates',
                                  current: filter.listingType,
                                  onTap: () => notifier.setListingType('nissie_estates'),
                                ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 2. Search Input & City Selector
                            Row(
                              children: [
                                // Search Input
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (val) {
                                      notifier.setSearchQuery(val);
                                      setState(() {});
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Search district (e.g. Maitama, Lekki, Guzape, Gwarinpa)...',
                                      prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                                      suffixIcon: _searchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 18),
                                              onPressed: () {
                                                _searchController.clear();
                                                notifier.setSearchQuery('');
                                                setState(() {});
                                              },
                                            )
                                          : null,
                                      filled: true,
                                      fillColor: const Color(0xFFF1F5F9),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 3. City Quick Filters & Bedroom Counts
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  const Text(
                                    'City:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCityChip('All', filter.selectedCity, () => notifier.setCity('All')),
                                  _buildCityChip('Abuja', filter.selectedCity, () => notifier.setCity('Abuja')),
                                  _buildCityChip('Lagos', filter.selectedCity, () => notifier.setCity('Lagos')),
                                  _buildCityChip('PH', filter.selectedCity, () => notifier.setCity('Port Harcourt')),
                                  _buildCityChip('Ibadan', filter.selectedCity, () => notifier.setCity('Ibadan')),
                                  const SizedBox(width: 16),
                                  const Text(
                                    'Beds:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildBedChip('Any', 0, filter.minBedrooms, () => notifier.setBedrooms(0)),
                                  _buildBedChip('1 Bed', 1, filter.minBedrooms, () => notifier.setBedrooms(1)),
                                  _buildBedChip('2 Beds', 2, filter.minBedrooms, () => notifier.setBedrooms(2)),
                                  _buildBedChip('3 Beds', 3, filter.minBedrooms, () => notifier.setBedrooms(3)),
                                  _buildBedChip('4+ Beds', 4, filter.minBedrooms, () => notifier.setBedrooms(4)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 4. Price / Budget Quick Filter Row
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  const Text(
                                    'Price:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (filter.listingType == 'rent') ...[
                                    _buildPriceChip('Any Budget', 'all', filter.selectedPriceRange, () => notifier.setPriceRange(rangeKey: 'all')),
                                    _buildPriceChip('Under ₦2M', 'under_2m', filter.selectedPriceRange, () => notifier.setPriceRange(max: 2000000, rangeKey: 'under_2m')),
                                    _buildPriceChip('₦2M - ₦5M', '2m_5m', filter.selectedPriceRange, () => notifier.setPriceRange(min: 2000000, max: 5000000, rangeKey: '2m_5m')),
                                    _buildPriceChip('₦5M - ₦10M', '5m_10m', filter.selectedPriceRange, () => notifier.setPriceRange(min: 5000000, max: 10000000, rangeKey: '5m_10m')),
                                    _buildPriceChip('Above ₦10M', 'above_10m', filter.selectedPriceRange, () => notifier.setPriceRange(min: 10000000, rangeKey: 'above_10m')),
                                  ] else ...[
                                    _buildPriceChip('Any Budget', 'all', filter.selectedPriceRange, () => notifier.setPriceRange(rangeKey: 'all')),
                                    _buildPriceChip('Under ₦10M', 'under_10m', filter.selectedPriceRange, () => notifier.setPriceRange(max: 10000000, rangeKey: 'under_10m')),
                                    _buildPriceChip('₦10M - ₦25M', '10m_25m', filter.selectedPriceRange, () => notifier.setPriceRange(min: 10000000, max: 25000000, rangeKey: '10m_25m')),
                                    _buildPriceChip('₦25M - ₦50M', '25m_50m', filter.selectedPriceRange, () => notifier.setPriceRange(min: 25000000, max: 50000000, rangeKey: '25m_50m')),
                                    _buildPriceChip('₦50M - ₦100M', '50m_100m', filter.selectedPriceRange, () => notifier.setPriceRange(min: 50000000, max: 100000000, rangeKey: '50m_100m')),
                                    _buildPriceChip('Above ₦100M', 'above_100m', filter.selectedPriceRange, () => notifier.setPriceRange(min: 100000000, rangeKey: 'above_100m')),
                                  ],
                                  const SizedBox(width: 8),
                                  _buildCustomPriceButton(context, notifier, filter),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Results Summary Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 48.0 : 20.0,
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (marketplaceState.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 16, color: Color(0xFFB45309)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              marketplaceState.errorMessage!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                            ),
                          ),
                          TextButton(
                            onPressed: () => notifier.loadMarketplace(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          marketplaceState.isLoading && properties.isEmpty
                              ? 'Loading verified properties…'
                              : '${properties.length} Verified Propert${properties.length == 1 ? 'y' : 'ies'} Available',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      DropdownButton<String>(
                        value: filter.sortOrder,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.sort, size: 16),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        items: const [
                          DropdownMenuItem(value: 'newest', child: Text('Newest')),
                          DropdownMenuItem(value: 'price_asc', child: Text('Price ↑')),
                          DropdownMenuItem(value: 'price_desc', child: Text('Price ↓')),
                        ],
                        onChanged: (v) {
                          if (v != null) notifier.setSortOrder(v);
                        },
                      ),
                      if (filter.listingType != 'all' || filter.selectedCity != 'All' || filter.minBedrooms > 0 || filter.searchQuery.isNotEmpty || filter.selectedPriceRange != 'all')
                        TextButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reset'),
                          onPressed: () {
                            _searchController.clear();
                            notifier.resetFilters();
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Property Grid / Feed ──
          if (marketplaceState.isLoading && properties.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isWide ? 48.0 : 20.0),
                child: Column(
                  children: List.generate(
                    3,
                    (_) => Container(
                      height: 220,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (properties.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'No properties matched your search',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Try clearing some filters or searching for another district.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () {
                          _searchController.clear();
                          notifier.resetFilters();
                        },
                        child: const Text('View All Properties', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 48.0 : 20.0,
              ),
              sliver: isWide
                  ? SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => MarketplacePropertyCard(
                          property: properties[index],
                          onTap: () => context.push('/properties/${properties[index].id}'),
                        ),
                        childCount: properties.length,
                      ),
                    )
                  : (isTablet
                      ? SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.88,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => MarketplacePropertyCard(
                              property: properties[index],
                              onTap: () => context.push('/properties/${properties[index].id}'),
                            ),
                            childCount: properties.length,
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => MarketplacePropertyCard(
                              property: properties[index],
                              onTap: () => context.push('/properties/${properties[index].id}'),
                            ),
                            childCount: properties.length,
                          ),
                        )),
            ),

          // ── How It Works Explainer Banner ──
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: isWide ? 48.0 : 20.0,
                vertical: 36.0,
              ),
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🛡️ HOW VERIFIED PHYSICAL INSPECTIONS WORK',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Rent & Buy Real Estate Without Getting Extorted',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 24,
                    runSpacing: 20,
                    children: [
                      _buildStepCard(
                        step: '1',
                        title: 'Browse & Choose',
                        description: 'Select your preferred house or apartment in Abuja or Lagos from our verified listings.',
                      ),
                      _buildStepCard(
                        step: '2',
                        title: 'Pay ₦10,000 Deposit',
                        description: 'Pay your tour deposit securely via Card, Transfer, or Wallet. You receive a secret 4-Digit PIN.',
                      ),
                      _buildStepCard(
                        step: '3',
                        title: 'Inspect & Release PIN',
                        description: 'Meet the assigned verified agent on-site. Only release your PIN after the inspection is complete.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Rich 4-Column Corporate Footer ──
          SliverToBoxAdapter(
            child: _buildCorporateFooter(context, isWide, isTablet, notifier),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildListingTypeTab({
    required String label,
    required String type,
    required String current,
    required VoidCallback onTap,
  }) {
    final isSelected = current == type;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCityChip(String city, String current, VoidCallback onTap) {
    final isSelected = current == city;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(city),
        selected: isSelected,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : const Color(0xFF334155),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildBedChip(String label, int count, int current, VoidCallback onTap) {
    final isSelected = current == count;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF0F172A).withValues(alpha: 0.12),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildPriceChip(String label, String rangeKey, String current, VoidCallback onTap) {
    final isSelected = current == rangeKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF059669).withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF059669) : const Color(0xFF334155),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildCustomPriceButton(BuildContext context, MarketplaceNotifier notifier, MarketplaceFilter filter) {
    final isCustom = filter.selectedPriceRange == 'custom';
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ActionChip(
        avatar: Icon(Icons.tune, size: 14, color: isCustom ? const Color(0xFF059669) : const Color(0xFF475569)),
        label: Text(
          isCustom
              ? (filter.minPrice != null && filter.maxPrice != null
                  ? '₦${(filter.minPrice! / 1000000).toStringAsFixed(1)}M–${(filter.maxPrice! / 1000000).toStringAsFixed(1)}M'
                  : filter.maxPrice != null
                      ? 'Max ₦${(filter.maxPrice! / 1000000).toStringAsFixed(1)}M'
                      : 'Min ₦${(filter.minPrice! / 1000000).toStringAsFixed(1)}M')
              : 'Custom ₦',
        ),
        backgroundColor: isCustom ? const Color(0xFF059669).withValues(alpha: 0.15) : Colors.grey.shade100,
        labelStyle: TextStyle(
          color: isCustom ? const Color(0xFF059669) : const Color(0xFF334155),
          fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onPressed: () => _showCustomPriceDialog(context, notifier),
      ),
    );
  }

  void _showCustomPriceDialog(BuildContext context, MarketplaceNotifier notifier) {
    final minCtrl = TextEditingController();
    final maxCtrl = TextEditingController();
    String? error;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.monetization_on_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Custom Price Range (₦)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minimum Price (₦)',
                hintText: 'e.g. 5,000,000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: maxCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Maximum Price (₦)',
                hintText: 'e.g. 50,000,000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                errorText: error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final min = minCtrl.text.trim().isEmpty ? null : double.tryParse(minCtrl.text.replaceAll(',', '').trim());
              final max = maxCtrl.text.trim().isEmpty ? null : double.tryParse(maxCtrl.text.replaceAll(',', '').trim());
              String? err;
              if (min == null && max == null) {
                err = 'Enter a min or max price';
              } else if ((min != null && min < 0) || (max != null && max < 0)) {
                err = 'Prices cannot be negative';
              } else if (min != null && max != null && min > max) {
                err = 'Min cannot exceed max';
              }
              if (err != null) {
                setDialogState(() => error = err);
                return;
              }
              notifier.setPriceRange(min: min, max: max, rangeKey: 'custom');
              Navigator.pop(context);
            },
            child: const Text('Apply Price Filter', style: TextStyle(color: Colors.white)),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    required String description,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorporateFooter(
    BuildContext context,
    bool isWide,
    bool isTablet,
    MarketplaceNotifier notifier,
  ) {
    return Container(
      color: const Color(0xFF0B132B),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 48 : (isTablet ? 32 : 20),
        vertical: 48,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4-Column Layout
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildCompanyInfoColumn(context)),
                const SizedBox(width: 32),
                Expanded(flex: 2, child: _buildPropertiesColumn(context, notifier)),
                const SizedBox(width: 32),
                Expanded(flex: 2, child: _buildPortalsColumn(context)),
                const SizedBox(width: 32),
                Expanded(flex: 3, child: _buildContactColumn(context)),
              ],
            )
          else ...[
            _buildCompanyInfoColumn(context),
            const SizedBox(height: 32),
            if (isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildPropertiesColumn(context, notifier)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildPortalsColumn(context)),
                ],
              )
            else ...[
              _buildPropertiesColumn(context, notifier),
              const SizedBox(height: 28),
              _buildPortalsColumn(context),
            ],
            const SizedBox(height: 32),
            _buildContactColumn(context),
          ],

          const SizedBox(height: 40),
          const Divider(color: Colors.white12, thickness: 1),
          const SizedBox(height: 24),

          // Bottom Bar
          _buildFooterBottomBar(context, isWide),
        ],
      ),
    );
  }

  Widget _buildCompanyInfoColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/logo.jpg',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 36,
                  height: 36,
                  color: AppColors.primary,
                  child: const Icon(Icons.apartment, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NISSIE IDEAL SHELTERS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Real Estate • Construction • Facilities',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, color: Color(0xFF38BDF8), size: 14),
              SizedBox(width: 6),
              Text(
                'CAC Reg: RC 7867098',
                style: TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Nigeria’s trusted proptech platform providing verified properties for rent and sale, anti-extortion inspection scheduling, and institutional title due-diligence in Abuja and Lagos.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.55),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTrustBadge(Icons.shield_outlined, 'Escrow Safe'),
            _buildTrustBadge(Icons.verified_user_outlined, 'Zero Extortion'),
            _buildTrustBadge(Icons.domain_verification, 'Verified Titles'),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesColumn(BuildContext context, MarketplaceNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROPERTIES & LIVING',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 16),
        _buildFooterLink(
          'Apartments & Houses for Rent',
          onTap: () {
            notifier.setListingType('rent');
            _scrollToTop();
          },
        ),
        _buildFooterLink(
          'Properties & Land for Sale',
          onTap: () {
            notifier.setListingType('sale');
            _scrollToTop();
          },
        ),
        _buildFooterLink(
          'Shortlet & Serviced Apartments',
          onTap: () {
            notifier.setListingType('shortlet');
            _scrollToTop();
          },
        ),
        _buildFooterLink(
          'List Your Property (Agents & Owners)',
          onTap: () => context.push('/list-property'),
        ),
        _buildFooterLink(
          'Verify Field Agent PIN',
          onTap: () => AgentPinVerificationModal.show(context),
        ),
      ],
    );
  }

  Widget _buildPortalsColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TRUST & PORTALS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 16),
        _buildFooterLink(
          'About Nissie Shelters',
          onTap: () => context.push('/about'),
        ),
        _buildFooterLink(
          'Staff & Partner Portal',
          onTap: () => context.push('/login'),
        ),
        _buildFooterLink(
          'Tenant / Buyer Digital Wallet',
          onTap: () => RenterWalletModal.show(context),
        ),
        _buildFooterLink(
          'Inspection Safety Policy',
          onTap: () => context.push('/about'),
        ),
        _buildFooterLink(
          'Contact Customer Support',
          onTap: () => context.push('/contact'),
        ),
      ],
    );
  }

  Widget _buildContactColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONTACT & OFFICES',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 16),
        _buildOfficeItem(
          icon: Icons.location_on_outlined,
          title: 'Office Headquarters:',
          detail: 'Suite 2, Shema filling station complex, Asokoro extension, After Abacha barracks bridge, Abuja Keffi Expressway.',
        ),
        const SizedBox(height: 12),
        // Phone 1
        InkWell(
          onTap: () => _launchExternalUrl('tel:+2349135598800'),
          child: const Row(
            children: [
              Icon(Icons.phone_outlined, color: Color(0xFF38BDF8), size: 15),
              SizedBox(width: 8),
              Text(
                '+234 913 559 8800',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Phone 2
        InkWell(
          onTap: () => _launchExternalUrl('tel:+2348065441537'),
          child: const Row(
            children: [
              Icon(Icons.phone_outlined, color: Color(0xFF38BDF8), size: 15),
              SizedBox(width: 8),
              Text(
                '+234 806 544 1537',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // WhatsApp
        InkWell(
          onTap: () => _launchExternalUrl('https://wa.me/2349135598800?text=Hello%20Nissie%20Ideal%20Shelters'),
          child: const Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: Color(0xFF22C55E), size: 15),
              SizedBox(width: 8),
              Text(
                'WhatsApp (+234 913 559 8800)',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Email
        InkWell(
          onTap: () => _launchExternalUrl('mailto:nissieidealshelterslimited@gmail.com'),
          child: const Row(
            children: [
              Icon(Icons.email_outlined, color: Color(0xFF38BDF8), size: 15),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'nissieidealshelterslimited@gmail.com',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF38BDF8)),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.send_outlined, size: 15, color: Color(0xFF38BDF8)),
            label: const Text(
              'Send Inquiry / Message',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
            onPressed: () => context.push('/contact'),
          ),
        ),
      ],
    );
  }

  Widget _buildOfficeItem({
    required IconData icon,
    required String title,
    required String detail,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white54, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, height: 1.4),
              children: [
                TextSpan(
                  text: '$title ',
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: detail,
                  style: const TextStyle(color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLink(String label, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterBottomBar(BuildContext context, bool isWide) {
    const copyright = '© 2026 Nissie Ideal Shelters Limited (RC: 7867098). All rights reserved.';
    final links = [
      TextButton(
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
        onPressed: () => _showPolicyDialog(
          context,
          'Terms of Service',
          'Nissie Ideal Shelters Limited provides property listing verification, inspection escrow, and agency coordination services. All listing details and pricing are provided by verified property owners and developers. Clients agree to conduct physical inspections using the official 4-digit verification PIN to ensure safety and prevent fraudulent fees.',
        ),
        child: const Text('Terms of Service', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
      ),
      TextButton(
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
        onPressed: () => _showPolicyDialog(
          context,
          'Privacy Policy',
          'Your contact and inquiry information is encrypted and transmitted securely via Supabase. We do not sell or lease your personal information to third parties. Contact details are solely utilized to coordinate scheduled property viewings and client communication.',
        ),
        child: const Text('Privacy Policy', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
      ),
      TextButton(
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
        onPressed: () => context.push('/about'),
        child: const Text('Anti-Extortion Guarantee', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5)),
      ),
    ];

    if (isWide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            copyright,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Row(children: links),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(children: links),
          const SizedBox(height: 8),
          const Text(
            copyright,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      );
    }
  }
}
