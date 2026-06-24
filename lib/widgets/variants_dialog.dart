import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/services/supabase_service.dart';

class LandingPageVariantsDialog extends ConsumerStatefulWidget {
  final Property property;
  final Map<String, dynamic> landingPage;

  const LandingPageVariantsDialog({
    super.key,
    required this.property,
    required this.landingPage,
  });

  @override
  ConsumerState<LandingPageVariantsDialog> createState() => _LandingPageVariantsDialogState();
}

class _LandingPageVariantsDialogState extends ConsumerState<LandingPageVariantsDialog> {
  List<LandingPageVariant> _variants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final response = await service.client
          .from('landing_page_variants')
          .select()
          .eq('landing_page_id', widget.landingPage['id'])
          .order('variant_code', ascending: true);

      final list = List<Map<String, dynamic>>.from(response);
      setState(() {
        _variants = list.map((json) => LandingPageVariant.fromJson(json)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load variants: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteVariant(LandingPageVariant variant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Variant?'),
        content: Text('Are you sure you want to delete Variant ${variant.variantCode}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final service = ref.read(supabaseServiceProvider);
      await service.delete('landing_page_variants', variant.id);
      _loadVariants();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete variant: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleActive(LandingPageVariant variant) async {
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.update('landing_page_variants', variant.id, {
        'is_active': !variant.isActive,
      });
      _loadVariants();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update variant: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showVariantForm([LandingPageVariant? variant]) {
    showDialog(
      context: context,
      builder: (context) => _VariantFormDialog(
        landingPageId: widget.landingPage['id'],
        companyId: widget.property.companyId,
        variant: variant,
        existingVariants: _variants,
        onSave: () {
          Navigator.of(context).pop();
          _loadVariants();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'A/B Split Test Variants',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Property: ${widget.property.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _variants.length >= 3 ? null : () => _showVariantForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Variant'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _variants.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          itemCount: _variants.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final variant = _variants[index];
                            return _buildVariantCard(variant);
                          },
                        ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.call_split_rounded, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          const Text(
            'No A/B Testing Variants Configured',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create variants with different headlines or CTAs to split traffic and measure conversion rates.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantCard(LandingPageVariant variant) {
    final double convRate = variant.viewsCount > 0 ? (variant.leadsCount / variant.viewsCount * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: variant.isActive ? AppColors.primary.withOpacity(0.15) : AppColors.border,
          width: variant.isActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: variant.isActive ? AppColors.primary : AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'VARIANT ${variant.variantCode}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  variant.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: variant.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
              Switch.adaptive(
                value: variant.isActive,
                activeColor: AppColors.accent,
                onChanged: (val) => _toggleActive(variant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetric(Icons.visibility_outlined, 'Views', variant.viewsCount.toString()),
              const SizedBox(width: 24),
              _buildMetric(Icons.person_outline_rounded, 'Leads', variant.leadsCount.toString()),
              const SizedBox(width: 24),
              _buildMetric(
                Icons.trending_up_rounded,
                'Conversion',
                '${convRate.toStringAsFixed(1)}%',
                color: convRate > 0 ? AppColors.successDark : AppColors.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                onPressed: () => _showVariantForm(variant),
                tooltip: 'Edit Variant',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                onPressed: () => _deleteVariant(variant),
                tooltip: 'Delete Variant',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VariantFormDialog extends ConsumerStatefulWidget {
  final String landingPageId;
  final String companyId;
  final LandingPageVariant? variant;
  final List<LandingPageVariant> existingVariants;
  final VoidCallback onSave;

  const _VariantFormDialog({
    required this.landingPageId,
    required this.companyId,
    this.variant,
    required this.existingVariants,
    required this.onSave,
  });

  @override
  ConsumerState<_VariantFormDialog> createState() => _VariantFormDialogState();
}

class _VariantFormDialogState extends ConsumerState<_VariantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _headlineController = TextEditingController();
  final _ctaPrimaryController = TextEditingController();
  final _ctaSecondaryController = TextEditingController();

  String _variantCode = 'A';
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.variant != null) {
      _headlineController.text = widget.variant!.headline;
      _ctaPrimaryController.text = widget.variant!.ctaPrimary;
      _ctaSecondaryController.text = widget.variant!.ctaSecondary;
      _variantCode = widget.variant!.variantCode;
      _isActive = widget.variant!.isActive;
    } else {
      _ctaPrimaryController.text = 'Book Free Site Inspection';
      _ctaSecondaryController.text = 'Get Price List';
      
      // Auto-pick first available code
      final codes = ['A', 'B', 'C'];
      for (final code in codes) {
        if (!widget.existingVariants.any((v) => v.variantCode == code)) {
          _variantCode = code;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _headlineController.dispose();
    _ctaPrimaryController.dispose();
    _ctaSecondaryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final service = ref.read(supabaseServiceProvider);

      final Map<String, dynamic> data = {
        'landing_page_id': widget.landingPageId,
        'company_id': widget.companyId,
        'variant_code': _variantCode,
        'headline': _headlineController.text.trim(),
        'cta_primary': _ctaPrimaryController.text.trim(),
        'cta_secondary': _ctaSecondaryController.text.trim(),
        'is_active': _isActive,
      };

      if (widget.variant != null) {
        await service.update('landing_page_variants', widget.variant!.id, data);
      } else {
        await service.insert('landing_page_variants', data);
      }
      widget.onSave();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save variant: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unusedCodes = ['A', 'B', 'C'].where((code) {
      if (widget.variant?.variantCode == code) return true;
      return !widget.existingVariants.any((v) => v.variantCode == code);
    }).toList();

    return AlertDialog(
      title: Text(widget.variant != null ? 'Edit Variant' : 'Add Variant'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _variantCode,
                decoration: const InputDecoration(labelText: 'Variant Code'),
                items: unusedCodes.map((code) {
                  return DropdownMenuItem(value: code, child: Text('Variant $code'));
                }).toList(),
                onChanged: widget.variant != null
                    ? null // Cannot change code on edit
                    : (val) {
                        if (val != null) setState(() => _variantCode = val);
                      },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _headlineController,
                decoration: const InputDecoration(
                  labelText: 'Headline',
                  hintText: 'e.g. Luxury 4 Bedroom Terrace in Lekki',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Headline is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ctaPrimaryController,
                decoration: const InputDecoration(labelText: 'Primary CTA Text'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Primary CTA is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ctaSecondaryController,
                decoration: const InputDecoration(labelText: 'Secondary CTA Text'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Secondary CTA is required' : null,
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
