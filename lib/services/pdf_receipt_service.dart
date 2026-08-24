import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:nissie_ideal_shelters/models/models.dart';

class PdfReceiptService {
  static final _currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  /// Converts number to English words for Naira currency formatting.
  static String numberToWords(num number) {
    if (number == 0) return 'Zero Naira Only';
    final intPart = number.toInt();
    return '${_convertChunk(intPart).trim()} Naira Only';
  }

  static String _convertChunk(int n) {
    if (n == 0) return '';
    if (n < 20) {
      const units = [
        '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
        'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
        'Seventeen', 'Eighteen', 'Nineteen'
      ];
      return units[n];
    }
    if (n < 100) {
      const tens = [
        '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
      ];
      return '${tens[n ~/ 10]} ${_convertChunk(n % 10)}'.trim();
    }
    if (n < 1000) {
      return '${_convertChunk(n ~/ 100)} Hundred ${_convertChunk(n % 100)}'.trim();
    }
    if (n < 1000000) {
      return '${_convertChunk(n ~/ 1000)} Thousand ${_convertChunk(n % 1000)}'.trim();
    }
    if (n < 1000000000) {
      return '${_convertChunk(n ~/ 1000000)} Million ${_convertChunk(n % 1000000)}'.trim();
    }
    return '${_convertChunk(n ~/ 1000000000)} Billion ${_convertChunk(n % 1000000000)}'.trim();
  }

