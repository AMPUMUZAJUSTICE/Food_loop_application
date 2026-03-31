import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/constants/app_colors.dart';
import 'core/routes/app_router.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/notifications/presentation/bloc/notification_bloc.dart';
import 'features/chat/presentation/bloc/unread_messages_cubit.dart';
import 'features/post_food/presentation/bloc/post_food_cubit.dart';
import 'injection_container.dart';
import 'package:firebase_auth/firebase_auth.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class FoodLoopApp extends StatefulWidget {
  const FoodLoopApp({super.key});

  @override
  State<FoodLoopApp> createState() => _FoodLoopAppState();
}

class _FoodLoopAppState extends State<FoodLoopApp> {
  late final AuthBloc authBloc;
  late final NotificationBloc notificationBloc;
  late final UnreadMessagesCubit unreadMessagesCubit;
  late final PostFoodCubit postFoodCubit;
  late final AppRouter appRouter;

  @override
  void initState() {
    super.initState();
    authBloc = sl<AuthBloc>()..add(AuthUserChecked());
    notificationBloc = sl<NotificationBloc>();
    unreadMessagesCubit = sl<UnreadMessagesCubit>();
    
    // Safety fallback for hot reloads where auth stream didn't trigger again
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      notificationBloc.add(StartListeningToNotifications(user.uid));
      unreadMessagesCubit.startListening(user.uid);
    }
    postFoodCubit = sl<PostFoodCubit>();
    appRouter = AppRouter(authBloc);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authBloc),
        BlocProvider.value(value: postFoodCubit),
        BlocProvider.value(value: notificationBloc),
        BlocProvider.value(value: unreadMessagesCubit),
      ],child: ScreenUtilInit(
        designSize: const Size(375, 812), // Standard iPhone X dimension for scaling
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthAuthenticated) {
                notificationBloc.add(StartListeningToNotifications(state.user.uid));
                unreadMessagesCubit.startListening(state.user.uid);
              } else {
                // Stop listening for any other state (Unauthenticated, Initial, Loading, etc.)
                notificationBloc.add(const StopListeningToNotifications());
                unreadMessagesCubit.stopListening();
              }
            },
            child: MaterialApp.router(
            title: 'Food Loop',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primaryColor: AppColors.primaryGreen,
              scaffoldBackgroundColor: AppColors.offWhite,
              colorScheme: const ColorScheme.light(
                primary: AppColors.primaryGreen,
                secondary: AppColors.accentGreen,
                error: AppColors.errorRed,
              ),
              fontFamily: 'Poppins',
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                elevation: 0,
              ),
              textTheme: const TextTheme(
                displayLarge: TextStyle(color: AppColors.textDark),
                bodyLarge: TextStyle(color: AppColors.textDark),
                bodyMedium: TextStyle(color: AppColors.textDark),
                bodySmall: TextStyle(color: AppColors.textGrey),
              ),
            ),
            routerConfig: appRouter.router,
          ),
        );
      },
      ),
    );
  }
}
