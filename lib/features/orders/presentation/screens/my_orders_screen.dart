import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../wallet/presentation/widgets/payment_bottom_sheet.dart';
import '../../../orders/domain/entities/order.dart' as dom;

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Scaffold(body: Center(child: Text('Not authenticated')));
        }
        return _MyOrdersView(userId: state.user.uid);
      },
    );
  }
}

class _MyOrdersView extends StatelessWidget {
  final String userId;
  const _MyOrdersView({required this.userId});

  Stream<List<dom.Order>> _ordersStream(List<String> statuses) {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('buyerId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final orders = snap.docs
              .map((d) => dom.Order.fromJson(d.data() as Map<String, dynamic>))
              .where((o) => statuses.contains(o.status.name))
              .toList();
          
          // Sort locally by createdAt descending to avoid composite index requirement
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          bottom: const TabBar(
            indicatorColor: AppColors.white,
            labelColor: AppColors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'Pending Pickups'),
              Tab(text: 'Completed History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OrdersTab(
              stream: _ordersStream([
                dom.OrderStatus.pending.name,
                dom.OrderStatus.escrowHeld.name,
              ]),
              emptyMessage: "You don't have any pending orders.",
              isPendingTab: true,
            ),
            _OrdersTab(
              stream: _ordersStream([
                dom.OrderStatus.completed.name,
                dom.OrderStatus.pickedUp.name,
                dom.OrderStatus.cancelled.name,
                dom.OrderStatus.disputed.name,
              ]),
              emptyMessage: "Your order history is empty.",
              isPendingTab: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  final Stream<List<dom.Order>> stream;
  final String emptyMessage;
  final bool isPendingTab;

  const _OrdersTab({
    required this.stream,
    required this.emptyMessage,
    required this.isPendingTab,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dom.Order>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: AppColors.errorRed),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.errorRed),
                  ),
                ],
              ),
            ),
          );
        }
 
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPendingTab ? Icons.shopping_bag_outlined : Icons.history,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: const TextStyle(fontSize: 16, color: AppColors.textGrey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            if (isPendingTab) {
              return PendingOrderCard(order: order);
            } else {
              if (order.status == dom.OrderStatus.cancelled) {
                return CancelledOrderCard(order: order);
              } else {
                return CompletedOrderCard(order: order);
              }
            }
          },
        );
      },
    );
  }
}

class PendingOrderCard extends StatelessWidget {
  final dom.Order order;

  const PendingOrderCard({super.key, required this.order});

  void _generatePickupOtp(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
    );

