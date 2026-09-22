import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/config/supabase_config.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/inspection_booking.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/marketplace_provider.dart';
import 'package:nissie_ideal_shelters/providers/wallet_provider.dart';
import 'package:nissie_ideal_shelters/screens/wallet/agent_withdrawal_modal.dart';

class AgentPinVerificationModal extends ConsumerStatefulWidget {
  const AgentPinVerificationModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AgentPinVerificationModal(),
    );
  }

  @override
  ConsumerState<AgentPinVerificationModal> createState() => _AgentPinVerificationModalState();
}

class _AgentPinVerificationModalState extends ConsumerState<AgentPinVerificationModal> {
  final _pinController = TextEditingController();
  bool _isVerifying = false;
  bool _isSuccess = false;
  InspectionBooking? _verifiedBooking;
  String? _errorMessage;
  int _attempts = 0;
  DateTime? _lockedUntil;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _errorMessage = 'Please enter a valid 4-digit PIN');
      return;
    }
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      setState(() => _errorMessage = 'Too many attempts. Try again in 1 minute.');
      return;
    }
    // Only staff roles may claim payouts — buyers must not self-pay.
    final role = ref.read(authProvider).profile?.role;
    final isStaff = role == UserRole.partner ||
        role == UserRole.admin ||
        role == UserRole.manager ||
        role == UserRole.marketer ||
        role == UserRole.platformAdmin;
    if (!isStaff) {
      setState(() => _errorMessage = 'Agent sign-in required. Buyers cannot verify their own PIN.');
      return;
    }
    final agentId = ref.read(authProvider).profile?.id;
    if (agentId == null) {
      setState(() => _errorMessage = 'Please sign in as an agent to claim payout.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final marketplace = ref.read(marketplaceProvider);
    // 1) Server lookup first — works cross-device (renter booked on their phone).
    InspectionBooking? matchedBooking;
    String? displayPropertyTitle;
    try {
      final res = await SupabaseConfig.client
          .rpc('lookup_booking_by_pin', params: {'p_pin': pin});
      if (res != null && res is Map && res['success'] == true) {
        final m = Map<String, dynamic>.from(res);
        final propId = (m['marketplace_property_id'] as String?) ??
            (m['property_id']?.toString() ?? '');
        displayPropertyTitle = m['property_title'] as String?;
        matchedBooking = InspectionBooking(
          id: m['booking_id'].toString(),
          propertyId: propId,
          renterName: (m['renter_name'] as String?) ?? 'Client',
          renterPhone: '',
          scheduledDate: m['scheduled_date'] != null
              ? DateTime.tryParse(m['scheduled_date'].toString()) ?? DateTime.now()
              : DateTime.now(),
          scheduledTime: (m['scheduled_time'] as String?) ?? '',
          feeAmount: (m['fee_amount'] as num?)?.toDouble() ?? 3000.0,
          agentPayoutAmount: (m['agent_payout_amount'] as num?)?.toDouble() ?? 2000.0,
          platformFeeAmount: (m['platform_fee_amount'] as num?)?.toDouble() ?? 1000.0,
          completionPin: pin,
          status: InspectionEscrowStatus.paidEscrow,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    } catch (_) {
      // RPC missing (migration not run) — fall through to local scan.
    }

    // 2) Local fallback — same-device bookings stored in memory.
    matchedBooking ??= _findLocalBooking(marketplace, pin);

    if (matchedBooking == null) {
      _attempts++;
      if (_attempts >= 5) {
        _lockedUntil = DateTime.now().add(const Duration(minutes: 1));
        _attempts = 0;
      }
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Invalid or already-settled PIN. Confirm the code from the renter.';
      });
      return;
    }

    // Free inspections carry no payout.
    if (matchedBooking.feeAmount <= 0) {
      setState(() {
        _isVerifying = false;
        _isSuccess = true;
        _verifiedBooking = matchedBooking;
      });
      return;
    }

    final property = marketplace.allProperties.where(
      (p) => p.id == matchedBooking!.propertyId,
    ).firstOrNull ??
        (displayPropertyTitle != null
            ? marketplace.allProperties.where(
                (p) => p.title == displayPropertyTitle,
              ).firstOrNull ??
                marketplace.allProperties.first
            : marketplace.allProperties.first);

    final ok = await ref.read(walletProvider.notifier).releaseInspectionPayout(
          bookingId: matchedBooking.id,
          pin: pin,
          agentId: agentId,
          propertyTitle: property.title,
          agentPayout: matchedBooking.agentPayoutAmount,
          platformFee: matchedBooking.platformFeeAmount,
        );

    if (!ok) {
      setState(() {
        _isVerifying = false;
        _errorMessage = ref.read(walletProvider).errorMessage ??
            'Verification failed server-side. No payout released.';
      });
      return;
    }

    setState(() {
      _isVerifying = false;
      _isSuccess = true;
      _verifiedBooking = matchedBooking;
    });
  }

  /// Same-device fallback when server lookup is unavailable.
  InspectionBooking? _findLocalBooking(MarketplaceState marketplace, String pin) {
    for (final b in marketplace.myBookings) {
      if (b.completionPin == pin &&
          b.status != InspectionEscrowStatus.completed &&
          b.status != InspectionEscrowStatus.cancelled) {
        return b;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _isSuccess ? _buildSuccessView() : _buildInputView(),
        ),
      ),
    );
  }

  Widget _buildInputView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Drag handle
        Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.pin_outlined, color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 14),

        const Text(
          'Agent On-Site Verification',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter the Renter\'s 4-digit PIN to complete the tour and receive ₦2,000 instantly in your wallet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
        ),
        const SizedBox(height: 24),

        // PIN Input Box
        SizedBox(
          width: 200,
          child: TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 14,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              hintStyle: const TextStyle(color: Colors.grey, letterSpacing: 14),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],

        const SizedBox(height: 24),

        // Verify button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isVerifying
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.verified, size: 18),
            label: Text(
              _isVerifying ? 'Verifying PIN & Crediting...' : 'Verify & Claim ₦2,000 Payout',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: _isVerifying ? null : _handleVerify,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Automated settlement. Funds arrive in your digital wallet immediately upon PIN match.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
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
        const SizedBox(height: 16),
        const Text(
          'PIN Verified & Tour Completed!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        Text(
          'Renter: ${_verifiedBooking?.renterName ?? 'Client'}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 20),

        // Payout Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '+₦2,000 Credited Instantly',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    Text(
                      'Your digital wallet has been funded. You can withdraw to your bank account anytime.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.account_balance, size: 16),
                label: const Text('Withdraw to Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  Navigator.of(context).pop();
                  AgentWithdrawalModal.show(context);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
