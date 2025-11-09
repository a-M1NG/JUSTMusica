import 'package:get_it/get_it.dart';
import 'package:just_musica/services/database_service.dart';
import 'package:just_musica/services/favorites_service.dart';
import 'package:just_musica/services/playlist_service.dart';
import 'package:just_musica/services/music_scanner_service.dart';
import 'package:just_musica/services/playback_service.dart';
import 'package:just_musica/services/theme_service.dart';
import 'dart:async';

final GetIt serviceLocator = GetIt.instance;

/// 标记服务定位器是否已完全初始化
bool _isServiceLocatorReady = false;

/// 用于等待服务初始化的completer
final Completer<void> _initializationCompleter = Completer<void>();

/// 检查服务定位器是否已准备就绪
bool get isServiceLocatorReady => _isServiceLocatorReady;

/// 等待服务定位器初始化完成
Future<void> waitForServiceLocator() async {
  if (_isServiceLocatorReady) return;
  return _initializationCompleter.future;
}

/// 安全地获取服务实例，如果服务未就绪则等待
Future<T> getServiceAsync<T extends Object>() async {
  await waitForServiceLocator();
  if (serviceLocator.isRegistered<T>()) {
    return serviceLocator.getAsync<T>();
  }
  throw Exception('Service $T is not registered');
}

/// 尝试同步获取服务，如果未就绪返回null
T? tryGetService<T extends Object>() {
  if (!_isServiceLocatorReady) return null;
  if (!serviceLocator.isRegistered<T>()) return null;
  try {
    return serviceLocator<T>();
  } catch (e) {
    return null;
  }
}

/// 检查特定服务是否已就绪
Future<bool> isServiceReady<T extends Object>() async {
  if (!_isServiceLocatorReady) return false;
  if (!serviceLocator.isRegistered<T>()) return false;
  try {
    await serviceLocator.isReady<T>();
    return true;
  } catch (e) {
    return false;
  }
}

/// 初始化服务定位器，注册所有服务
Future<void> setupServiceLocator() async {
  if (_isServiceLocatorReady) {
    return; // 避免重复初始化
  }

  try {
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

    // 标记为已就绪
    _isServiceLocatorReady = true;
    if (!_initializationCompleter.isCompleted) {
      _initializationCompleter.complete();
    }
  } catch (e) {
    if (!_initializationCompleter.isCompleted) {
      _initializationCompleter.completeError(e);
    }
    rethrow;
  }
}
