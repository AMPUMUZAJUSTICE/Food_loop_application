import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification preferences - paymentUpdates is always on
  bool _newMessages = true;
  bool _expiryReminders = true;
  bool _newOrders = true;
  bool _marketing = false;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _newMessages = prefs.getBool('notif_new_messages') ?? true;
      _expiryReminders = prefs.getBool('notif_expiry_reminders') ?? true;
      _newOrders = prefs.getBool('notif_new_orders') ?? true;
      _marketing = prefs.getBool('notif_marketing') ?? false;
      _loading = false;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    // Sync notification preferences to Firestore
    if (key.startsWith('notif_')) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final prefMap = {
          'new_messages': _newMessages,
          'expiry_reminders': _expiryReminders,
          'new_orders': _newOrders,
          'marketing': _marketing,
        };
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'notificationPrefs': prefMap,
          }, SetOptions(merge: true));
        } catch (_) {
          // Silently ignore offline network exceptions
        }
      }
    }
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder()),
                validator: (v) => (v != newCtrl.text) ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
                final user = FirebaseAuth.instance.currentUser!;
                final cred = EmailAuthProvider.credential(email: user.email!, password: currentCtrl.text);
                await user.reauthenticateWithCredential(cred);
                await user.updatePassword(newCtrl.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password updated successfully'), backgroundColor: AppColors.primaryGreen),
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message ?? 'Error'), backgroundColor: AppColors.errorRed),
                  );
                }
              }
            },
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showCommunityStandards() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Community Standards'),
        content: const SingleChildScrollView(
          child: Text(
            '🌿 Food Loop Community Rules\n\n'
            '1. Only list food you genuinely intend to share or sell at a fair price.\n'
            '2. Listings must be honest — accurate photos, descriptions and expiry dates.\n'
            '3. Treat all members with respect. Harassment and discrimination will result in a ban.\n'
            '4. Complete transactions you commit to. Repeated no-shows will result in suspension.\n'
            '5. Do not list food that is spoiled, contaminated, or otherwise unsafe.\n'
            '6. Keep personal contact information off public listings — use the in-app chat.\n'
            '7. Report suspicious buyers or sellers using the "Report a Problem" option.',
            style: TextStyle(height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: AppColors.primaryGreen)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  Future<void> _reportProblem() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@foodloop.must',
      query: 'subject=Food Loop Problem Report&body=Please describe your issue here:',
    );
    await launchUrl(uri);
  }

  Future<void> _deleteAccount() async {
    final confirmCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete your account and all your data (listings, messages, orders, profile). This cannot be undone.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text('Type DELETE to confirm:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: confirmCtrl,
              decoration: const InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () {
              if (confirmCtrl.text.trim() == 'DELETE') {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please type DELETE exactly')),
                );
              }
            },
            child: const Text('Delete My Account', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
    );

    try {
      // Force token refresh to ensure Function context is authenticated
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      
      final callable = FirebaseFunctions.instance.httpsCallable('deleteUserAccount');
      await callable.call();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.errorRed),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.pop(context); // close loading
      context.read<AuthBloc>().add(AuthSignOutRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)));
    }

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryGreen,
        elevation: 1,
      ),
      body: ListView(
        children: [
          // ─── ACCOUNT ───
          _sectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppColors.primaryGreen),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => context.push('/edit-profile'),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user, color: AppColors.primaryGreen),
            title: const Text('Verification Status'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryGreen),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 14),
                  SizedBox(width: 4),
                  Text('Email & Phone Verified', style: TextStyle(fontSize: 11, color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // ─── NOTIFICATIONS ───
          _sectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.chat_bubble_outline, color: AppColors.primaryGreen),
            title: const Text('New Messages'),
            value: _newMessages,
            activeThumbColor: AppColors.primaryGreen,
            onChanged: (v) {
              setState(() => _newMessages = v);
              _savePref('notif_new_messages', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.account_balance_wallet_outlined, color: Colors.grey),
            title: const Text('Payment Updates'),
            subtitle: const Text('Required — cannot be disabled', style: TextStyle(fontSize: 12, color: Colors.grey)),
            value: true,
            activeThumbColor: AppColors.primaryGreen,
            onChanged: null, // always on, disabled
          ),
          SwitchListTile(
            secondary: const Icon(Icons.timer_outlined, color: AppColors.primaryGreen),
            title: const Text('Expiry Reminders'),
            value: _expiryReminders,
            activeThumbColor: AppColors.primaryGreen,
            onChanged: (v) {
              setState(() => _expiryReminders = v);
              _savePref('notif_expiry_reminders', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.shopping_bag_outlined, color: AppColors.primaryGreen),
            title: const Text('New Orders (Seller)'),
            value: _newOrders,
            activeThumbColor: AppColors.primaryGreen,
            onChanged: (v) {
              setState(() => _newOrders = v);
              _savePref('notif_new_orders', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.local_offer_outlined, color: AppColors.primaryGreen),
            title: const Text('Marketing & Promotions'),
            value: _marketing,
            activeThumbColor: AppColors.primaryGreen,
            onChanged: (v) {
              setState(() => _marketing = v);
              _savePref('notif_marketing', v);
            },
          ),

          const Divider(height: 1),

          // ─── SECURITY ───
          _sectionHeader('Security'),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: AppColors.primaryGreen),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _changePassword,
          ),

          const Divider(height: 1),

          // ─── COMMUNITY ───
          _sectionHeader('Community'),
          ListTile(
            leading: const Icon(Icons.eco_outlined, color: AppColors.primaryGreen),
            title: const Text('Food Safety Guidelines'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => context.push('/settings/safety'),
          ),
          ListTile(
            leading: const Icon(Icons.groups_outlined, color: AppColors.primaryGreen),
            title: const Text('Community Standards'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _showCommunityStandards,
          ),

          const Divider(height: 1),

          // ─── PRIVACY & LEGAL ───
          _sectionHeader('Privacy & Legal'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primaryGreen),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, color: Colors.grey, size: 18),
            onTap: () => _launchUrl('https://foodloop.must.ac.ug/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined, color: AppColors.primaryGreen),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new, color: Colors.grey, size: 18),
            onTap: () => _launchUrl('https://foodloop.must.ac.ug/terms'),
          ),

          const Divider(height: 1),

          // ─── SUPPORT ───
          _sectionHeader('Support'),
          ListTile(
            leading: const Icon(Icons.help_outline, color: AppColors.primaryGreen),
            title: const Text('Help & FAQ'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _launchUrl('https://foodloop.must.ac.ug/faq'),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined, color: AppColors.primaryGreen),
            title: const Text('Report a Problem'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _reportProblem,
          ),

          const Divider(height: 1),

          // ─── DANGER ZONE ───
          _sectionHeader('Danger Zone', isRed: true),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.errorRed),
            title: const Text('Delete Account', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
            subtitle: const Text('Permanently removes your account and all data', style: TextStyle(fontSize: 12, color: Colors.grey)),
            onTap: _deleteAccount,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: isRed ? AppColors.errorRed : AppColors.primaryGreen,
        ),
      ),
    );
  }
}
