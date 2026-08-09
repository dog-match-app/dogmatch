// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:dogmatch/app/di/register_module.dart' as _i496;
import 'package:dogmatch/core/network/auth_session_manager.dart' as _i838;
import 'package:dogmatch/core/network/file_uploader.dart' as _i416;
import 'package:dogmatch/core/network/socket_client.dart' as _i989;
import 'package:dogmatch/core/storage/token_storage.dart' as _i478;
import 'package:dogmatch/features/auth/data/repositories/auth_repository_impl.dart'
    as _i750;
import 'package:dogmatch/features/auth/domain/repositories/auth_repository.dart'
    as _i549;
import 'package:dogmatch/features/auth/presentation/bloc/auth_bloc.dart'
    as _i190;
import 'package:dogmatch/features/auth/presentation/cubit/login_cubit.dart'
    as _i967;
import 'package:dogmatch/features/auth/presentation/cubit/register_cubit.dart'
    as _i218;
import 'package:dogmatch/features/chat/data/repositories/chat_repository_impl.dart'
    as _i454;
import 'package:dogmatch/features/chat/domain/repositories/chat_repository.dart'
    as _i190;
import 'package:dogmatch/features/chat/presentation/cubit/chat_cubit.dart'
    as _i203;
import 'package:dogmatch/features/discovery/data/repositories/discovery_repository_impl.dart'
    as _i893;
import 'package:dogmatch/features/discovery/domain/repositories/discovery_repository.dart'
    as _i557;
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart'
    as _i230;
import 'package:dogmatch/features/discovery/presentation/cubit/discovery_cubit.dart'
    as _i290;
import 'package:dogmatch/features/dogs/data/repositories/dog_posts_repository_impl.dart'
    as _i681;
import 'package:dogmatch/features/dogs/data/repositories/dog_repository_impl.dart'
    as _i184;
import 'package:dogmatch/features/dogs/domain/repositories/dog_posts_repository.dart'
    as _i564;
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart'
    as _i1052;
import 'package:dogmatch/features/dogs/presentation/cubit/dog_post_composer_cubit.dart'
    as _i209;
import 'package:dogmatch/features/dogs/presentation/cubit/dog_posts_cubit.dart'
    as _i815;
import 'package:dogmatch/features/dogs/presentation/cubit/my_dogs_cubit.dart'
    as _i691;
import 'package:dogmatch/features/matches/data/repositories/match_repository_impl.dart'
    as _i491;
import 'package:dogmatch/features/matches/domain/repositories/match_repository.dart'
    as _i19;
import 'package:dogmatch/features/matches/presentation/cubit/matches_cubit.dart'
    as _i623;
import 'package:dogmatch/features/owners/data/repositories/owners_repository_impl.dart'
    as _i318;
import 'package:dogmatch/features/owners/domain/repositories/owners_repository.dart'
    as _i638;
import 'package:dogmatch/features/owners/presentation/cubit/owner_profile_cubit.dart'
    as _i496;
import 'package:dogmatch/features/profile/data/repositories/profile_repository_impl.dart'
    as _i302;
import 'package:dogmatch/features/profile/domain/repositories/profile_repository.dart'
    as _i854;
import 'package:dogmatch/features/profile/presentation/cubit/profile_cubit.dart'
    as _i417;
import 'package:dogmatch/features/search/data/repositories/search_repository_impl.dart'
    as _i687;
import 'package:dogmatch/features/search/domain/repositories/search_repository.dart'
    as _i984;
import 'package:dogmatch/features/search/presentation/cubit/dog_detail_cubit.dart'
    as _i996;
