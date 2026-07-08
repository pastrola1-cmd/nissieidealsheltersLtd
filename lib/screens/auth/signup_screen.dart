import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/constants/app_strings.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

/// Sign-up screen for PPN.
class SignupScreen extends ConsumerStatefulWidget {
  final String? initialEmail;
  const SignupScreen({super.key, this.initialEmail});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

enum _UserRole { admin, partner, buyer }

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyCodeController = TextEditingController();
  final _newAgencyNameController = TextEditingController();

  bool _obscurePassword = true;
  _UserRole? _selectedRole;
  bool _createAgencyMode = true;
  String _selectedSubscriptionTier = 'free';

  List<Company> _companies = [];
  bool _isLoadingCompanies = false;
  String? _selectedCompanyId;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoadingCompanies = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final list = await service.getCompanies(excludeHidden: true);
      setState(() {
        _companies = [
          Company(
            id: 'manual',
            name: 'Join via Company Code (Manual ID)',
            createdAt: DateTime.now(),
          ),
          ...list,
        ];
        _selectedCompanyId = null;
      });
    } catch (e) {
      setState(() {
        _companies = [
          Company(
            id: 'manual',
            name: 'Join via Company Code (Manual ID)',
            createdAt: DateTime.now(),
          ),
        ];
        _selectedCompanyId = 'manual';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingCompanies = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _companyCodeController.dispose();
    _newAgencyNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a role'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    UserRole role;
    if (_selectedRole == _UserRole.admin) {
      role = UserRole.admin;
    } else if (_selectedRole == _UserRole.partner) {
      role = UserRole.partner;
    } else {
      role = UserRole.buyer;
    }

    String? companyId;
    if (_selectedRole == _UserRole.admin && !_createAgencyMode || _selectedRole == _UserRole.partner) {
      if (_selectedCompanyId == 'manual') {
        final code = _companyCodeController.text.trim();
        companyId = code.isNotEmpty ? code : null;
      } else {
        companyId = _selectedCompanyId;
      }
    }

    final createCompanyName = (_selectedRole == _UserRole.admin && _createAgencyMode)
        ? _newAgencyNameController.text.trim()
        : null;

    if (role == UserRole.partner && companyId != null && companyId.isNotEmpty) {
      try {
        final service = ref.read(supabaseServiceProvider);
        final company = await service.getCompany(companyId);
        if (company == null) {
          _showError('Agency code not found. Please verify the code.');
          return;
        }

        final partners = await service.getProfilesByRole(UserRole.partner, companyId: companyId);
        final maxPartners = company.plan.maxPartners;

        if (partners.length >= maxPartners) {
          _showPartnerLimitReachedDialog(company);
          return;
        }
      } catch (e) {
        // Silently let sign up handle any database connection errors
      }
    }

    final success = await ref.read(authProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: role,
          companyId: companyId != null && companyId.isNotEmpty ? companyId : null,
          createCompanyName: createCompanyName != null && createCompanyName.isNotEmpty ? createCompanyName : null,
          createSubscriptionTier: role == UserRole.admin && _createAgencyMode ? _selectedSubscriptionTier : null,
        );

    if (success && mounted) {
      if (role == UserRole.buyer) {
        final buyerId = ref.read(authProvider).profile?.id;
        if (buyerId != null) {
          await ref.read(leadProvider.notifier).checkAndCreateReferralLead(
                buyerId: buyerId,
                buyerName: _nameController.text.trim(),
                buyerPhone: _phoneController.text.trim(),
                buyerEmail: _emailController.text.trim(),
              );
        }
      }
    } else if (!success && mounted) {
      final errorMessage = ref.read(authProvider).errorMessage ?? 'Sign-up failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Text(
                  AppStrings.signUp,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Join ${AppStrings.appFullName} today',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Full Name ──
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration(
                    label: AppStrings.fullName,
                    hint: 'John Doe',
                    prefixIcon: Icons.person_outline,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.trim().split(' ').length < 2) {
                      return 'Please enter first and last name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // ── Email ──
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    label: AppStrings.email,
                    hint: 'you@example.com',
                    prefixIcon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // ── Phone ──
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    label: AppStrings.phone,
                    hint: '+234 801 234 5678',
                    prefixIcon: Icons.phone_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // ── Password ──
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  decoration: _inputDecoration(
                    label: AppStrings.password,
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),

                // ── Company / Agency Option Toggles (Admin only) ──
                if (_selectedRole == _UserRole.admin) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _createAgencyMode = true),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _createAgencyMode
                                ? AppColors.accent.withOpacity(0.08)
                                : Colors.transparent,
                            side: BorderSide(
                              color: _createAgencyMode ? AppColors.accent : AppColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Create New Agency'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _createAgencyMode = false),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: !_createAgencyMode
                                ? AppColors.accent.withOpacity(0.08)
                                : Colors.transparent,
                            side: BorderSide(
                              color: !_createAgencyMode ? AppColors.accent : AppColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Join Existing'),
                        ),
                      ),
                    ],
                  ),
                ],
                
                // ── Company Code or Agency Name Field ──
                if (_selectedRole == _UserRole.admin && _createAgencyMode) ...[
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _newAgencyNameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration(
                      label: 'New Agency Name *',
                      hint: 'e.g. Greenwood Listings',
                      prefixIcon: Icons.business_rounded,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your agency name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Select Subscription Plan *',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SubscriptionPlanCard(
                    title: 'Free Trial',
                    priceText: '₦0',
                    limitsText: '2 Listings • 1 Partner',
                    featuresText: 'Shared Nissie App branding, 10 leads/month',
                    badgeText: '7-Day Trial',
                    isSelected: _selectedSubscriptionTier == 'free',
                    activeColor: Colors.blueGrey,
                    onTap: () => setState(() => _selectedSubscriptionTier = 'free'),
                  ),
                  const SizedBox(height: 12),
                  _SubscriptionPlanCard(
                    title: 'Starter Plan',
                    priceText: '₦25,000',
                    limitsText: '10 Listings • 5 Partners',
                    featuresText: 'Basic Listings, Lead Pipeline',
                    badgeText: '14-Day Trial',
                    isSelected: _selectedSubscriptionTier == 'basic',
                    activeColor: AppColors.secondary,
                    onTap: () => setState(() => _selectedSubscriptionTier = 'basic'),
                  ),
                  const SizedBox(height: 12),
                  _SubscriptionPlanCard(
                    title: 'Agency Growth',
                    priceText: '₦50,000',
                    limitsText: '50 Listings • 25 Partners',
                    featuresText: 'Push Notifications, Analytics, Custom Logo',
                    badgeText: 'Best Value',
                    isSelected: _selectedSubscriptionTier == 'growth',
                    activeColor: AppColors.accent,
                    onTap: () => setState(() => _selectedSubscriptionTier = 'growth'),
                  ),
                  const SizedBox(height: 12),
                  _SubscriptionPlanCard(
                    title: 'Unlimited Scale',
                    priceText: '₦100,000',
                    limitsText: 'Unlimited Listings & Partners',
                    featuresText: 'Priority Ledger, Custom Domains, Full Support',
                    isSelected: _selectedSubscriptionTier == 'enterprise',
                    activeColor: Colors.amber[800] ?? Colors.amber,
                    onTap: () => setState(() => _selectedSubscriptionTier = 'enterprise'),
                  ),
                ] else if ((_selectedRole == _UserRole.admin && !_createAgencyMode) ||
                    _selectedRole == _UserRole.partner) ...[
                  const SizedBox(height: 18),
                  _isLoadingCompanies
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(color: AppColors.accent),
                          ),
                        )
                      : RawAutocomplete<Company>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            return _companies.where((Company company) {
                              return company.name
                                  .toLowerCase()
                                  .contains(textEditingValue.text.toLowerCase());
                            });
                          },
                          displayStringForOption: (Company company) => company.name,
                          onSelected: (Company company) {
                            setState(() {
                              _selectedCompanyId = company.id;
                            });
                          },
                          optionsViewBuilder: (BuildContext context,
                              AutocompleteOnSelected<Company> onSelected,
                              Iterable<Company> options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 8.0,
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.surface,
                                child: Container(
                                  width: MediaQuery.of(context).size.width - 64,
                                  constraints: const BoxConstraints(maxHeight: 220.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (BuildContext context, int index) {
                                        final Company option = options.elementAt(index);
                                        return InkWell(
                                          onTap: () {
                                            onSelected(option);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16.0, vertical: 14.0),
                                            decoration: BoxDecoration(
                                              border: index < options.length - 1
                                                  ? Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)))
                                                  : null,
                                            ),
                                            child: Text(
                                              option.name,
                                              style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          fieldViewBuilder: (BuildContext context,
                              TextEditingController textEditingController,
                              FocusNode focusNode,
                              VoidCallback onFieldSubmitted) {
                            // Sync selected company to text controller on first load
                            if (textEditingController.text.isEmpty && _selectedCompanyId != null) {
                              final current = _companies.firstWhere(
                                (c) => c.id == _selectedCompanyId,
                                orElse: () => _companies.first,
                              );
                              textEditingController.text = current.name;
                            }

                            return TextFormField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              onChanged: (value) {
                                final selectedCompany = _companies.firstWhere(
                                  (c) => c.id == _selectedCompanyId,
                                  orElse: () => Company(
                                      id: '',
                                      name: '',
                                      createdAt: DateTime.now()),
                                );
                                if (value != selectedCompany.name) {
                                  setState(() {
                                    _selectedCompanyId = null;
                                  });
                                }
                              },
                              decoration: _inputDecoration(
                                label: _selectedRole == _UserRole.admin
                                    ? 'Select Agency to Join *'
                                    : 'Select Agency (Type to Search) *',
                                hint: 'Search agency by name...',
                                prefixIcon: Icons.search_rounded,
                              ),
                              validator: (value) {
                                if (_selectedCompanyId == null) {
                                  return 'Please select an agency';
                                }
                                final selectedCompany = _companies.firstWhere(
                                  (c) => c.id == _selectedCompanyId,
                                  orElse: () => Company(
                                      id: '',
                                      name: '',
                                      createdAt: DateTime.now()),
                                );
                                if (textEditingController.text != selectedCompany.name) {
                                  return 'Please select an agency from suggestions';
                                }
                                return null;
                              },
                            );
                          },
                        ),
                  if (_selectedCompanyId == 'manual') ...[
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _companyCodeController,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: _selectedRole == _UserRole.admin
                            ? 'Company Code (Tenant ID) *'
                            : 'Company Code (Optional - blank for default)',
                        hint: 'e.g. d3b07384-d113-4ec6-a5d7-ecf9e01103e6',
                        prefixIcon: Icons.vpn_key_outlined,
                      ),
                      validator: (value) {
                        if (_selectedRole == _UserRole.admin) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Company Code is required to join an existing agency';
                          }
                          final uuidRegex = RegExp(
                              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
                          if (!uuidRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid Company Code (UUID)';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ],
                const SizedBox(height: 28),

                // ── Role Selector ──
                Text(
                  AppStrings.selectRole,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                
                Column(
                  children: [
                    _RoleCard(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Agency Admin / Owner',
                      subtitle: 'I own/manage a real estate agency portal',
                      isSelected: _selectedRole == _UserRole.admin,
                      onTap: () {
                        setState(() {
                          _selectedRole = _UserRole.admin;
                          _createAgencyMode = true;
                          _companyCodeController.clear();
                          _newAgencyNameController.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _RoleCard(
                      icon: Icons.handshake_rounded,
                      title: 'Affiliate Partner',
                      subtitle: 'I want to sell properties and earn commissions',
                      isSelected: _selectedRole == _UserRole.partner,
                      onTap: () {
                        setState(() {
                          _selectedRole = _UserRole.partner;
                          _createAgencyMode = false;
                          _companyCodeController.clear();
                          _newAgencyNameController.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _RoleCard(
                      icon: Icons.home_rounded,
                      title: 'Home Buyer',
                      subtitle: 'I want to browse and purchase premium properties',
                      isSelected: _selectedRole == _UserRole.buyer,
                      onTap: () {
                        setState(() {
                          _selectedRole = _UserRole.buyer;
                          _companyCodeController.clear();
                          _newAgencyNameController.clear();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Create Account Button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: authState.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : ElevatedButton(
                          onPressed: _handleSignup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.textOnAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                            textStyle: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text(AppStrings.signUp),
                        ),
                ),
                const SizedBox(height: 24),

                // ── Login Link ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.hasAccount,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        AppStrings.login,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared Input Decoration ──
  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(prefixIcon, color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showPartnerLimitReachedDialog(Company company) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registration Limit Reached'),
        content: Text(
          'The agency "${company.name}" has reached the maximum partner registration limit for its current subscription tier.\n\nPlease ask the agency administrator to contact Nissie Ideal Shelters support to upgrade their subscription.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// A selectable role card used in the sign-up form.
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent.withOpacity(0.1)
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected ? AppColors.accent : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isSelected ? AppColors.accent : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A selectable subscription plan card used in the sign-up form.
class _SubscriptionPlanCard extends StatelessWidget {
  final String title;
  final String priceText;
  final String limitsText;
  final String featuresText;
  final String? badgeText;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;

  const _SubscriptionPlanCard({
    required this.title,
    required this.priceText,
    required this.limitsText,
    required this.featuresText,
    this.badgeText,
    required this.isSelected,
    required this.onTap,
    this.activeColor = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: isSelected ? activeColor : AppColors.textTertiary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: isSelected ? activeColor : AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? activeColor : AppColors.secondary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  priceText,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/ month',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    limitsText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    featuresText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
