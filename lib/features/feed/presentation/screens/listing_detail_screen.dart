import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../orders/domain/entities/order.dart' as dom;
import '../../domain/entities/food_listing.dart';
import '../../domain/repositories/feed_repository.dart';
import '../../../../features/chat/data/chat_repository.dart';
import '../../../wallet/presentation/widgets/payment_bottom_sheet.dart';

class ListingDetailScreen extends StatefulWidget {
  final String id;
  const ListingDetailScreen({super.key, required this.id});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final FeedRepository _feedRepository = sl<FeedRepository>();
  FoodListing? _listing;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentImageIndex = 0;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchListing();
  }

  Future<void> _fetchListing() async {
    setState(() => _isLoading = true);
    final result = await _feedRepository.getListingById(widget.id);
    result.fold(
      (failure) => setState(() {
        _errorMessage = failure.message;
        _isLoading = false;
      }),
      (listing) => setState(() {
        _listing = listing;
        _isLoading = false;
        if (listing == null) _errorMessage = 'Listing not found';
      }),
    );
  }

  Future<void> _claimForFree(FoodListing listing, String currentUserId, String currentUserName) async {
    setState(() => _isActionLoading = true);
    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      final order = dom.Order(
        id: orderRef.id,
        listingId: listing.id,
        listingTitle: listing.title,
        listingImageUrl: listing.imageUrls.isNotEmpty ? listing.imageUrls.first : '',
        buyerId: currentUserId,
        buyerName: currentUserName,
        sellerId: listing.sellerId,
        sellerName: listing.sellerName,
        amount: 0.0,
        platformFee: 0.0,
        status: dom.OrderStatus.escrowHeld,
        createdAt: DateTime.now(),
      );

      await orderRef.set(order.toJson());
      await FirebaseFirestore.instance.collection('listings').doc(listing.id).update({'status': 'sold'});

      if (mounted) {
        // Navigation to orders screen using .go() to ensure we leave the current branch
        context.go('/orders');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully claimed! 🎁 Please coordinate pickup with the seller.'), 
            backgroundColor: AppColors.primaryGreen,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to claim: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Widget _buildBottomBar(BuildContext context, String currentUserId, String currentUserName) {
    if (_listing == null) return const SizedBox.shrink();
    
    final isSeller = _listing!.sellerId == currentUserId;
    final isAvailable = _listing!.status == ListingStatus.active && _listing!.pickupWindowEnd.isAfter(DateTime.now());

    if (!isAvailable && !isSeller) {
      return Container(
        color: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Text('No Longer Available', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      );
    }

    if (isSeller) {
      return Container(
        color: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/edit-listing', extra: _listing),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Edit Listing', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() => _isActionLoading = true);
                    await FirebaseFirestore.instance.collection('listings').doc(_listing!.id).update({'status': 'sold'});
                    setState(() {
                      _listing = _listing?.copyWith(status: ListingStatus.sold);
                      _isActionLoading = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isActionLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                      : const Text('Mark as Sold', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isActionLoading ? null : () {
            if (_listing!.isFree) {
              _claimForFree(_listing!, currentUserId, currentUserName);
            } else {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => PaymentBottomSheet(listing: _listing!, buyerId: currentUserId),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isActionLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
              : Text(
                  _listing!.isFree ? 'Claim for Free' : 'Buy Now — UGX ${_listing!.price.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)));
    }

    if (_errorMessage != null || _listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_errorMessage ?? 'Listing not found')),
      );
    }

    final listing = _listing!;
    final hoursLeft = listing.pickupWindowEnd.difference(DateTime.now()).inHours;
    final bool isExpiringSoon = hoursLeft < 24;
    final bool isExpiringCriticallySoon = hoursLeft < 2;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        String currentUserId = '';
        String currentUserName = 'Buyer';
        if (authState is AuthAuthenticated) {
          currentUserId = authState.user.uid;
          currentUserName = authState.user.displayName ?? 'Buyer';
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: AppColors.white.withValues(alpha: 0.9),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomBar(context, currentUserId, currentUserName),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Carousel
                SizedBox(
                  height: 300,
                  child: Stack(
                    children: [
                      PageView.builder(
                        itemCount: listing.imageUrls.isEmpty ? 1 : listing.imageUrls.length,
                        onPageChanged: (index) => setState(() => _currentImageIndex = index),
                        itemBuilder: (context, index) {
                          if (listing.imageUrls.isEmpty) return Container(color: Colors.grey[300]);
                          return CachedNetworkImage(
                            imageUrl: listing.imageUrls[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(color: Colors.white),
                            ),
                          );
                        },
                      ),
                      if (listing.imageUrls.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              listing.imageUrls.length,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImageIndex == index ? AppColors.white : AppColors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // Title
                        Text(
                          listing.title,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppColors.textGrey, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(listing.pickupLocation.address, 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textGrey, fontSize: 14)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Price
                        if (listing.isFree)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.primaryGreen, borderRadius: BorderRadius.circular(8)),
                            child: const Text('FREE', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          )
                        else
                          Text(
                            'UGX ${listing.price.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                          ),
                        const SizedBox(height: 24),

                        // Expiry Timer Card
                        _CountdownTimerCard(expiryDate: listing.pickupWindowEnd),
                        
                        const SizedBox(height: 24),
                        const Divider(color: AppColors.offWhite, thickness: 1),
                        const SizedBox(height: 24),

                      // Seller Info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: listing.sellerImageUrl != null ? CachedNetworkImageProvider(listing.sellerImageUrl!) : null,
                            child: listing.sellerImageUrl == null ? const Icon(Icons.person, color: AppColors.white) : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(listing.sellerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: AppColors.warningAmber, size: 16),
                                    const SizedBox(width: 4),
                                    Text('${listing.sellerRating.toStringAsFixed(1)} rating', style: const TextStyle(color: AppColors.textGrey, fontSize: 14)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (listing.sellerId != currentUserId && currentUserId.isNotEmpty)
                            TextButton.icon(
                              onPressed: _isActionLoading ? null : () async {
                                setState(() => _isActionLoading = true);
                                try {
                                  final chatRepo = sl<ChatRepository>();
                                  final thread = await chatRepo.getOrCreateChatThread(
                                    currentUserId,
                                    listing.sellerId,
                                    listing,
                                  );
                                  if (context.mounted) {
                                    setState(() => _isActionLoading = false);
                                    context.push('/chat/${thread.id}');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    setState(() => _isActionLoading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to open chat: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.chat_bubble_outline, size: 18),
                              label: const Text('Message Seller'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                            ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Divider(color: AppColors.offWhite, thickness: 2),
                      const SizedBox(height: 24),

                      // Category & Allergens
                      const Text('Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 12),
                      Chip(
                        label: Text(listing.category.name.toUpperCase()),
                        backgroundColor: AppColors.lightGreen,
                        labelStyle: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                        side: BorderSide.none,
                      ),
                      
                      const SizedBox(height: 24),
                      if (listing.allergenTags.isNotEmpty) ...[
                        const Text('Allergens / Tags', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: listing.allergenTags.map((tag) => Chip(
                            label: Text(tag),
                            backgroundColor: Colors.grey[200],
                            side: BorderSide.none,
                          )).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Description
                      const Text('About this item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 12),
                      Text(
                        listing.description ?? 'No description provided.',
                        style: const TextStyle(fontSize: 16, color: AppColors.textGrey, height: 1.5),
                      ),
                      
                      const SizedBox(height: 24),

                      // Pickup Details
                      const Text('Pickup Location & Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 150,
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(listing.pickupLocation.latitude, listing.pickupLocation.longitude),
                                    zoom: 15,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId('pickup'),
                                      position: LatLng(listing.pickupLocation.latitude, listing.pickupLocation.longitude),
                                    ),
                                  },
                                  zoomControlsEnabled: false,
                                  scrollGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                  rotateGesturesEnabled: false,
                                  mapToolbarEnabled: false,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, color: AppColors.primaryGreen, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(listing.pickupLocation.address, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, color: AppColors.warningAmber, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Available: ${DateFormat('MMM d, h:mm a').format(listing.pickupWindowStart)} – ${DateFormat('h:mm a').format(listing.pickupWindowEnd)}',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
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
                      
                      const SizedBox(height: 24),
                      
                      // Food Safety Link
                      InkWell(
                        onTap: () => context.push('/settings/safety'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.lightGreen,
                            border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, color: AppColors.primaryGreen),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text('Read our Food Safety Guidelines', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                              ),
                              Icon(Icons.chevron_right, color: AppColors.primaryGreen),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CountdownTimerCard extends StatefulWidget {
  final DateTime expiryDate;
  const _CountdownTimerCard({required this.expiryDate});

  @override
  State<_CountdownTimerCard> createState() => _CountdownTimerCardState();
}

class _CountdownTimerCardState extends State<_CountdownTimerCard> {
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
    if (_duration.isNegative) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(24)),
        child: const Center(child: Text('EXPIRED', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey))),
      );
    }

    final hours = _duration.inHours.toString().padLeft(2, '0');
    final minutes = (_duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_duration.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_filled, color: AppColors.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'EXPIRES IN',
                style: TextStyle(
                  color: AppColors.primaryGreen.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimeUnit(hours, 'HOURS'),
              _buildTimeUnit(minutes, 'MINUTES'),
              _buildTimeUnit(seconds, 'SECONDS'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