    try {
      // Force token refresh to ensure Function context is authenticated
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      
      final functions = sl<FirebaseFunctions>();
      final result = await functions.httpsCallable('generatePickupOTP').call({
        'orderId': order.id,
      });

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading overlay
        final otp = result.data['otp'] as String;
        _showOtpDialog(context, otp);
      }
    } catch (e) {
      if (context.mounted) {
        // Only pop if we are sure the dialog is showing
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading overlay
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate OTP: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  void _showOtpDialog(BuildContext context, String otp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OtpBottomSheet(otp: otp, order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEscrowHeld = order.status == dom.OrderStatus.escrowHeld;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: order.listingImageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _imagePlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.listingTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Seller: ${order.sellerName}',
                        style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'UGX ${order.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        isEscrowHeld ? Icons.security : Icons.hourglass_top,
                        size: 16,
                        color: isEscrowHeld ? Colors.blue : AppColors.warningAmber,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isEscrowHeld
                              ? 'Payment Held — Ready for Pickup'
                              : 'Awaiting Payment',
                          style: TextStyle(
                            color: isEscrowHeld ? Colors.blue : AppColors.warningAmber,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isEscrowHeld) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _generatePickupOtp(context),
                  icon: const Icon(Icons.qr_code, color: AppColors.white),
                  label: const Text('Show Pickup Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              if (order.flutterwaveRef != null && order.status == dom.OrderStatus.pending)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _verifyPayment(context),
                    icon: const Icon(Icons.refresh, color: AppColors.white),
                    label: const Text('Verify Payment Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warningAmber,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => PaymentBottomSheet(
                          order: order,
                          buyerId: order.buyerId,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Complete Payment'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _verifyPayment(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primaryGreen),
                SizedBox(height: 16),
                Text('Verifying with Flutterwave...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Force token refresh to ensure Function context is authenticated
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      
      final functions = sl<FirebaseFunctions>();
      await functions.httpsCallable('confirmFlutterwavePayment').call({
        'orderId': order.id,
        'transactionRef': order.flutterwaveRef,
        'flutterwaveTransactionId': order.flutterwaveTransactionId,
      });

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified successfully!'), backgroundColor: AppColors.primaryGreen),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Widget _imagePlaceholder() => Container(
        width: 80,
        height: 80,
        color: AppColors.lightGreen,
        child: const Icon(Icons.fastfood, color: AppColors.primaryGreen, size: 36),
      );
}

class _OtpBottomSheet extends StatefulWidget {
  final String otp;
  final dom.Order order;

  const _OtpBottomSheet({required this.otp, required this.order});

  @override
  State<_OtpBottomSheet> createState() => _OtpBottomSheetState();
}

class _OtpBottomSheetState extends State<_OtpBottomSheet> {
  late Timer _timer;
  int _secondsLeft = 15 * 60; // 15 minutes

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _timeString {
    int m = _secondsLeft ~/ 60;
    int s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _regenerateCode() async {
    setState(() => _secondsLeft = 15 * 60); // Reset UI quickly
    try {
      // Force token refresh to ensure Function context is authenticated
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      
      final functions = sl<FirebaseFunctions>();
      await functions.httpsCallable('generatePickupOTP').call({
        'orderId': widget.order.id,
      });
      // In a real app we'd update the OTP string, but if they keep the overlay open
      // we might want the parent to close/re-open. We'll just reset the timer for now.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to regenerate: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Pickup Code',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Show this code to ${widget.order.sellerName} to confirm pickup',
            style: const TextStyle(color: AppColors.textGrey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Text(
            widget.otp,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 12,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.offWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: widget.otp,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: AppColors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Code expires in $_timeString',
            style: TextStyle(
              color: _secondsLeft < 60 ? AppColors.errorRed : AppColors.textDark,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _regenerateCode,
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerate Code'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }
}

class CompletedOrderCard extends StatelessWidget {
  final dom.Order order;

  const CompletedOrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    // Determine if we have a rating from a subcollection or stream
    // For simplicity right now, if it's completed, allow rating.
    // In a full implementation, we'd query the 'ratings' collection.
    // We'll show the Rate button if it's completed.
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: order.listingImageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _imagePlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.listingTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                       Text(
                        'Completed: ${DateFormat('MMM d, yyyy').format(order.completedAt ?? order.createdAt)}',
                        style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                       const SizedBox(height: 4),
                        Text(
                          'Total Paid: UGX ${order.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                 TextButton.icon(
                  onPressed: () => context.push('/rate/${order.id}'),
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Rate this Order'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.warningAmber),
                 ),
              ],
            ),
          ],
        ),
      ),
    );
  }

   Widget _imagePlaceholder() => Container(
        width: 60,
        height: 60,
        color: AppColors.lightGreen,
        child: const Icon(Icons.fastfood, color: AppColors.primaryGreen, size: 24),
      );
}

class CancelledOrderCard extends StatelessWidget {
  final dom.Order order;

  const CancelledOrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
             Opacity(
              opacity: 0.5,
               child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: order.listingImageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _imagePlaceholder(),
                  ),
                ),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                        order.listingTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textGrey,
                          decoration: TextDecoration.lineThrough,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                       Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Cancelled',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                  ],
               ),
             )
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        width: 60,
        height: 60,
        color: Colors.grey[300],
        child: const Icon(Icons.fastfood, color: Colors.grey, size: 24),
      );
}
