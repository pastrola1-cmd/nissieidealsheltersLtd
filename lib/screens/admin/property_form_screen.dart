import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ppn/core/constants/app_colors.dart';
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/property_provider.dart';
import 'package:ppn/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PropertyFormScreen extends ConsumerStatefulWidget {
  final String? propertyId;

  const PropertyFormScreen({super.key, this.propertyId});

  @override
  ConsumerState<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends ConsumerState<PropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _commissionValueController = TextEditingController();

  PropertyStatus _status = PropertyStatus.available;
  CommissionType _commissionType = CommissionType.percentage;
  String? _assignedPartnerId;

  List<String> _existingImages = [];
  final List<XFile> _newImages = [];
  final List<Uint8List> _newImageBytes = [];

  List<Profile> _partners = [];
  bool _isLoadingPartners = false;
  bool _isLoadingProperty = false;
  bool _isSaving = false;

  Property? _property;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _videoUrlController.dispose();
    _commissionValueController.dispose();
    super.dispose();
  }

  bool get _isEditMode => widget.propertyId != null;

  Future<void> _loadInitialData() async {
    final companyId = ref.read(authProvider).profile?.companyId;
    if (companyId != null) {
      _fetchPartners(companyId);
    }

    if (_isEditMode) {
      setState(() => _isLoadingProperty = true);
      try {
        final properties = ref.read(propertyProvider).properties;
        final match = properties.where((p) => p.id == widget.propertyId).firstOrNull;
        if (match != null) {
          _property = match;
          _prefillFields(match);
        } else {
          final service = ref.read(supabaseServiceProvider);
          final fetched = await service.getProperty(widget.propertyId!);
          if (fetched != null) {
            _property = fetched;
            _prefillFields(fetched);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading property: $e'), backgroundColor: AppColors.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoadingProperty = false);
      }
    } else {
      // Default commission value for new property
      _commissionValueController.text = '5.0';
    }
  }

  void _prefillFields(Property p) {
    _titleController.text = p.title;
    _descriptionController.text = p.description ?? '';
    _locationController.text = p.location ?? '';
    _priceController.text = p.price.toStringAsFixed(0);
    _videoUrlController.text = p.videoUrl ?? '';
    _status = p.status;
    _commissionType = p.commissionType;
    _commissionValueController.text = p.commissionValue.toString();
    _assignedPartnerId = p.assignedPartnerId;
    _existingImages = List<String>.from(p.images);
  }

  Future<void> _fetchPartners(String companyId) async {
    setState(() => _isLoadingPartners = true);
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('profiles')
          .select()
          .eq('role', 'partner')
          .eq('company_id', companyId);
      
      final list = List<Map<String, dynamic>>.from(response);
      setState(() {
        _partners = list.map((json) => Profile.fromJson(json)).toList();
      });
    } catch (e) {
      debugPrint('Error fetching partners: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPartners = false);
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (images.isEmpty) return;

    for (final image in images) {
      final bytes = await image.readAsBytes();
      setState(() {
        _newImages.add(image);
        _newImageBytes.add(bytes);
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
      _newImageBytes.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final commissionValue = double.tryParse(_commissionValueController.text.trim()) ?? 0.0;

    setState(() => _isSaving = true);

    bool success;
    if (_isEditMode && _property != null) {
      success = await ref.read(propertyProvider.notifier).updateProperty(
            id: _property!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            location: _locationController.text.trim(),
            price: price,
            status: _status,
            existingImages: _existingImages,
            newImageBytesList: _newImageBytes,
            newImageNames: _newImages.map((img) => img.name).toList(),
            videoUrl: _videoUrlController.text.trim().isEmpty ? null : _videoUrlController.text.trim(),
            assignedPartnerId: _assignedPartnerId,
            commissionType: _commissionType,
            commissionValue: commissionValue,
          );
    } else {
      success = await ref.read(propertyProvider.notifier).createProperty(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            location: _locationController.text.trim(),
            price: price,
            status: _status,
            imageBytesList: _newImageBytes,
            imageNames: _newImages.map((img) => img.name).toList(),
            videoUrl: _videoUrlController.text.trim().isEmpty ? null : _videoUrlController.text.trim(),
            assignedPartnerId: _assignedPartnerId,
            commissionType: _commissionType,
            commissionValue: commissionValue,
          );
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Property updated successfully!' : 'Property added successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      } else {
        final error = ref.read(propertyProvider).errorMessage ?? 'Failed to save property';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoadingProperty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Property' : 'Add Property'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Main Card ──
              Card(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Property Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        keyboardType: TextInputType.text,
                        decoration: _inputDecoration(label: 'Property Title *', icon: Icons.title_rounded),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Property title is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Location
                      TextFormField(
                        controller: _locationController,
                        keyboardType: TextInputType.streetAddress,
                        decoration: _inputDecoration(label: 'Location / Address *', icon: Icons.location_on_outlined),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Location is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Price
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          label: 'Price (₦) *',
                          icon: Icons.monetization_on_outlined,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Price is required';
                          }
                          final parsed = double.tryParse(value);
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid positive price';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        keyboardType: TextInputType.multiline,
                        maxLines: 4,
                        decoration: _inputDecoration(label: 'Description', icon: Icons.description_outlined),
                      ),
                      const SizedBox(height: 16),

                      // Video URL (Optional)
                      TextFormField(
                        controller: _videoUrlController,
                        keyboardType: TextInputType.url,
                        decoration: _inputDecoration(label: 'Video Link (YouTube/Vimeo) (Optional)', icon: Icons.play_circle_outline),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Images Upload Card ──
              Card(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Property Images',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.accent, size: 18),
                            label: const Text('Add Images', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_existingImages.isEmpty && _newImages.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.photo_library_outlined, size: 40, color: AppColors.textTertiary),
                              SizedBox(height: 8),
                              Text('No images selected yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _existingImages.length + _newImages.length,
                            itemBuilder: (context, index) {
                              final isExisting = index < _existingImages.length;
                              final imageWidget = isExisting
                                  ? Image.network(_existingImages[index], fit: BoxFit.cover)
                                  : Image.memory(_newImageBytes[index - _existingImages.length], fit: BoxFit.cover);

                              return Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(9),
                                        child: imageWidget,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          if (isExisting) {
                                            _removeExistingImage(index);
                                          } else {
                                            _removeNewImage(index - _existingImages.length);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: AppColors.error,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Settings Card (Status & Assignment) ──
              Card(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status & Assignment',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Status Dropdown
                      DropdownButtonFormField<PropertyStatus>(
                        initialValue: _status,
                        decoration: _inputDecoration(label: 'Property Status', icon: Icons.info_outline),
                        items: PropertyStatus.values.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status.value.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _status = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Assigned Partner Dropdown
                      _isLoadingPartners
                          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                          : DropdownButtonFormField<String?>(
                              initialValue: _assignedPartnerId,
                              decoration: _inputDecoration(label: 'Assigned Partner (Optional)', icon: Icons.person_outline),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Unassigned / Available for All'),
                                ),
                                ..._partners.map((partner) {
                                  return DropdownMenuItem<String?>(
                                    value: partner.id,
                                    child: Text(partner.fullName ?? partner.email ?? 'Unknown Partner'),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() => _assignedPartnerId = val);
                              },
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Commission Structure Card ──
              Card(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commission Structure',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Commission Type Choice
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Percentage (%)')),
                              selected: _commissionType == CommissionType.percentage,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _commissionType = CommissionType.percentage;
                                    _commissionValueController.text = '5.0'; // reset default
                                  });
                                }
                              },
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surface,
                              labelStyle: TextStyle(
                                color: _commissionType == CommissionType.percentage ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: _commissionType == CommissionType.percentage ? AppColors.primary : AppColors.border),
                              ),
                              showCheckmark: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Flat Fee (₦)')),
                              selected: _commissionType == CommissionType.flatFee,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _commissionType = CommissionType.flatFee;
                                    _commissionValueController.text = '1000000'; // reset default
                                  });
                                }
                              },
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surface,
                              labelStyle: TextStyle(
                                color: _commissionType == CommissionType.flatFee ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: _commissionType == CommissionType.flatFee ? AppColors.primary : AppColors.border),
                              ),
                              showCheckmark: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Commission Value Field
                      TextFormField(
                        controller: _commissionValueController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          label: _commissionType == CommissionType.percentage ? 'Commission Percentage (%)' : 'Commission Amount (₦)',
                          icon: _commissionType == CommissionType.percentage ? Icons.percent_rounded : Icons.monetization_on_outlined,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Commission value is required';
                          }
                          final parsed = double.tryParse(value);
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid positive number';
                          }
                          if (_commissionType == CommissionType.percentage && parsed > 100) {
                            return 'Percentage cannot exceed 100%';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Action Buttons ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: _isSaving
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.textOnAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _isEditMode ? 'Update Property Listing' : 'Publish Property Listing',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textOnAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.surface,
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
    );
  }
}
