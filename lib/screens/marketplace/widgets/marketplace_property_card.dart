import 'package:flutter/material.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/screens/marketplace/widgets/inspection_booking_modal.dart';

class MarketplacePropertyCard extends StatelessWidget {
  final Property property;
  final VoidCallback? onTap;

  const MarketplacePropertyCard({
    super.key,
    required this.property,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRent = property.isRent;
    final isDeveloperEstate = !property.isMarketplace;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    property.images.isNotEmpty
                        ? property.images.first
                        : 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=800&q=80',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.apartment_rounded, size: 48, color: Colors.grey),
                      ),
                    ),
                  ),
                ),

                // Top Pills
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: [
                      // Rent / Sale / Nissie Estate Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDeveloperEstate
                              ? const Color(0xFFD97706) // Gold / Bronze for Nissie estates
                              : (isRent ? const Color(0xFF059669) : const Color(0xFF2563EB)),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          isDeveloperEstate
                              ? 'NISSIE SIGNATURE'
                              : (isRent ? 'FOR RENT' : 'FOR SALE'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Verified badge
                      if (property.isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 13),
                              SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Price Tag Overlay
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      property.displayPrice,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    property.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.locationDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Amenities Chips Row
                  Row(
                    children: [
                      if (property.bedrooms > 0) ...[
                        _buildFeatureChip(Icons.bed_outlined, '${property.bedrooms} Beds'),
                        const SizedBox(width: 8),
                      ],
                      if (property.bathrooms > 0) ...[
                        _buildFeatureChip(Icons.bathtub_outlined, '${property.bathrooms} Baths'),
                        const SizedBox(width: 8),
                      ],
                      _buildFeatureChip(Icons.home_work_outlined, property.propertyCategory.toUpperCase()),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Bottom Action Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Shielded security note
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 15, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            isDeveloperEstate ? 'Direct Nissie Estate' : 'Shielded Agent Contact',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // Inspection CTA Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 1,
                        ),
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(
                          isDeveloperEstate
                              ? 'Free Inspection'
                              : 'Book (₦${property.inspectionFee.toStringAsFixed(0)})',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => InspectionBookingModal.show(context, property),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF475569)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
