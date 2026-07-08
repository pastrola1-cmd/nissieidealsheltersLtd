import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/document_provider.dart';
import 'package:nissie_ideal_shelters/providers/lead_provider.dart';
import 'package:nissie_ideal_shelters/providers/property_provider.dart';

class DocumentListScreen extends ConsumerStatefulWidget {
  const DocumentListScreen({super.key});

  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DocumentType? _selectedTypeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final docState = ref.watch(documentProvider);
    final leadState = ref.watch(leadProvider);
    final propertyState = ref.watch(propertyProvider);

    // Filter documents locally
    final filteredDocs = docState.documents.where((doc) {
      // 1. Search Query Filter (on document title, buyer name, or property title)
      final matchQuery = _searchQuery.isEmpty || () {
        final titleMatch = doc.title.toLowerCase().contains(_searchQuery.toLowerCase());
        
        final lead = leadState.leads.cast<Lead?>().firstWhere((l) => l?.id == doc.leadId, orElse: () => null);
        final buyerMatch = lead != null && lead.buyerName.toLowerCase().contains(_searchQuery.toLowerCase());

        final property = lead != null 
            ? propertyState.properties.cast<Property?>().firstWhere((p) => p?.id == lead.propertyId, orElse: () => null)
            : null;
        final propertyMatch = property != null && property.title.toLowerCase().contains(_searchQuery.toLowerCase());

        return titleMatch || buyerMatch || propertyMatch;
      }();

      // 2. Document Type Filter
      final matchType = _selectedTypeFilter == null || doc.type == _selectedTypeFilter;

      return matchQuery && matchType;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Document Registry', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: docState.isLoading && docState.documents.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: () => ref.read(documentProvider.notifier).loadDocuments(),
              child: Column(
                children: [
                  // Search & Filter Panel
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    color: AppColors.surface,
                    child: Column(
                      children: [
                        // Search Bar
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search title, client or property...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        
                        // Filters Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('All Types'),
                                selected: _selectedTypeFilter == null,
                                onSelected: (sel) {
                                  if (sel) setState(() => _selectedTypeFilter = null);
                                },
                                selectedColor: AppColors.accent,
                                labelStyle: TextStyle(
                                  color: _selectedTypeFilter == null ? Colors.white : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ...DocumentType.values.map((type) {
                                final isSelected = _selectedTypeFilter == type;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: Text(type.label),
                                    selected: isSelected,
                                    onSelected: (sel) {
                                      if (sel) setState(() => _selectedTypeFilter = type);
                                    },
                                    selectedColor: AppColors.accent,
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Documents List Viewport
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? _buildEmptyState(theme)
                        : ListView.separated(
                            padding: const EdgeInsets.all(24),
                            itemCount: filteredDocs.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final lead = leadState.leads.cast<Lead?>().firstWhere((l) => l?.id == doc.leadId, orElse: () => null);
                              final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(doc.createdAt);

                              return Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.01),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.description_rounded, color: AppColors.accent),
                                  ),
                                  title: Text(
                                    doc.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        'Client: ${lead?.buyerName ?? "N/A"}',
                                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dateStr,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    onSelected: (action) {
                                      if (action == 'preview') {
                                        context.push('/admin/documents/preview?url=${Uri.encodeComponent(doc.fileUrl)}&title=${Uri.encodeComponent(doc.title)}');
                                      } else if (action == 'share') {
                                        SharePlus.instance.share(
                                          ShareParams(
                                            text: 'Here is the ${doc.type.label} for the transaction: ${doc.fileUrl}',
                                            subject: doc.title,
                                          ),
                                        );
                                      } else if (action == 'delete') {
                                        _showDeleteConfirmation(context, doc.id);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'preview',
                                        child: Row(
                                          children: [
                                            Icon(Icons.visibility_outlined, size: 18),
                                            SizedBox(width: 8),
                                            Text('Preview PDF'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'share',
                                        child: Row(
                                          children: [
                                            Icon(Icons.share_outlined, size: 18),
                                            SizedBox(width: 8),
                                            Text('Share Link'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                                            SizedBox(width: 8),
                                            Text('Delete Record', style: TextStyle(color: AppColors.error)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    context.push('/admin/documents/preview?url=${Uri.encodeComponent(doc.fileUrl)}&title=${Uri.encodeComponent(doc.title)}');
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.description_outlined, color: AppColors.textTertiary, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'No Documents Found',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try refining your filters or search query above, or generate a new document directly from a Lead detail card.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, String documentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Document?'),
        content: const Text('Are you sure you want to permanently delete this document record from the deal history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(documentProvider.notifier).deleteDocument(documentId);
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document successfully deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
