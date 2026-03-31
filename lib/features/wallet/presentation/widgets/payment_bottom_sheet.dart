import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/flutterwave_config.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../feed/domain/entities/food_listing.dart';
import '../../../orders/domain/entities/order.dart' as dom;
import '../../data/flutterwave_service.dart';

enum PaymentMethod { wallet, mobileMoney }

class PaymentBottomSheet extends StatefulWidget {
  final FoodListing? listing;
  final dom.Order? order;
  final String buyerId;
  final FirebaseFirestore? firestore;
  final FirebaseFunctions? functions;

  const PaymentBottomSheet({
    super.key, 
    this.listing, 
    this.order,
    required this.buyerId,
    this.firestore,
    this.functions,
  }) : assert(listing != null || order != null, 'Either listing or order must be provided');

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  PaymentMethod? _selectedMethod;
  bool _isProcessing = false;
  bool _isLoadingBuyer = true;
  AppUser? _buyer;
  
  late double _amount;
  late double _platformFee;
  late double _totalAmount;
  bool _hasSufficientBalance = false;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _amount = widget.order!.amount;
      _platformFee = widget.order!.platformFee;
    } else {
      _amount = widget.listing!.price;
      _platformFee = FlutterwaveConfig.calculatePlatformFee(_amount);
    }
    _totalAmount = _amount + _platformFee;
    _fetchBuyerData();
  }

  Future<void> _fetchBuyerData() async {
    try {
      final doc = await (widget.firestore ?? FirebaseFirestore.instance).collection('users').doc(widget.buyerId).get();
      if (doc.exists) {
        _buyer = AppUser.fromJson(doc.data()!);
        _hasSufficientBalance = _buyer!.walletBalance >= _totalAmount;
        if (_hasSufficientBalance) {
          _selectedMethod = PaymentMethod.wallet;
        } else {
          _selectedMethod = PaymentMethod.mobileMoney;
        }
      }
    } catch (e) {
      debugPrint('Failed to load buyer data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBuyer = false);
    }
  }

  Future<void> _processPayment() async {
    if (_selectedMethod == null || _buyer == null) return;

    setState(() => _isProcessing = true);

    try {
      final orderRef = widget.order != null 
          ? (widget.firestore ?? FirebaseFirestore.instance).collection('orders').doc(widget.order!.id)
          : (widget.firestore ?? FirebaseFirestore.instance).collection('orders').doc();
      
      final order = widget.order ?? dom.Order(
        id: orderRef.id,
        listingId: widget.listing!.id,
        listingTitle: widget.listing!.title,
        listingImageUrl: widget.listing!.imageUrls.isNotEmpty ? widget.listing!.imageUrls.first : '',
        buyerId: _buyer!.uid,
        buyerName: _buyer!.fullName,
        sellerId: widget.listing!.sellerId,
        sellerName: widget.listing!.sellerName,
        amount: _amount,
        platformFee: _platformFee,
        status: dom.OrderStatus.pending,
        createdAt: DateTime.now(),
      );

      if (widget.order == null) {
        await orderRef.set(order.toJson());
      }
      
      final funcs = widget.functions ?? sl<FirebaseFunctions>();
      final flutterwaveService = sl<FlutterwaveService>();

      if (_selectedMethod == PaymentMethod.wallet) {
        // Force token refresh to ensure Function context is authenticated
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        
        await funcs.httpsCallable('processWalletPayment').call({'orderId': order.id});
        await (widget.firestore ?? FirebaseFirestore.instance).collection('listings').doc(order.listingId).update({'status': 'sold'});
        
        if (mounted) {
          context.pop(); 
          context.push('/orders');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment successful! Arrange pickup with seller.'), backgroundColor: AppColors.primaryGreen));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Redirecting to Flutterwave...'), duration: Duration(seconds: 2)),
        );
        flutterwaveService.initiatePayment(
          context,
          order,
          _buyer!,
          onSuccess: () async {
            // Use the new hardened confirmation flow
            await _handlePaymentComplete(context, order);
          },
          onFailure: () {
            if (mounted) setState(() => _isProcessing = false);
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to process payment: $e'), backgroundColor: AppColors.errorRed));
      }
    }
  }

  Future<void> _handlePaymentComplete(
    BuildContext context,
    dom.Order order,
  ) async {
    // 1. Show a non-dismissible loading overlay immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryGreen),
                  SizedBox(height: 24),
                  Text(
                    'Confirming your payment...',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please do not close the app',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      // The actual work happens here. The FlutterwaveService._callFunctionWithRetry
      // already handles the token refresh and the actual Cloud Function call.
      // But we just wait for it to finish.
      
      // Update the listing status locally first
      await (widget.firestore ?? FirebaseFirestore.instance)
          .collection('listings')
          .doc(order.listingId)
          .update({'status': 'sold'});

      if (context.mounted) {
        // Dismiss loader
        Navigator.of(context).pop();
        
        // Success redirect
        context.pop(); // Close bottom sheet
        context.push('/orders');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed! Arrange pickup with the seller.'),
            backgroundColor: AppColors.primaryGreen,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Dismiss loader
        Navigator.of(context).pop();

        // Show recovery dialog — payment went through but order not updated on backend
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Payment Received — Order Not Updated'),
            content: const Text(
              'Your payment was successful but we could not update your order automatically.\n\n'
              'Please tap "Retry" and we will try again. If this keeps failing, '
              'contact support with your payment receipt.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Recursive retry of the confirmation
                  _handlePaymentComplete(context, order);
                },
                child: const Text('Retry', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close', style: TextStyle(color: AppColors.textGrey)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: _isLoadingBuyer 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                  : ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 24),
                  const Text('Complete Purchase', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark), textAlign: TextAlign.center),
                  const SizedBox(height: 24),

                  // Listing Info Horizontal Card
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[200]),
                        child: (widget.listing?.imageUrls.isNotEmpty ?? false) || (widget.order?.listingImageUrl.isNotEmpty ?? false)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                    imageUrl: widget.order?.listingImageUrl ?? widget.listing!.imageUrls.first, 
                                    fit: BoxFit.cover
                                ),
                              )
                            : const Icon(Icons.fastfood, color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.order?.listingTitle ?? widget.listing!.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
                            const SizedBox(height: 4),
                            Text('UGX ${_amount.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.offWhite, thickness: 2),
                  const SizedBox(height: 16),

                  // Wallet Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Food Loop Wallet', style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text('UGX ${_buyer?.walletBalance.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                        const SizedBox(height: 8),
                        if (_hasSufficientBalance)
                          const Text('✓ Sufficient balance', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 14))
                        else
                          Text('⚠ Insufficient — top up UGX ${(_totalAmount - (_buyer?.walletBalance ?? 0)).toStringAsFixed(0)}', style: const TextStyle(color: AppColors.warningAmber, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 12),

                  // Payment Radios
                  _buildRadioOption(
                    title: 'Use Wallet Balance',
                    value: PaymentMethod.wallet,
                    icon: Icons.account_balance_wallet,
                    enabled: _hasSufficientBalance,
                  ),
                  _buildRadioOption(
                    title: 'Mobile Money via Flutterwave',
                    value: PaymentMethod.mobileMoney,
                    icon: Icons.phone_android,
                    enabled: true,
                  ),

                  const SizedBox(height: 24),
                  
                  // Breakdown Table
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        _buildBreakdownRow('Item price', 'UGX ${_amount.toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        _buildBreakdownRow('Platform fee (5%)', 'UGX ${_platformFee.toStringAsFixed(0)}'),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                        _buildBreakdownRow('Total', 'UGX ${_totalAmount.toStringAsFixed(0)}', isBold: true),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Action Buttons
                  ElevatedButton(
                    onPressed: _isProcessing || _selectedMethod == null ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Pay UGX ${_totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isProcessing ? null : () => context.pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
            if (_isProcessing)
              Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                child: const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRadioOption({required String title, required PaymentMethod value, required IconData icon, required bool enabled}) {
    return RadioListTile<PaymentMethod>(
      title: Row(
        children: [
          Icon(icon, color: enabled ? AppColors.textDark : AppColors.textGrey, size: 20),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: enabled ? AppColors.textDark : AppColors.textGrey)),
        ],
      ),
      value: value,
      groupValue: _selectedMethod,
      onChanged: enabled ? (PaymentMethod? method) => setState(() => _selectedMethod = method) : null,
      activeColor: AppColors.primaryGreen,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isBold ? AppColors.textDark : AppColors.textGrey, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
        Text(value, style: TextStyle(color: AppColors.textDark, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
      ],
    );
  }
}
