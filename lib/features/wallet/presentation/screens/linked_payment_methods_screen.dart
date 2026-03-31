import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';

class LinkedPaymentMethodsScreen extends StatefulWidget {
  const LinkedPaymentMethodsScreen({super.key});

  @override
  State<LinkedPaymentMethodsScreen> createState() => _LinkedPaymentMethodsScreenState();
}

class _LinkedPaymentMethodsScreenState extends State<LinkedPaymentMethodsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _phoneNumber;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserPhone();
  }

  void _loadUserPhone() {
    final user = _auth.currentUser;
    setState(() {
      _phoneNumber = user?.phoneNumber;
    });
  }

  Future<void> _unlinkPhone() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Mobile Money'),
        content: const Text('Are you sure you want to remove this mobile money number from your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unlink', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Unlink the phone provider
        await user.unlink(PhoneAuthProvider.PROVIDER_ID);
        // Remove from Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'phoneNumber': FieldValue.delete(),
        });
        
        // Reload user to sync state
        await user.reload();
        _loadUserPhone();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mobile Money number unlinked successfully'), backgroundColor: AppColors.primaryGreen),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startPhoneLinking() async {
    final phoneController = TextEditingController(text: '+256');
    final String? phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Mobile Money Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your MTN or Airtel Mobile Money number.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+256 700 000000',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            onPressed: () {
              final number = phoneController.text.trim();
              if (number.length >= 10) {
                Navigator.pop(ctx, number);
              }
            },
            child: const Text('Verify', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (phone == null || phone.isEmpty) return;

    setState(() => _isLoading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _linkCredential(credential, phone);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: ${e.message}'), backgroundColor: AppColors.errorRed),
        );
      },
      codeSent: (String verificationId, int? resendToken) async {
        if (!mounted) return;
        setState(() => _isLoading = false);
        final smsController = TextEditingController();
        final String? smsCode = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Enter SMS Code'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Code sent to $phone. Enter it below:', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: smsController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '6-digit Code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, null);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                onPressed: () {
                  final code = smsController.text.trim();
                  if (code.length == 6) {
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx, code);
                  }
                },
                child: const Text('Confirm', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (smsCode != null && smsCode.isNotEmpty) {
          setState(() => _isLoading = true);
          try {
            final credential = PhoneAuthProvider.credential(
              verificationId: verificationId,
              smsCode: smsCode,
            );
            await _linkCredential(credential, phone);
          } catch (e) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid code: ${e.toString()}'), backgroundColor: AppColors.errorRed),
            );
          }
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> _linkCredential(PhoneAuthCredential credential, String phone) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.linkWithCredential(credential);
        
        // Save to Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'phoneNumber': phone,
        });

        await user.reload();
        _loadUserPhone();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mobile Money linked successfully!'), backgroundColor: AppColors.primaryGreen),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to link: ${e.message}'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linked Payment Methods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryGreen,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Mobile Money (SeerBit)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkGreen),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your verified MTN or Airtel mobile money number is securely linked. This number is used for fast, automated checkouts via SeerBit when ordering food.',
                  style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 24),
                
                if (_phoneNumber != null && _phoneNumber!.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone_android, color: AppColors.primaryGreen),
                      ),
                      title: Text(_phoneNumber!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: const Row(
                        children: [
                          Icon(Icons.verified, color: AppColors.primaryGreen, size: 14),
                          SizedBox(width: 4),
                          Text('Verified Mobile Money', style: TextStyle(color: AppColors.primaryGreen, fontSize: 12)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: AppColors.errorRed),
                        onPressed: _unlinkPhone,
                        tooltip: 'Unlink Number',
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.mobile_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No mobile money number linked.',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _startPhoneLinking,
                            child: const Text('Link Mobile Money Number', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 48),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Cards & Bank Accounts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkGreen),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Currently, Food Loop only supports direct Mobile Money integration for both sellers and buyers to ensure lowest transaction fees. Bank cards are not yet supported for automated saving.',
                  style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
                ),
              ],
            ),
    );
  }
}
