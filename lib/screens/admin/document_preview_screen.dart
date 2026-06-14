import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:ppn/core/constants/app_colors.dart';

class DocumentPreviewScreen extends StatelessWidget {
  final String fileUrl;
  final String title;

  const DocumentPreviewScreen({
    super.key,
    required this.fileUrl,
    required this.title,
  });

  Future<Uint8List> _fetchPdfBytes() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(fileUrl));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final List<int> bytesList = [];
        await for (final chunk in response) {
          bytesList.addAll(chunk);
        }
        return Uint8List.fromList(bytesList);
      } else {
        throw Exception('Failed to load PDF: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to download PDF from storage: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PdfPreview(
              build: (format) => _fetchPdfBytes(),
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              loadingWidget: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.accent),
                    SizedBox(height: 12),
                    Text('Downloading document from cloud...', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              onError: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading document',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              },
              pdfPreviewPageDecoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
