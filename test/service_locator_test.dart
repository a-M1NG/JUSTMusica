import 'package:flutter_test/flutter_test.dart';
import 'package:just_musica/services/service_locator.dart';
import 'package:just_musica/services/playback_service.dart';
import 'package:just_musica/services/theme_service.dart';
import 'package:just_musica/services/playlist_service.dart';
import 'package:just_musica/services/favorites_service.dart';
import 'package:just_musica/services/database_service.dart';

void main() {
  group('Service Locator Tests', () {
    setUp(() async {
      // Reset service locator between tests if needed
      if (serviceLocator.isRegistered<DatabaseService>()) {
        await serviceLocator.reset();
      }
    });

    test('Service locator initializes successfully', () async {
      // Initialize database first
      DatabaseService.init();
      
      // Setup service locator
      await setupServiceLocator();
      
      // Verify service locator is ready
      expect(isServiceLocatorReady, true);
    });

    test('waitForServiceLocator completes after initialization', () async {
      // Initialize database first
      DatabaseService.init();
      
      // Setup service locator
      await setupServiceLocator();
      
      // This should complete immediately since services are ready
      await expectLater(
        waitForServiceLocator(),
        completes,
      );
    });

    test('Synchronous services are accessible after initialization', () async {
      DatabaseService.init();
      await setupServiceLocator();
      
      // Test synchronous services
      expect(() => serviceLocator<PlaybackService>(), returnsNormally);
      expect(() => serviceLocator<ThemeService>(), returnsNormally);
    });

    test('Async services are accessible after initialization', () async {
      DatabaseService.init();
      await setupServiceLocator();
      
      // Test async services
      expect(isServiceReady<PlaylistService>(), true);
      expect(isServiceReady<FavoritesService>(), true);
      
      // Services should be accessible
      expect(() => serviceLocator<PlaylistService>(), returnsNormally);
      expect(() => serviceLocator<FavoritesService>(), returnsNormally);
    });

    test('getServiceAsync works for async services', () async {
      DatabaseService.init();
      await setupServiceLocator();
      
      // Get async service
      final playlistService = await getServiceAsync<PlaylistService>();
      expect(playlistService, isNotNull);
      expect(playlistService, isA<PlaylistService>());
    });

    test('tryGetService returns null before initialization', () {
      // Don't initialize - test behavior before ready
      expect(tryGetService<PlaybackService>(), isNull);
    });

    test('isServiceReady returns false before initialization', () {
      // Don't initialize - test behavior before ready
      expect(isServiceReady<PlaybackService>(), false);
    });
  });
}
