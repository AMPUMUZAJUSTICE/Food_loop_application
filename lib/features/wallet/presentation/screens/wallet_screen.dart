import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/flutterwave_service.dart';
import '../../domain/entities/wallet_transaction.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _flutterwaveService = sl<FlutterwaveService>();
  bool _isProcessingTopUp = false;
  bool _isProcessingWithdraw = false;
  
  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showTopUpSheet(BuildContext context, AppUser user) {
    _amountController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Top Up Wallet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAmountChip(5000),
                _buildAmountChip(10000),
                _buildAmountChip(20000),
                _buildAmountChip(50000),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Custom Amount (UGX)',
                prefixText: 'UGX ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(_amountController.text) ?? 0;
                if (amount >= 1000) {
                  Navigator.pop(context);
                  _initiateTopUp(amount, user);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum top-up is UGX 1,000')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Proceed to Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountChip(int amount) {
    return InkWell(
      onTap: () => _amountController.text = amount.toString(),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primaryGreen),
          borderRadius: BorderRadius.circular(20),
          color: AppColors.lightGreen,
        ),
        child: Text('UGX ${amount ~/ 1000}k', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
      ),
    );
  }

  void _showWithdrawSheet(BuildContext context, AppUser user) {
    _amountController.clear();
    _phoneController.text = user.phoneNumber;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Withdraw Funds', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (UGX)',
                    prefixText: 'UGX ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile Money Number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isProcessingWithdraw ? null : () async {
                    final amount = double.tryParse(_amountController.text) ?? 0;
                    if (amount < 1000) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum withdrawal is UGX 1,000')));
                      return;
                    }
                    if (amount > user.walletBalance) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient wallet balance')));
                      return;
                    }
                    
                    setModalState(() => _isProcessingWithdraw = true);
                    try {
                      // Force token refresh to ensure Function context is authenticated
                      await FirebaseAuth.instance.currentUser?.getIdToken(true);
                      
                      await sl<FirebaseFunctions>().httpsCallable('initiateWithdrawal').call({
                        'amount': amount,
                        'phoneNumber': _phoneController.text,
                      });
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal initiated. You\'ll receive funds within 24 hours.'), backgroundColor: AppColors.primaryGreen));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to initiate: $e'), backgroundColor: AppColors.errorRed));
                    } finally {
                      setModalState(() => _isProcessingWithdraw = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isProcessingWithdraw 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                    : const Text('Confirm Withdrawal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  void _initiateTopUp(double amount, AppUser user) {
    setState(() => _isProcessingTopUp = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Redirecting to Flutterwave...'), duration: Duration(seconds: 2)),
    );
    _flutterwaveService.initiateTopUp(
      context, 
      amount, 
      user, 
      onSuccess: () {
        if (mounted) setState(() => _isProcessingTopUp = false);
      }, 
      onFailure: () {
        if (mounted) setState(() => _isProcessingTopUp = false);
      }
    );
  }

  IconData _getIconForType(TransactionType type) {
    switch (type) {
      case TransactionType.topUp: return Icons.arrow_downward;
      case TransactionType.withdrawal: return Icons.arrow_upward;
      case TransactionType.paymentSent: return Icons.arrow_forward;
      case TransactionType.paymentReceived: return Icons.arrow_back;
      case TransactionType.feeDeducted: return Icons.remove;
    }
  }

  Color _getColorForType(TransactionType type) {
    switch (type) {
      case TransactionType.topUp: return AppColors.primaryGreen;
      case TransactionType.withdrawal: return AppColors.warningAmber;
      case TransactionType.paymentSent: return AppColors.errorRed;
      case TransactionType.paymentReceived: return AppColors.primaryGreen;
      case TransactionType.feeDeducted: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Scaffold(body: Center(child: Text('Not authenticated')));
        }
        
        final userUid = state.user.uid;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Wallet'),
            elevation: 0,
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.white,
            iconTheme: const IconThemeData(color: AppColors.white),
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Balance Card
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(userUid).snapshots(),
                    builder: (context, snapshot) {
                      double balance = 0.0;
                      AppUser? loadedUser;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        loadedUser = AppUser.fromJson(snapshot.data!.data() as Map<String, dynamic>);
                        balance = loadedUser.walletBalance; // Realtime active balance!
                      }

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32, top: 16),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                        ),
                        child: Column(
                          children: [
                            Text('Available Balance', style: TextStyle(color: AppColors.white, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              'UGX ${balance.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: loadedUser != null ? () => _showTopUpSheet(context, loadedUser!) : null,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.white,
                                      side: const BorderSide(color: AppColors.white),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Top Up +', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: loadedUser != null ? () => _showWithdrawSheet(context, loadedUser!) : null,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.white,
                                      side: const BorderSide(color: AppColors.white),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Withdraw →', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                  
                  // Transaction History
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        ),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('transactions')
                                .doc(userUid)
                                .collection('history')
                                .orderBy('timestamp', descending: true)
                                .limit(20)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
                              }
                              
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const Center(child: Text('No transactions yet.', style: TextStyle(color: AppColors.textGrey)));
                              }
                              
                              final transactions = snapshot.data!.docs.map((d) => WalletTransaction.fromJson(d.data() as Map<String, dynamic>)).toList();
                              
                              return ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                itemCount: transactions.length + 1, // +1 for "Load More" button Placeholder
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  if (index == transactions.length) {
                                    return TextButton(
                                      onPressed: () {
                                        // Pagination (Phase 9 placeholder)
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pagination Phase 9 Placeholder')));
                                      },
                                      child: const Text('Load More', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                                    );
                                  }
                                  
                                  final tx = transactions[index];
                                  final isPositive = tx.type == TransactionType.topUp || tx.type == TransactionType.paymentReceived;
                                  
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: _getColorForType(tx.type).withOpacity(0.1),
                                      child: Icon(_getIconForType(tx.type), color: _getColorForType(tx.type)),
                                    ),
                                    title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(DateFormat('MMM d, h:mm a').format(tx.timestamp), style: const TextStyle(fontSize: 12)),
                                    trailing: Text(
                                      '${isPositive ? '+' : '-'} UGX ${tx.amount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isPositive ? AppColors.primaryGreen : AppColors.errorRed,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              if (_isProcessingTopUp)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
                ),
            ],
          ),
        );
      },
    );
  }
}