import 'package:dogmatch/features/search/presentation/cubit/search_cubit.dart'
    as _i832;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => registerModule.secureStorage,
    );
    gh.lazySingleton<_i989.SocketClient>(() => registerModule.socketClient);
    gh.lazySingleton<_i838.AuthSessionManager>(
      () => _i838.AuthSessionManager(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i478.TokenStorage>(
      () => _i478.TokenStorage(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i361.Dio>(
      () => registerModule.dio(
        gh<_i478.TokenStorage>(),
        gh<_i838.AuthSessionManager>(),
      ),
    );
    gh.lazySingleton<_i638.OwnersRepository>(
      () => _i318.OwnersRepositoryImpl(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i564.DogPostsRepository>(
      () => _i681.DogPostsRepositoryImpl(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i190.ChatRepository>(
      () => _i454.ChatRepositoryImpl(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i984.SearchRepository>(
      () => _i687.SearchRepositoryImpl(gh<_i361.Dio>()),
    );
    gh.factory<_i815.DogPostsCubit>(
      () => _i815.DogPostsCubit(gh<_i564.DogPostsRepository>()),
    );
    gh.lazySingleton<_i19.MatchRepository>(
      () => _i491.MatchRepositoryImpl(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i416.FileUploader>(
      () => _i416.FileUploader(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i557.DiscoveryRepository>(
      () => _i893.DiscoveryRepositoryImpl(gh<_i361.Dio>()),
    );
    gh.factory<_i496.OwnerProfileCubit>(
      () => _i496.OwnerProfileCubit(gh<_i638.OwnersRepository>()),
    );
    gh.lazySingleton<_i549.AuthRepository>(
      () => _i750.AuthRepositoryImpl(gh<_i361.Dio>(), gh<_i478.TokenStorage>()),
    );
    gh.lazySingleton<_i190.AuthBloc>(
      () => _i190.AuthBloc(
        gh<_i549.AuthRepository>(),
        gh<_i838.AuthSessionManager>(),
        gh<_i989.SocketClient>(),
      ),
    );
    gh.lazySingleton<_i1052.DogRepository>(
      () => _i184.DogRepositoryImpl(gh<_i361.Dio>(), gh<_i416.FileUploader>()),
    );
    gh.lazySingleton<_i854.ProfileRepository>(
      () => _i302.ProfileRepositoryImpl(
        gh<_i361.Dio>(),
        gh<_i416.FileUploader>(),
      ),
    );
    gh.factory<_i203.ChatCubit>(
      () => _i203.ChatCubit(
        gh<_i190.ChatRepository>(),
        gh<_i19.MatchRepository>(),
        gh<_i989.SocketClient>(),
        gh<_i478.TokenStorage>(),
        gh<_i190.AuthBloc>(),
      ),
    );
    gh.factory<_i967.LoginCubit>(
      () => _i967.LoginCubit(gh<_i549.AuthRepository>(), gh<_i190.AuthBloc>()),
    );
    gh.factory<_i218.RegisterCubit>(
      () =>
          _i218.RegisterCubit(gh<_i549.AuthRepository>(), gh<_i190.AuthBloc>()),
    );
    gh.factory<_i209.DogPostComposerCubit>(
      () => _i209.DogPostComposerCubit(
        gh<_i564.DogPostsRepository>(),
        gh<_i416.FileUploader>(),
      ),
    );
    gh.lazySingleton<_i230.ActiveDogCubit>(
      () => _i230.ActiveDogCubit(gh<_i1052.DogRepository>()),
    );
    gh.factory<_i417.ProfileCubit>(
      () => _i417.ProfileCubit(gh<_i854.ProfileRepository>()),
    );
    gh.factory<_i691.MyDogsCubit>(
      () => _i691.MyDogsCubit(
        gh<_i1052.DogRepository>(),
        gh<_i230.ActiveDogCubit>(),
      ),
    );
    gh.factory<_i290.DiscoveryCubit>(
      () => _i290.DiscoveryCubit(
        gh<_i557.DiscoveryRepository>(),
        gh<_i230.ActiveDogCubit>(),
      ),
    );
    gh.factory<_i996.DogDetailCubit>(
      () => _i996.DogDetailCubit(
        gh<_i1052.DogRepository>(),
        gh<_i557.DiscoveryRepository>(),
        gh<_i19.MatchRepository>(),
        gh<_i230.ActiveDogCubit>(),
      ),
    );
    gh.factory<_i623.MatchesCubit>(
      () => _i623.MatchesCubit(
        gh<_i19.MatchRepository>(),
        gh<_i230.ActiveDogCubit>(),
      ),
    );
    gh.factory<_i832.SearchCubit>(
      () => _i832.SearchCubit(
        gh<_i984.SearchRepository>(),
        gh<_i230.ActiveDogCubit>(),
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i496.RegisterModule {}