  /// Generates and previews/prints an official Branded Payment Receipt PDF.
  static Future<void> generateAndPrintReceipt({
    required Company company,
    required PaymentPlan plan,
    required PaymentMilestone milestone,
    String? receiptNumber,
  }) async {
    final doc = pw.Document();
    final recNum = receiptNumber ?? milestone.receiptNumber ?? 'NIS/REC/${DateTime.now().year}/${milestone.id.substring(0, 6).toUpperCase()}';
    final issueDate = milestone.paidAt ?? DateTime.now();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        company.name.toUpperCase(),
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E6BE6')),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        company.address ?? 'Suite 2, Shema complex, Asokoro extension, Abuja',
                        style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B')),
                      ),
                      pw.Text(
                        'Tel: ${company.phone ?? '+234 800 000 0000'} | Email: ${company.email ?? 'info@nissieidealshelters.com'}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B')),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#10B981'),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Text(
                      'OFFICIAL RECEIPT',
                      style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#1E6BE6')),
              pw.SizedBox(height: 16),

              // ── Receipt Metadata ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('RECEIPT NO:', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#94A3B8'), fontWeight: pw.FontWeight.bold)),
                      pw.Text(recNum, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('PAYMENT DATE:', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#94A3B8'), fontWeight: pw.FontWeight.bold)),
                      pw.Text(DateFormat('MMMM d, yyyy').format(issueDate), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // ── Received From Card ──
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('RECEIVED FROM:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B'))),
                    pw.SizedBox(height: 4),
                    pw.Text(plan.buyerName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                    pw.Text('Phone: ${plan.buyerPhone} ${plan.buyerEmail != null ? '| Email: ${plan.buyerEmail}' : ''}', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B'))),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // ── Property & Purpose Table ──
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('DESCRIPTION / PROPERTY', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('PLOT NO.', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('PAYMENT DETAILS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('AMOUNT (₦)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(plan.propertyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                            pw.Text('Subscription: ${plan.durationMonths} Months Installment Plan', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#64748B'))),
                          ],
                        ),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(plan.plotNumber ?? 'To be Allocated', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('Milestone #${milestone.milestoneNumber}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          _currencyFormat.format(milestone.paidAmount > 0 ? milestone.paidAmount : milestone.expectedAmount),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColor.fromHex('#10B981')),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // ── Amount in Words ──
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EFF6FF'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('AMOUNT IN WORDS: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E6BE6'))),
                    pw.Expanded(
                      child: pw.Text(
                        numberToWords(milestone.paidAmount > 0 ? milestone.paidAmount : milestone.expectedAmount),
                        style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // ── Financial Ledger Summary ──
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryColumn('TOTAL PROPERTY PRICE', _currencyFormat.format(plan.totalAmount)),
                    _buildSummaryColumn('TOTAL PAID TO DATE', _currencyFormat.format(plan.totalPaid), color: '#10B981'),
                    _buildSummaryColumn('OUTSTANDING BALANCE', _currencyFormat.format(plan.balanceAmount), color: plan.balanceAmount > 0 ? '#EF4444' : '#10B981'),
                  ],
                ),
              ),
              pw.Spacer(),

              // ── Signatures & QR Code ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 140,
                        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey500, width: 1))),
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Account / Finance Department', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'NISSIE-RECEIPT:$recNum|BUYER:${plan.buyerName}|AMT:${milestone.paidAmount}|DATE:${DateFormat('y-M-d').format(issueDate)}',
                        width: 50,
                        height: 50,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Scan to Verify', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  'Thank you for investing with Nissie Ideal Shelters Ltd. This receipt is an official acknowledgment of payment.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'receipt_${recNum.replaceAll('/', '_')}.pdf',
    );
  }

  static pw.Widget _buildSummaryColumn(String label, String value, {String color = '#0F172A'}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#64748B'), fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex(color))),
      ],
    );
  }

  /// Generates and previews/prints an official Provisional Allocation Letter PDF.
  static Future<void> generateAndPrintAllocationLetter({
    required Company company,
    required PaymentPlan plan,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(company.name.toUpperCase(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E6BE6'))),
                    pw.SizedBox(height: 2),
                    pw.Text(company.address ?? 'Suite 2, Shema complex, Asokoro extension, Abuja', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B'))),
                    pw.Text('Phone: ${company.phone ?? '+234 800 000 0000'} | Email: ${company.email ?? 'info@nissieidealshelters.com'}', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B'))),
                    pw.SizedBox(height: 8),
                    pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#1E6BE6')),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Letter Date & Ref
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Ref: NIS/ALLO/${DateTime.now().year}/${plan.id.substring(0, 6).toUpperCase()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('MMMM d, yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 16),

              // Recipient
              pw.Text('TO:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B'))),
              pw.Text(plan.buyerName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text('Phone: ${plan.buyerPhone}', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 20),

              // Title
              pw.Center(
                child: pw.Text(
                  'LETTER OF PROVISIONAL PLOT ALLOCATION',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
                ),
              ),
              pw.SizedBox(height: 16),

              // Body Paragraphs
              pw.Text(
                'Dear Esteemed Investor,',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'We are pleased to formally issue this Letter of Provisional Allocation for your property subscription at ${plan.propertyName}, following your commitment and subscription terms.',
                style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
              ),
              pw.SizedBox(height: 12),

              // Allocation Specifications Box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ALLOCATION SPECIFICATIONS:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E6BE6'))),
                    pw.SizedBox(height: 6),
                    pw.Row(children: [pw.Text('• Estate: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.Text(plan.propertyName, style: const pw.TextStyle(fontSize: 10))]),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [pw.Text('• Allocated Plot: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.Text(plan.plotNumber ?? 'Designated Plot Area', style: const pw.TextStyle(fontSize: 10))]),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [pw.Text('• Total Consideration: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.Text(_currencyFormat.format(plan.totalAmount), style: const pw.TextStyle(fontSize: 10))]),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [pw.Text('• Current Amount Paid: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.Text(_currencyFormat.format(plan.totalPaid), style: const pw.TextStyle(fontSize: 10))]),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              pw.Text(
                'TERMS & CONDITIONS:',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B')),
              ),
              pw.SizedBox(height: 4),
              pw.Text('1. This allocation remains provisional until all installment payments are completely satisfied.', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Text('2. Physical site pegging and possession will be scheduled upon completion of minimum threshold payments.', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Text('3. Final Deed of Assignment and Survey Plan will be prepared in the name specified on this document.', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(width: 140, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey500))), padding: const pw.EdgeInsets.only(top: 4)),
                      pw.Text('Managing Director / CEO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text(company.name, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'NISSIE-ALLOCATION:${plan.id}|BUYER:${plan.buyerName}|ESTATE:${plan.propertyName}',
                        width: 45,
                        height: 45,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Official Document Verification', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'allocation_${plan.buyerName.replaceAll(' ', '_')}.pdf',
    );
  }
}
