import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/flutterwave_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../orders/domain/entities/order.dart';

class FlutterwaveService {
  final FirebaseFunctions _functions;

  FlutterwaveService(this._functions);

  String _generateTxRef() {
    final uuid = const Uuid().v4().replaceAll('-', '');
    return 'FLW${uuid.substring(0, 18).toUpperCase()}';
  }

  Future<void> initiateTopUp(
    BuildContext context,
    double amount,
    AppUser user, {
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
  }) async {
    final txRef = _generateTxRef();

    final flutterwave = Flutterwave(
      publicKey: FlutterwaveConfig.publicKey,
      currency: FlutterwaveConfig.currency,
      redirectUrl: "https://food-loop-verified.web.app/callback",
      txRef: txRef,
      amount: amount.toStringAsFixed(0),
      customer: Customer(
        name: user.fullName,
        phoneNumber: user.phoneNumber,
        email: user.email,
      ),
      paymentOptions: "card, mobilemoneyuganda",
      customization: Customization(
        title: "Wallet Top Up",
        description: "Adding funds to your Food Loop wallet",
        logo: "https://firebasestorage.googleapis.com/v0/b/food-loop-verified.appspot.com/o/app_assets%2Flogo.png?alt=media",
      ),
      isTestMode: true,
    );

    final ChargeResponse response = await flutterwave.charge(context);

    if (response.success == true || response.status == "successful") {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Successful. Crediting wallet...'), backgroundColor: AppColors.primaryGreen)
      );
      
      try {
        await _callFunctionWithRetry('creditWallet', {
          'transactionRef': txRef,
          'amount': amount,
        });
        onSuccess();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating wallet: $e'), backgroundColor: AppColors.errorRed)
          );
        }
        onFailure();
      }
    } else {
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Payment failed: ${response.status}'), backgroundColor: AppColors.errorRed)
         );
       }
       onFailure();
    }
  }

  Future<void> initiatePayment(
    BuildContext context,
    Order order,
    AppUser buyer, {
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
  }) async {
    final totalAmount = order.amount + order.platformFee;
    final txRef = _generateTxRef();

    final flutterwave = Flutterwave(
      publicKey: FlutterwaveConfig.publicKey,
      currency: FlutterwaveConfig.currency,
      redirectUrl: "https://food-loop-verified.web.app/callback",
      txRef: txRef,
      amount: totalAmount.toStringAsFixed(0),
      customer: Customer(
        name: buyer.fullName,
        phoneNumber: buyer.phoneNumber,
        email: buyer.email,
      ),
      paymentOptions: "card, mobilemoneyuganda",
      customization: Customization(
        title: "Order Payment",
        description: "Payment for ${order.listingTitle}",
        logo: "https://firebasestorage.googleapis.com/v0/b/food-loop-verified.appspot.com/o/app_assets%2Flogo.png?alt=media",
      ),
      isTestMode: true,
    );

    final ChargeResponse response = await flutterwave.charge(context);

    if (response.success == true || response.status == "successful") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Successful. Processing order...'), backgroundColor: AppColors.primaryGreen)
      );
      
      try {
        await _callFunctionWithRetry('confirmFlutterwavePayment', {
          'orderId': order.id,
          'transactionRef': txRef,
          'flutterwaveTransactionId': response.transactionId,
        });
        onSuccess();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error processing order: $e'), backgroundColor: AppColors.errorRed)
          );
        }
        onFailure();
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${response.status}'), backgroundColor: AppColors.errorRed)
        );
      }
      onFailure();
    }
  }

  Future<void> _callFunctionWithRetry(String functionName, Map<String, dynamic> data) async {
    // Wait for Auth state to stabilize after return from WebView
    debugPrint('DEBUG: Waiting for Auth state to stabilize before calling $functionName...');
    await Future.delayed(const Duration(seconds: 2));

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User is not logged in');
      }
      
      // Force token refresh — this is critical after returning from an external payment WebView
      debugPrint('DEBUG: Refreshing ID token for ${user.uid}...');
      await user.getIdToken(true); 
    } catch (e) {
      debugPrint('DEBUG: Auth refresh failed: $e');
      throw Exception('Authentication error: Please log in again');
    }

    int attempts = 0;
    while (attempts < 3) {
      try {
        final callable = _functions.httpsCallable(
          functionName,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        );
        
        debugPrint('DEBUG: Calling $functionName with data: $data');
        await callable.call(data);
        debugPrint('DEBUG: Successfully called $functionName');
        return; // Success
      } catch (e) {
        attempts++;
        debugPrint('DEBUG: Call to $functionName failed (attempt $attempts): $e');
        
        // Handle specifically the unauthenticated error by refreshing token again and retrying
        if (e.toString().contains('unauthenticated') && attempts < 3) {
          debugPrint('DEBUG: Unauthenticated error received. Refreshing token and retrying...');
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
          await Future.delayed(Duration(seconds: 2 * attempts));
          continue;
        }
        rethrow;
      }
    }
  }
}
