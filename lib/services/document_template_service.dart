import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/models/models.dart';

class DocumentTemplateService {
  /// Fetches company logo from network and compiles it into a pw.MemoryImage
  static Future<pw.MemoryImage?> _loadLogo(String? logoUrl) async {
    if (logoUrl == null || logoUrl.isEmpty) return null;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final request = await client.getUrl(Uri.parse(logoUrl));
      final response = await request.close();
      if (response.statusCode == 200) {
        final List<int> bytesList = [];
        await for (final chunk in response) {
          bytesList.addAll(chunk);
        }
        return pw.MemoryImage(Uint8List.fromList(bytesList));
      }
    } catch (e) {
      debugPrint('SDE: Failed to download company logo: $e');
    }
    return null;
  }

  /// Generates a PDF Document containing the Offer Letter
  static Future<Uint8List> generateOfferLetter({
    required Company company,
    required Lead lead,
    required Property property,
    required Profile creator,
    required double negotiatedPrice,
    required double expectedPayout,
    required DateTime issueDate,
    String? notes,
    Profile? partner,
  }) async {
    final pdf = pw.Document(
      title: 'Offer Letter - ${lead.buyerName}',
      author: company.name,
    );

    // Fetch the logo bytes if available
    final logoImage = await _loadLogo(company.logoUrl);

    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: 'NGN ', decimalDigits: 0);
    final dateFormat = DateFormat('MMMM dd, yyyy');
    
    // Theme Colors
    final primaryColor = PdfColor.fromInt(0xFF1A1A2E); // Sleek Dark Blue
    final accentColor = PdfColor.fromInt(0xFF10B981);  // Emerald Green
    final lightGrey = PdfColor.fromInt(0xFFF3F4F6);
    final borderGrey = PdfColor.fromInt(0xFFE5E7EB);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ─── HEADER SECTION ───
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Logo or Text Branding
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 80,
                          height: 80,
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: pw.BoxDecoration(
                            color: primaryColor,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(
                            company.name.substring(0, 2).toUpperCase(),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        company.name,
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  
                  // Agency Contact Details
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'OFFICIAL OFFER LETTER',
                        style: pw.TextStyle(
                          color: accentColor,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      if (company.address != null)
                        pw.Text(
                          company.address!,
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                      if (company.phone != null)
                        pw.Text(
                          'Tel: ${company.phone}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                      if (company.email != null)
                        pw.Text(
                          'Email: ${company.email}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 20),
              pw.Divider(color: borderGrey, thickness: 1),
              pw.SizedBox(height: 15),

              // ─── DOCUMENT REFERENCE & DATES ───
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DATE OF ISSUE:',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        dateFormat.format(issueDate),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TRANSACTION ID:',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        lead.id.split('-').first.toUpperCase(),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // ─── RECIPIENT DETAILS ───
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderGrey),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PREPARED FOR:',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      lead.buyerName,
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    ),
                    if (lead.buyerEmail != null && lead.buyerEmail!.isNotEmpty)
                      pw.Text(
                        'Email: ${lead.buyerEmail}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                      ),
                    pw.Text(
                      'Tel: ${lead.buyerPhone}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 25),

              // ─── LETTER BODY ───
              pw.Text(
                'Dear ${lead.buyerName.split(' ').first},',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'We are pleased to present this official offer, on behalf of ${company.name}, for the acquisition of the real estate asset described below. Following negotiations and reviews, the transaction details have been summarized as follows:',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.black, lineSpacing: 1.5),
              ),

              pw.SizedBox(height: 20),

              // ─── PROPERTY TABLE ───
              pw.Table(
                border: pw.TableBorder.all(color: borderGrey, width: 1),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(4),
                },
                children: [
                  _buildTableRow('Property Title', property.title, primaryColor, lightGrey, true),
                  _buildTableRow('Location', property.location ?? 'Not Specified', primaryColor, PdfColors.white, false),
                  _buildTableRow('Agreed Price', currencyFormat.format(negotiatedPrice), primaryColor, lightGrey, false),
                  if (partner != null)
                    _buildTableRow('Attributed Agent', partner.fullName ?? 'Direct Lead', primaryColor, PdfColors.white, false),
                ],
              ),

              pw.SizedBox(height: 25),

              // ─── TERMS AND CONDITIONS ───
              pw.Text(
                'TERMS OF AGREEMENT:',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 8),
              _buildBulletPoint('Validity: This offer remains legally binding and valid for 14 calendar days from the date of issue.'),
              _buildBulletPoint('Contracting: Upon confirmation of deposit terms, the formal Deed of Assignment / Tenancy Agreement will be prepared for execution.'),
              _buildBulletPoint('Fees & Levies: The price stated above is exclusive of statutory registration fees, survey plans, and agency service charges unless explicitly stated.'),

              if (notes != null && notes.trim().isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'SPECIAL CONDITIONS / REMARKS:',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: borderGrey),
                    borderRadius: pw.BorderRadius.circular(6),
                    color: PdfColors.white,
                  ),
                  child: pw.Text(
                    notes,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900, lineSpacing: 1.3),
                  ),
                ),
              ],

              pw.Spacer(),

              // ─── SIGNATURES ───
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PREPARED BY:',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Container(width: 150, height: 1, color: PdfColors.grey400),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        creator.fullName ?? 'Agency Representative',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                      pw.Text(
                        creator.role.label,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'AUTHORIZED SIGNATURE / STAMP:',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Container(width: 150, height: 1, color: PdfColors.grey400),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        company.name,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 30),
              pw.Divider(color: borderGrey, thickness: 0.5),
              pw.SizedBox(height: 6),
              
              // ─── FOOTER ───
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated via ScalewealthEstate Document Engine (SDE)',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                  ),
                  pw.Text(
                    'Page 1 of 1',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.TableRow _buildTableRow(String label, String value, PdfColor textColor, PdfColor bgColor, bool isHeader) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bgColor),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9, 
              fontWeight: pw.FontWeight.bold,
              color: isHeader ? textColor : PdfColors.grey800
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9, 
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHeader ? textColor : PdfColors.black
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildBulletPoint(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: const pw.TextStyle(fontSize: 10)),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900, lineSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
