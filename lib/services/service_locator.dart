import 'package:get_it/get_it.dart';
import 'package:just_musica/services/database_service.dart';
import 'package:just_musica/services/favorites_service.dart';
import 'package:just_musica/services/playlist_service.dart';
import 'package:just_musica/services/music_scanner_service.dart';
import 'package:just_musica/services/playback_service.dart';
import 'package:just_musica/services/theme_service.dart';

final GetIt serviceLocator = GetIt.instance;

/// 初始化服务定位器，注册所有服务
Future<void> setupServiceLocator() async {
  // 注册数据库服务（单例，懒加载）
  serviceLocator.registerLazySingleton<DatabaseService>(
    () => DatabaseService(),
  );

  // 注册 FavoritesService（单例，需要数据库实例）
  serviceLocator.registerLazySingletonAsync<FavoritesService>(
    () async {
      final db = await serviceLocator<DatabaseService>().database;
      return FavoritesService(db);
    },
  );

  // 注册 PlaylistService（单例，需要数据库实例）
  serviceLocator.registerLazySingletonAsync<PlaylistService>(
    () async {
      final db = await serviceLocator<DatabaseService>().database;
      return PlaylistService(db);
    },
  );

  // 注册 MusicScannerService（单例）
  serviceLocator.registerLazySingleton<MusicScannerService>(
    () => MusicScannerService(),
  );

  // 注册 PlaybackService（单例）
  serviceLocator.registerLazySingleton<PlaybackService>(
    () => PlaybackService(),
  );

  // 注册 ThemeService（单例）
  serviceLocator.registerLazySingleton<ThemeService>(
    () => ThemeService(),
  );

  // 等待异步依赖初始化完成
  await serviceLocator.allReady();
}
