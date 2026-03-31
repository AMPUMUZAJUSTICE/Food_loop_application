import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../orders/domain/entities/order.dart' as app_order;
import '../bloc/rating_bloc.dart';

class RatingScreen extends StatelessWidget {
  final String orderId;

  const RatingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RatingBloc>()..add(LoadOrderToRate(orderId)),
      child: const _RatingScreenView(),
    );
  }
}

class _RatingScreenView extends StatefulWidget {
  const _RatingScreenView();

  @override
  State<_RatingScreenView> createState() => _RatingScreenViewState();
}

class _RatingScreenViewState extends State<_RatingScreenView> {
  int _foodQuality = 0;
  int _reliability = 0;
  bool _isAnonymous = false;
  final _commentController = TextEditingController();

  void _submit(BuildContext context, app_order.Order order) {
    if (_foodQuality == 0 || _reliability == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a star rating for both categories.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    context.read<RatingBloc>().add(
          SubmitRatingEvent(
            orderId: order.id,
            reviewerId: authState.user.uid,
            reviewerName: authState.user.displayName,
            sellerId: order.sellerId,
            foodQualityRating: _foodQuality,
            reliabilityRating: _reliability,
            comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
            isAnonymous: _isAnonymous,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Leave a Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: BlocConsumer<RatingBloc, RatingState>(
        listener: (context, state) {
          if (state is RatingSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thanks for your feedback! 🙏'),
                backgroundColor: AppColors.primaryGreen,
              ),
            );
            context.go('/feed');
          } else if (state is RatingError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.message}'), backgroundColor: AppColors.errorRed),
            );
          }
        },
        builder: (context, state) {
          if (state is RatingLoading || state is RatingInitial) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
          }
          if (state is RatingError) {
            return Center(child: Text(state.message, style: const TextStyle(color: AppColors.errorRed)));
          }

          app_order.Order? order;
          bool isSubmitting = false;

          if (state is RatingOrderLoaded) {
            order = state.order;
          } else if (state is RatingSubmitting) {
            // we lost the order reference strictly in state, but ideally UI handles this gracefully
            isSubmitting = true;
          } else if (state is RatingSuccess) {
            return const Center(child: Text('Success! redirecting...'));
          }

          if (order == null && !isSubmitting) {
            return const Center(child: Text('Order details could not be loaded.'));
          }

          // In standard Bloc, if state transitions to submitting, we might not have `order` in state. 
          // For prototype simplicity, we'll only show the form if we successfully kept order around 
          // or just show an overlay. Actually, I didn't keep order in RatingSubmitting state.
          // Let's just assume we can show a loader if missing order while submitting.
          if (isSubmitting) {
             return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'How was your experience?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Listing & Seller Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: order!.listingImageUrl.isNotEmpty ? order.listingImageUrl : 'https://via.placeholder.com/80',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[200]),
                          errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.dining)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.listingTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.storefront, size: 14, color: AppColors.textGrey),
                                const SizedBox(width: 4),
                                Expanded(child: Text(order.sellerName, style: const TextStyle(color: AppColors.textGrey, fontSize: 13), maxLines: 1)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Stars section
                const Text('Food Quality', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _AnimatedStarRating(
                  rating: _foodQuality,
                  onRatingChanged: (val) => setState(() => _foodQuality = val),
                ),
                const SizedBox(height: 24),

                const Text('Seller Reliability', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _AnimatedStarRating(
                  rating: _reliability,
                  onRatingChanged: (val) => setState(() => _reliability = val),
                ),
                const SizedBox(height: 32),

                // Comment
                const Text('Share details about your experience... (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: 'Was the food tasty? Was the seller on time?',
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Anonymity Toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primaryGreen,
                  title: const Text('Submit anonymously', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text("Your name won't be shown publicly", style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  value: _isAnonymous,
                  onChanged: (val) => setState(() => _isAnonymous = val),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: () => _submit(context, order!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedStarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRatingChanged;

  const _AnimatedStarRating({required this.rating, required this.onRatingChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isSelected = starValue <= rating;

        return GestureDetector(
          onTap: () => onRatingChanged(starValue),
          child: AnimatedScale(
            scale: isSelected ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(
                isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 40,
                color: isSelected ? AppColors.warningAmber : Colors.grey[300],
              ),
            ),
          ),
        );
      }),
    );
  }
}
