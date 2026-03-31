// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:cloud_functions/cloud_functions.dart' as _i809;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:firebase_messaging/firebase_messaging.dart' as _i892;
import 'package:firebase_storage/firebase_storage.dart' as _i457;
import 'package:food_loop/core/notifications/notification_service.dart'
    as _i365;
import 'package:food_loop/features/auth/data/datasources/auth_remote_data_source.dart'
    as _i471;
import 'package:food_loop/features/auth/data/repositories/auth_repository_impl.dart'
    as _i960;
import 'package:food_loop/features/auth/domain/repositories/auth_repository.dart'
    as _i712;
import 'package:food_loop/features/auth/presentation/bloc/auth_bloc.dart'
    as _i676;
import 'package:food_loop/features/chat/data/chat_remote_data_source.dart'
    as _i1065;
import 'package:food_loop/features/chat/data/chat_repository.dart' as _i428;
import 'package:food_loop/features/chat/presentation/bloc/chat_bloc.dart'
    as _i906;
import 'package:food_loop/features/chat/presentation/bloc/chat_list_bloc.dart'
    as _i838;
import 'package:food_loop/features/chat/presentation/bloc/unread_messages_cubit.dart'
    as _i999;
import 'package:food_loop/features/expiry_tracker/data/repositories/expiry_tracker_repository.dart'
    as _i775;
import 'package:food_loop/features/expiry_tracker/presentation/bloc/expiry_tracker_cubit.dart'
    as _i523;
import 'package:food_loop/features/feed/data/datasources/feed_remote_data_source.dart'
    as _i607;
import 'package:food_loop/features/feed/data/repositories/feed_repository_impl.dart'
    as _i736;
import 'package:food_loop/features/feed/domain/repositories/feed_repository.dart'
    as _i385;
import 'package:food_loop/features/feed/presentation/bloc/feed_bloc.dart'
    as _i203;
import 'package:food_loop/features/notifications/data/repositories/notification_repository.dart'
    as _i332;
import 'package:food_loop/features/notifications/presentation/bloc/notification_bloc.dart'
    as _i731;
import 'package:food_loop/features/post_food/presentation/bloc/post_food_cubit.dart'
    as _i5;
import 'package:food_loop/features/profile/data/profile_repository.dart'
    as _i824;
import 'package:food_loop/features/profile/presentation/bloc/profile_bloc.dart'
    as _i291;
import 'package:food_loop/features/ratings/data/repositories/rating_repository.dart'
    as _i653;
import 'package:food_loop/features/ratings/presentation/bloc/rating_bloc.dart'
    as _i97;
import 'package:food_loop/features/search/data/repositories/search_repository.dart'
    as _i280;
import 'package:food_loop/features/search/presentation/bloc/search_bloc.dart'
    as _i447;
import 'package:food_loop/injection_container.dart' as _i262;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final firebaseModule = _$FirebaseModule();
    gh.lazySingleton<_i5.PostFoodCubit>(() => _i5.PostFoodCubit());
    gh.lazySingleton<_i59.FirebaseAuth>(() => firebaseModule.firebaseAuth);
    gh.lazySingleton<_i974.FirebaseFirestore>(
      () => firebaseModule.firebaseFirestore,
    );
    gh.lazySingleton<_i457.FirebaseStorage>(
      () => firebaseModule.firebaseStorage,
    );
    gh.lazySingleton<_i809.FirebaseFunctions>(
      () => firebaseModule.firebaseFunctions,
    );
    gh.lazySingleton<_i892.FirebaseMessaging>(
      () => firebaseModule.firebaseMessaging,
    );
    gh.lazySingleton<_i653.RatingRepository>(
      () => _i653.RatingRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i809.FirebaseFunctions>(),
      ),
    );
    gh.lazySingleton<_i365.NotificationService>(
      () => _i365.NotificationService(gh<_i892.FirebaseMessaging>()),
    );
    gh.factory<_i97.RatingBloc>(
      () => _i97.RatingBloc(gh<_i653.RatingRepository>()),
    );
    gh.lazySingleton<_i471.AuthRemoteDataSource>(
      () => _i471.AuthRemoteDataSourceImpl(
        gh<_i59.FirebaseAuth>(),
        gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.lazySingleton<_i712.AuthRepository>(
      () => _i960.AuthRepositoryImpl(gh<_i471.AuthRemoteDataSource>()),
    );
    gh.lazySingleton<_i1065.ChatRemoteDataSource>(
      () => _i1065.ChatRemoteDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i775.ExpiryTrackerRepository>(
      () => _i775.ExpiryTrackerRepository(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i332.NotificationRepository>(
      () => _i332.NotificationRepository(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i280.SearchRepository>(
      () => _i280.SearchRepository(gh<_i974.FirebaseFirestore>()),
    );
    gh.factory<_i676.AuthBloc>(
      () => _i676.AuthBloc(gh<_i712.AuthRepository>()),
    );
    gh.factory<_i447.SearchBloc>(
      () => _i447.SearchBloc(gh<_i280.SearchRepository>()),
    );
    gh.lazySingleton<_i824.ProfileRepository>(
      () => _i824.ProfileRepository(
        gh<_i974.FirebaseFirestore>(),
        gh<_i457.FirebaseStorage>(),
      ),
    );
    gh.factory<_i291.ProfileBloc>(
      () => _i291.ProfileBloc(
        gh<_i824.ProfileRepository>(),
        gh<_i676.AuthBloc>(),
      ),
    );
    gh.lazySingleton<_i607.FeedRemoteDataSource>(
      () => _i607.FeedRemoteDataSourceImpl(gh<_i974.FirebaseFirestore>()),
    );
    gh.factory<_i523.ExpiryTrackerCubit>(
      () => _i523.ExpiryTrackerCubit(gh<_i775.ExpiryTrackerRepository>()),
    );
    gh.lazySingleton<_i731.NotificationBloc>(
      () => _i731.NotificationBloc(gh<_i332.NotificationRepository>()),
    );
    gh.lazySingleton<_i428.ChatRepository>(
      () => _i428.ChatRepository(gh<_i1065.ChatRemoteDataSource>()),
    );
    gh.lazySingleton<_i385.FeedRepository>(
      () => _i736.FeedRepositoryImpl(gh<_i607.FeedRemoteDataSource>()),
    );
    gh.factory<_i203.FeedBloc>(
      () => _i203.FeedBloc(gh<_i385.FeedRepository>()),
    );
    gh.factory<_i906.ChatBloc>(
      () => _i906.ChatBloc(gh<_i428.ChatRepository>()),
    );
    gh.factory<_i838.ChatListBloc>(
      () => _i838.ChatListBloc(gh<_i428.ChatRepository>()),
    );
    gh.factory<_i999.UnreadMessagesCubit>(
      () => _i999.UnreadMessagesCubit(gh<_i428.ChatRepository>()),
    );
    return this;
  }
}

class _$FirebaseModule extends _i262.FirebaseModule {}
