import 'package:flutter_test/flutter_test.dart';
import 'package:nissie_ideal_shelters/models/payment_plan.dart';
import 'package:nissie_ideal_shelters/services/pdf_receipt_service.dart';

void main() {
  group('Payment Plan & Milestone Calculations', () {
    test('PaymentPlan computes totalPaid and progressPercent correctly', () {
      final now = DateTime.now();
      final plan = PaymentPlan(
        id: 'plan-1',
        companyId: 'comp-1',
        buyerName: 'Alhaji Musa Ibrahim',
        buyerPhone: '08012345678',
        propertyName: 'Graceland Estate',
        totalAmount: 15000000.0,
        initialDeposit: 3000000.0,
        balanceAmount: 6000000.0,
        durationMonths: 6,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(plan.totalPaid, 9000000.0);
      expect(plan.progressPercent, 0.6); // 9M / 15M = 60%
      expect(plan.isCompleted, false);
    });

    test('PaymentMilestone detects overdue and paid statuses correctly', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 10));
      final futureDate = DateTime.now().add(const Duration(days: 20));

      final overdueMilestone = PaymentMilestone(
        id: 'm-1',
        paymentPlanId: 'plan-1',
        companyId: 'comp-1',
        milestoneNumber: 1,
        dueDate: pastDate,
        expectedAmount: 2000000.0,
        paidAmount: 0.0,
        status: 'pending',
        createdAt: pastDate,
      );

      expect(overdueMilestone.isOverdue, true);
      expect(overdueMilestone.isPaid, false);

      final paidMilestone = PaymentMilestone(
        id: 'm-2',
        paymentPlanId: 'plan-1',
        companyId: 'comp-1',
        milestoneNumber: 2,
        dueDate: futureDate,
        expectedAmount: 2000000.0,
        paidAmount: 2000000.0,
        status: 'paid',
        createdAt: pastDate,
      );

      expect(paidMilestone.isPaid, true);
      expect(paidMilestone.isOverdue, false);
    });

    test('PdfReceiptService numberToWords converts Naira accurately', () {
      expect(
        PdfReceiptService.numberToWords(1500000),
        'One Million Five Hundred Thousand Naira Only',
      );
      expect(
        PdfReceiptService.numberToWords(25000000),
        'Twenty Five Million Naira Only',
      );
    });
  });
}
