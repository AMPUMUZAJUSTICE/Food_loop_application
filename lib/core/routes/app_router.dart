import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/auth/presentation/screens/phone_verification_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/feed/presentation/screens/listing_detail_screen.dart';
import '../../features/post_food/presentation/screens/post_step1_screen.dart';
import '../../features/post_food/presentation/screens/post_step2_screen.dart';
import '../../features/post_food/presentation/screens/post_step3_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/listings/presentation/screens/my_listings_screen.dart';
import '../../features/listings/presentation/screens/edit_listing_screen.dart';
import '../../features/feed/domain/entities/food_listing.dart';
import '../../features/orders/presentation/screens/my_orders_screen.dart';
import '../../features/expiry_tracker/presentation/screens/expiry_tracker_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/ratings/presentation/screens/rating_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/food_safety_screen.dart';
import '../../features/wallet/presentation/screens/linked_payment_methods_screen.dart';
import '../utils/route_placeholders.dart' hide FoodSafetyScreen;
import '../utils/go_router_refresh_stream.dart';
import 'main_shell_screen.dart';
import '../../app.dart';

class AppRouter {
  final AuthBloc authBloc;

  AppRouter(this.authBloc);

  late final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = authBloc.state;
      
      final bool isAuthRoute = state.uri.path == '/login' || 
          state.uri.path == '/signup' || 
          state.uri.path == '/verify-email' || 
          state.uri.path == '/verify-phone';

      if (state.uri.path == '/') {
        if (authState is AuthAuthenticated) {
          return '/feed';
        } else if (authState is AuthUnauthenticated) {
          return '/login';
        }
        return null; // Stay on splash while AuthInitial or AuthLoading
      }

      // If user is not authenticated and trying to access a protected route
      if ((authState is! AuthAuthenticated) && !isAuthRoute) {
        if (authState is AuthEmailVerificationPending && state.uri.path == '/verify-email') return null;
        if (authState is AuthPhoneVerificationPending && state.uri.path == '/verify-phone') return null;
        return '/login';
      }

      // If authenticated and trying to access auth screens
      if (authState is AuthAuthenticated && isAuthRoute) {
        return '/feed';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => EmailVerificationScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/verify-phone',
        builder: (context, state) => const PhoneVerificationScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainShellScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/feed',
            builder: (context, state) => const FeedScreen(),
            routes: [
              GoRoute(
                path: 'listing/:id',
                builder: (context, state) => ListingDetailScreen(id: state.pathParameters['id']!),
              ),
            ]
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatListScreen(),
            routes: [
              GoRoute(
                path: ':chatId',
                builder: (context, state) => ChatScreen(chatId: state.pathParameters['chatId']!),
              ),
            ]
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const MyOrdersScreen(),
          ),
        ],
      ),
      // Post Food Wizard — outside shell so it can be accessed from any screen
      GoRoute(
        path: '/post/step1',
        builder: (context, state) => const PostFoodStep1Screen(),
      ),
      GoRoute(
        path: '/post/step2',
        builder: (context, state) => const PostFoodStep2Screen(),
      ),
      GoRoute(
        path: '/post/step3',
        builder: (context, state) => const PostFoodStep3Screen(),
      ),
      GoRoute(
        path: '/rate/:orderId',
        builder: (context, state) => RatingScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/listings',
        builder: (context, state) => const MyListingsScreen(),
      ),
      GoRoute(
        path: '/edit-listing',
        builder: (context, state) => EditListingScreen(listing: state.extra as FoodListing),
      ),
      GoRoute(
        path: '/expiry',
        builder: (context, state) => const ExpiryTrackerScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'safety',
            builder: (context, state) => const FoodSafetyScreen(),
          ),
          GoRoute(
            path: 'payment-methods',
            builder: (context, state) => const LinkedPaymentMethodsScreen(),
          ),
        ]
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),

    ],
  );
}
