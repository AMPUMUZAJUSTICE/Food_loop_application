import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/profile_bloc.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileBloc _profileBloc;

  @override
  void initState() {
    super.initState();
    _profileBloc = sl<ProfileBloc>();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _profileBloc.add(LoadProfile(authState.user.uid));
    }
  }

  @override
  void dispose() {
    _profileBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _profileBloc,
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state is ProfileInitial || state is ProfileLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)));
          }
          if (state is ProfileError) {
            return Scaffold(body: Center(child: Text(state.message)));
          }

          if (state is ProfileLoaded) {
            final user = state.user;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.primaryGreen,
                elevation: 1,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      context.push('/edit-profile').then((_) {
                        _profileBloc.add(LoadProfile(user.uid));
                      });
                    },
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.lightGreen,
                      backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(user.profileImageUrl!)
                          : null,
                      child: user.profileImageUrl == null || user.profileImageUrl!.isEmpty
                          ? Text(
                              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 36, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.fullName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    if (user.department != null && user.department!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(user.department!, style: const TextStyle(color: AppColors.textGrey, fontSize: 16)),
                      ),
                    const SizedBox(height: 32),

                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryGreen),
                      title: const Text('Wallet'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/wallet'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primaryGreen),
                      title: const Text('My Orders'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/orders'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryGreen),
                      title: const Text('My Listings'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/listings'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.settings, color: AppColors.primaryGreen),
                      title: const Text('Settings'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout, color: AppColors.errorRed),
                      title: const Text('Logout', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
                      onTap: () {
                        context.read<AuthBloc>().add(AuthSignOutRequested());
                      },
                    ),
                  ],
                ),
              ),
            );
          }
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    );
  }
}
