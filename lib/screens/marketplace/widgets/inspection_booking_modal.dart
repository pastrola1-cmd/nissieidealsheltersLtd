import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/constants/app_strings.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/marketplace_provider.dart';
import 'package:nissie_ideal_shelters/providers/wallet_provider.dart';
import 'package:nissie_ideal_shelters/screens/marketplace/widgets/my_inspections_modal.dart';
import 'package:nissie_ideal_shelters/services/paystack_service.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

class InspectionBookingModal extends ConsumerStatefulWidget {
  final Property property;

  const InspectionBookingModal({
    super.key,
    required this.property,
  });

  static Future<void> show(BuildContext context, Property property) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InspectionBookingModal(property: property),
    );
  }

  @override
  ConsumerState<InspectionBookingModal> createState() => _InspectionBookingModalState();
}

class _InspectionBookingModalState extends ConsumerState<InspectionBookingModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTime = '11:00 AM';

  final List<String> _timeSlots = const [
    '09:00 AM',
    '11:00 AM',
    '01:00 PM',
    '03:00 PM',
    '05:00 PM',
  ];

  bool _createAccount = true;
  bool _obscurePassword = true;
  bool _isRegistering = false;
  bool _isProcessingPayment = false;
  bool _isSubmitted = false;
  InspectionBooking? _createdBooking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(authProvider).profile;
      if (profile != null) {
        setState(() {
          _nameController.text = profile.fullName ?? '';
          _phoneController.text = profile.phone ?? '';
          _emailController.text = profile.email ?? '';
          _createAccount = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleBooking() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    String? renterId = authState.profile?.id;

    if (!authState.isAuthenticated && _createAccount && _passwordController.text.isNotEmpty) {
      setState(() => _isRegistering = true);
      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        final fullName = _nameController.text.trim();
        final phone = _phoneController.text.trim();

        final success = await ref.read(authProvider.notifier).signUp(
          email: email,
          password: password,
          fullName: fullName,
          phone: phone,
          role: UserRole.buyer,
          companyId: AppStrings.defaultCompanyId,
        );
        if (success) {
          renterId = ref.read(authProvider).profile?.id;
        } else {
          // Try login (existing account with same password)
          final loggedIn = await ref.read(authProvider.notifier).login(email, password);
          if (loggedIn) {
            renterId = ref.read(authProvider).profile?.id;
          } else {
            // STOP — don't silently continue as guest. User explicitly asked for account.
            final msg = ref.read(authProvider).errorMessage ??
                'Could not create account. If you already have an account, use login with your old password.';
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  backgroundColor: Colors.redAccent,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Auto-signup/login error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign-up failed: $e'), backgroundColor: Colors.redAccent),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _isRegistering = false);
      }
    }

    final fee = widget.property.inspectionFee;
    // Paid inspections require an account: guests would pay with no wallet to credit.
    if (fee > 0 && !ref.read(authProvider).isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please create a free account or log in before paying, so your deposit and PIN are saved to you.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    if (fee > 0) {
      _promptPaymentAndFinalize(renterId: renterId, fee: fee);
    } else {
      _finalizeBooking(renterId: renterId);
    }
  }

  void _promptPaymentAndFinalize({required String? renterId, required double fee}) {
    final walletState = ref.read(walletProvider);
    final walletBalance = walletState.wallet.balance;
    final hasEnoughBalance = walletBalance >= fee;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.payment, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pay Inspection Deposit',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Deposit of ₦${fee.toStringAsFixed(0)} required to receive 4-digit tour PIN',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.property.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Inspection Deposit (Protected)',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₦${NumberFormat('#,##0').format(fee)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Option 1: Paystack (Card / USSD / Bank Transfer)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _payViaPaystack(renterId: renterId, fee: fee);
                  },
                  icon: const Icon(Icons.credit_card, color: Colors.white, size: 20),
                  label: const Text(
                    'Pay with Card / Bank Transfer (Paystack)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0BA4DB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Option 2: Wallet Balance (Only if user has funded and has sufficient real balance)
              if (hasEnoughBalance) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _payViaWallet(renterId: renterId, fee: fee);
                    },
                    icon: const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 20),
                    label: Text(
                      'Pay from Wallet Balance (₦${NumberFormat('#,##0').format(walletBalance)} available)',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ] else if (walletBalance > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Wallet Balance: ₦${NumberFormat('#,##0.00').format(walletBalance)} (Insufficient for this tour)',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '🔒 100% Refundable if the agent fails to show up.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _payViaPaystack({required String? renterId, required double fee}) async {
    // Free inspections skip payment entirely.
    if (fee <= 0) {
      _finalizeBooking(renterId: renterId);
      return;
    }
    setState(() => _isProcessingPayment = true);
    try {
      final paystack = ref.read(paystackServiceProvider);
      final email = _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : (ref.read(authProvider).profile?.email ?? '');
      if (email.isEmpty || !email.contains('@')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid email for payment receipt.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
      final refCode = paystack.generateReference(prefix: 'INSP_DEP');

      await paystack.launchPaystackCheckout(
        email: email,
        amountInNaira: fee,
        reference: refCode,
        userId: renterId ?? ref.read(authProvider).profile?.id,
        onSuccess: (verifiedRef) async {
          // Only reached after server verification (see PaystackService).
          final funded = await ref.read(walletProvider.notifier).fundWallet(
            amount: fee,
            method: 'Paystack Card / Transfer',
            reference: verifiedRef,
          );
          if (!funded) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ref.read(walletProvider).errorMessage ?? 'Deposit not verified. No charge made.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
            return;
          }
          final held = await ref.read(walletProvider.notifier).payInspectionDeposit(
            propertyTitle: widget.property.title,
            amount: fee,
          );
          if (!held && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment verified but deposit hold failed. Contact support with your reference.'),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }
          if (mounted) _finalizeBooking(renterId: renterId);
        },
        onCancel: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment cancelled. Your booking is not confirmed yet — retry when ready.'),
              ),
            );
          }
        },
        onError: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
            );
          }
        },
      );
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _payViaWallet({required String? renterId, required double fee}) async {
    final success = await ref.read(walletProvider.notifier).payInspectionDeposit(
      propertyTitle: widget.property.title,
      amount: fee,
    );
    if (success) {
      _finalizeBooking(renterId: renterId);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient wallet balance. Please pay with Paystack.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _finalizeBooking({required String? renterId}) async {
    final booking = ref.read(marketplaceProvider.notifier).bookInspection(
      propertyId: widget.property.id,
      renterId: renterId,
      renterName: _nameController.text.trim(),
      renterPhone: _phoneController.text.trim(),
      renterEmail: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      date: _selectedDate,
      time: _selectedTime,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      feeAmount: widget.property.inspectionFee,
    );

    if (mounted) {
      setState(() {
        _isSubmitted = true;
        _createdBooking = booking;
      });
    }

    // Persist server-side so escrow verify / payout / cross-device work.
    // Local-only fallback keeps the PIN visible if DB/RLS isn't ready.
    try {
      final uuidRe = RegExp(r'^[0-9a-fA-F-]{36}$');
      final row = <String, dynamic>{
        'marketplace_property_id': widget.property.id,
        if (uuidRe.hasMatch(widget.property.id)) 'property_id': widget.property.id,
        if (renterId != null && uuidRe.hasMatch(renterId)) 'renter_id': renterId,
        'renter_name': booking.renterName,
        'renter_phone': booking.renterPhone,
        if (booking.renterEmail != null) 'renter_email': booking.renterEmail,
        'scheduled_date': booking.scheduledDate.toIso8601String().split('T').first,
        'scheduled_time': booking.scheduledTime,
        'fee_amount': booking.feeAmount,
        'agent_payout_amount': booking.agentPayoutAmount,
        'platform_fee_amount': booking.platformFeeAmount,
        'completion_pin': booking.completionPin,
        'status': booking.status.value,
        if (booking.notes != null) 'notes': booking.notes,
      };
      final saved = await ref.read(supabaseServiceProvider).insert('inspection_bookings', row);
      final serverId = saved['id'] as String?;
      if (serverId != null && mounted) {
        ref.read(marketplaceProvider.notifier).replaceBookingId(booking.id, serverId);
        setState(() => _createdBooking = booking.copyWith(id: serverId));
      }
    } catch (e) {
      debugPrint('Booking DB persist failed (local-only): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _isSubmitted ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    final isRent = widget.property.isRent;
    final fee = widget.property.inspectionFee;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Book Verified Site Inspection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      isRent ? 'Renting Apartment' : 'Property Purchase',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Property summary snippet
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.property.images.isNotEmpty
                        ? widget.property.images.first
                        : 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=400&q=80',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.home, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.property.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.property.locationDisplay,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.property.displayPrice,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Deposit protection banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_rounded, color: Color(0xFF2563EB), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Protected Inspection Deposit: ₦${fee.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Your inspection deposit is protected. Pay to receive your secret 4-Digit PIN. The agent only receives payout after you meet on-site and provide this PIN.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E40AF),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Form fields
          const Text('Your Full Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'e.g. Ibrahim Abubakar',
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 14),

          const Text('WhatsApp / Phone Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'e.g. 08012345678',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter phone number';
              final digits = v.replaceAll(RegExp(r'[\s\-()]'), '');
              final ngRegex = RegExp(r'^(\+234[789][01]\d{8}|0[789][01]\d{8})$');
              if (!ngRegex.hasMatch(digits)) return 'e.g. 08012345678';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Email Address
          const Text('Email Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'e.g. ibrahim@gmail.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) {
              final isAuth = ref.read(authProvider).isAuthenticated;
              if (_createAccount && !isAuth) {
                if (v == null || v.trim().isEmpty || !v.contains('@')) {
                  return 'Please enter a valid email to secure your account';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Unauthenticated Account Creation Card
          if (!ref.watch(authProvider).isAuthenticated) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _createAccount,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _createAccount = val ?? true),
                      ),
                      const Expanded(
                        child: Text(
                          'Save booking & 4-digit PIN in a free Renter account',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  if (_createAccount) ...[
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Set a password so you can log in to view your secret PIN and booking status anytime:',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Create account password (min 8 chars)',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      ),
                      validator: (v) {
                        if (_createAccount && !ref.read(authProvider).isAuthenticated) {
                          if (v == null || v.length < 8) return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Date & Time Picker
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Inspection Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final tomorrow = DateTime.now().add(const Duration(days: 1));
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate.isBefore(tomorrow) ? tomorrow : _selectedDate,
                          firstDate: tomorrow,
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd MMM yyyy').format(_selectedDate),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Preferred Time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTime,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      ),
                      items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTime = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Optional notes for agent
          const Text('Notes for Agent (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. Gate code, coming with family, need parking...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              onPressed: (_isRegistering || _isProcessingPayment) ? null : _handleBooking,
              child: (_isRegistering || _isProcessingPayment)
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Proceed to Payment (₦${fee.toStringAsFixed(0)})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              '100% Refundable if the agent fails to show up.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final booking = _createdBooking!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
        ),
        const SizedBox(height: 18),
        const Text(
          'Inspection Booking Confirmed!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'We have reserved your appointment on ${DateFormat('EEE, dd MMMM').format(booking.scheduledDate)} at ${booking.scheduledTime}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
        const SizedBox(height: 22),

        // Secret PIN Card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'YOUR 4-DIGIT COMPLETION PIN',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6)),
                ),
                child: Text(
                  booking.completionPin,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Colors.amberAccent,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '🛡️ DO NOT give this PIN to anyone until you meet the agent physically at the property and complete the inspection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (booking.renterId != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, color: Colors.blue.shade700, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Saved to your account. You can log in anytime to view your PIN.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  // ignore: avoid_print
                  Clipboard.setData(ClipboardData(text: booking.completionPin));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN copied. Keep it private until on-site.')),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  MyInspectionsModal.show(context);
                },
                child: const Text('My Inspections', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
