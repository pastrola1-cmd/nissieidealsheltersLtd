import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

class PaymentPlanState {
  final List<PaymentPlan> plans;
  final bool isLoading;
  final String? errorMessage;

  const PaymentPlanState({
    this.plans = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  PaymentPlanState copyWith({
    List<PaymentPlan>? plans,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PaymentPlanState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  int get totalActivePlans => plans.where((p) => p.status == 'active').length;

  double get totalCollectedToDate =>
      plans.fold(0.0, (sum, p) => sum + p.totalPaid);

  double get totalExpectedThisMonth {
    final now = DateTime.now();
    double sum = 0.0;
    for (final plan in plans) {
      for (final m in plan.milestones) {
        if (m.dueDate.year == now.year && m.dueDate.month == now.month) {
          sum += m.expectedAmount;
        }
      }
    }
    return sum;
  }

  double get totalOverdueReceivables {
    double sum = 0.0;
    for (final plan in plans) {
      for (final m in plan.milestones) {
        if (m.isOverdue) {
          sum += m.remainingAmount;
        }
      }
    }
    return sum;
  }
}

class PaymentPlanNotifier extends Notifier<PaymentPlanState> {
  late SupabaseService _supabaseService;

  @override
  PaymentPlanState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    final profile = ref.watch(authProvider).profile;
    if (profile != null && profile.companyId != null) {
      Future.microtask(() => loadPaymentPlans());
    }
    return const PaymentPlanState();
  }

  Future<void> loadPaymentPlans() async {
    final companyId = ref.read(authProvider).profile?.companyId;
    if (companyId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final plans = await _supabaseService.getPaymentPlans(companyId);
      state = state.copyWith(plans: plans, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createPlan({
    required String buyerName,
    required String buyerPhone,
    String? buyerEmail,
    String? propertyId,
    required String propertyName,
    String? plotNumber,
    required double totalAmount,
    required double initialDeposit,
    required int durationMonths,
    required DateTime startDate,
    String? notes,
  }) async {
    final profile = ref.read(authProvider).profile;
    if (profile == null || profile.companyId == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final balance = (totalAmount - initialDeposit).clamp(0.0, double.infinity);
      final monthlyAmount = durationMonths > 0 ? (balance / durationMonths) : balance;

      final planData = {
        'company_id': profile.companyId!,
        'buyer_name': buyerName,
        'buyer_phone': buyerPhone,
        'buyer_email': buyerEmail,
        'property_id': propertyId,
        'property_name': propertyName,
        'plot_number': plotNumber,
        'total_amount': totalAmount,
        'initial_deposit': initialDeposit,
        'balance_amount': balance,
        'duration_months': durationMonths,
        'start_date': startDate.toIso8601String().split('T').first,
        'status': balance <= 0 ? 'completed' : 'active',
        'notes': notes,
      };

      // Generate milestones data
      final milestonesData = <Map<String, dynamic>>[];
      for (int i = 1; i <= durationMonths; i++) {
        final dueDate = DateTime(startDate.year, startDate.month + i, startDate.day);
        milestonesData.add({
          'milestone_number': i,
          'due_date': dueDate.toIso8601String().split('T').first,
          'expected_amount': monthlyAmount,
          'paid_amount': 0.0,
          'status': 'pending',
        });
      }

      await _supabaseService.createPaymentPlan(
        planData: planData,
        milestonesData: milestonesData,
      );

      await loadPaymentPlans();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> logMilestonePayment({
    required String milestoneId,
    required double amount,
    String? receiptNumber,
    String? paymentMethod,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _supabaseService.logMilestonePayment(
        milestoneId: milestoneId,
        amount: amount,
        receiptNumber: receiptNumber,
        paymentMethod: paymentMethod,
        notes: notes,
      );
      await loadPaymentPlans();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final paymentPlanProvider =
    NotifierProvider<PaymentPlanNotifier, PaymentPlanState>(() {
  return PaymentPlanNotifier();
});
