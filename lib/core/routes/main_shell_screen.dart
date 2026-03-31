import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/chat/presentation/bloc/unread_messages_cubit.dart';
import '../constants/app_colors.dart';

class MainShellScreen extends StatelessWidget {
  final Widget child;
  const MainShellScreen({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/feed')) return 0;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/post')) return 2;
    if (location.startsWith('/chat')) return 3;
    if (location.startsWith('/profile') || location.startsWith('/orders')) return 4;
    return 0; // default to home
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/feed');
        break;
      case 1:
        context.go('/search');
        break;
      case 2:
        context.go('/post/step1');
        break;
      case 3:
        context.go('/chat');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onItemTapped(index, context),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: AppColors.textGrey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search_outlined), activeIcon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              backgroundColor: AppColors.primaryGreen,
              radius: 20,
              child: Icon(Icons.add, color: AppColors.white),
            ),
            activeIcon: CircleAvatar(
              backgroundColor: AppColors.darkGreen,
              radius: 20,
              child: Icon(Icons.add, color: AppColors.white),
            ),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: BlocBuilder<UnreadMessagesCubit, int>(
              builder: (context, count) {
                return Badge(
                  label: Text(count.toString()),
                  backgroundColor: AppColors.errorRed,
                  textColor: Colors.white,
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.chat_bubble_outline),
                );
              },
            ),
            activeIcon: BlocBuilder<UnreadMessagesCubit, int>(
              builder: (context, count) {
                return Badge(
                  label: Text(count.toString()),
                  backgroundColor: AppColors.errorRed,
                  textColor: Colors.white,
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.chat_bubble),
                );
              },
            ),
            label: 'Chat',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
