import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/food_listing.dart';
import 'package:shimmer/shimmer.dart';

class FoodCard extends StatelessWidget {
  final FoodListing listing;
  final double distanceKm;
  final VoidCallback onTap;

  const FoodCard({
    super.key,
    required this.listing,
    required this.distanceKm,
    required this.onTap,
  });

  bool get _expiringSoon {
    final hoursLeft = listing.pickupWindowEnd.difference(DateTime.now()).inHours;
    return hoursLeft < 24;
  }

  bool get _expiringCriticallySoon {
    final hoursLeft = listing.pickupWindowEnd.difference(DateTime.now()).inHours;
    return hoursLeft < 2;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Stack
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: CachedNetworkImage(
                      imageUrl: listing.imageUrls.isNotEmpty ? listing.imageUrls.first : '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                // Price Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      listing.isFree ? 'FREE' : 'UGX ${listing.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                // Expiry Badge
                if (listing.pickupWindowEnd.isAfter(DateTime.now()))
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: _LiveCountdownBadge(expiryDate: listing.pickupWindowEnd),
                  ),
              ],
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                      const Icon(Icons.star, size: 14, color: AppColors.warningAmber),
                      const SizedBox(width: 2),
                      Text(
                        listing.sellerRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        '${distanceKm.toStringAsFixed(1)} km away',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryGreen,
                        ),
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
}

class _LiveCountdownBadge extends StatefulWidget {
  final DateTime expiryDate;
  const _LiveCountdownBadge({required this.expiryDate});

  @override
  State<_LiveCountdownBadge> createState() => _LiveCountdownBadgeState();
}

class _LiveCountdownBadgeState extends State<_LiveCountdownBadge> {
  late Timer _timer;
  late Duration _duration;

  @override
  void initState() {
    super.initState();
    _duration = widget.expiryDate.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration = widget.expiryDate.difference(DateTime.now());
          if (_duration.isNegative) {
            _timer.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_duration.isNegative) return const SizedBox.shrink();

    final hours = _duration.inHours;
    final minutes = _duration.inMinutes % 60;
    final seconds = _duration.inSeconds % 60;

    final isCritical = _duration.inHours < 2;

    String timeText;
    if (hours > 0) {
      timeText = '${hours}h ${minutes}m';
    } else {
      timeText = '${minutes}m ${seconds}s';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCritical ? AppColors.errorRed : AppColors.warningAmber,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            timeText,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
