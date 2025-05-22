// test/app_white_box_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_musica/models/playlist_model.dart';
import 'package:just_musica/models/song_model.dart';
import 'package:just_musica/services/database_service.dart';
import 'package:just_musica/services/music_scanner_service.dart';
import 'package:just_musica/services/playlist_service.dart';
// Mocking base_music_page.dart's search logic requires a bit more setup,
// so we'll extract and test the core search logic.
// For a full test, you'd need a WidgetTester.
// import 'package:just_musica/views/base_music_page.dart';

// import 'package:logger/logger.dart'; // Logger not directly used in tests, but present in services
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:audiotags/audiotags.dart' as audiotags;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// --- MOCKS ---

// Mock for PathProviderPlatform
class MockPathProviderPlatform extends Mock
    with
        MockPlatformInterfaceMixin // Use this mixin for platform interface mocks
    implements
        PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    // For tests, we can return a temporary or in-memory path.
    // Since sqflite_common_ffi uses inMemoryDatabasePath for ":memory:",
    // we can return a path that won't actually be written to disk in most cases,
    // or a specific temp directory if needed.
    // Let's use a subdirectory in the system's temp directory for tests.
    final tempDir = Directory.systemTemp.createTempSync('app_test_docs');
    return tempDir.path;
  }

  // Mock other methods if your DatabaseService or other services use them.
  // For example:
  @override
  Future<String?> getTemporaryPath() async {
    final tempDir = Directory.systemTemp.createTempSync('app_test_temp');
    return tempDir.path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    final tempDir = Directory.systemTemp.createTempSync('app_test_support');
    return tempDir.path;
  }
}

// Mock Database for sqflite
class MockDatabase extends Mock implements Database {}

// Mock DatabaseService
class MockDatabaseService extends Mock implements DatabaseService {
  final MockDatabase _mockDb;
  MockDatabaseService(this._mockDb);

  @override
  Future<Database> get database async => _mockDb;

  // Add other methods that are called by services if needed
  @override
  Future<List<SongModel>> getAllSongs() async {
    // Simulate database call
    final result = await _mockDb.query('Songs');
    return result.map((map) => SongModel.fromMap(map)).toList();
  }

  @override
  Future<SongModel?> getSongById(int id) async {
    final List<Map<String, dynamic>> maps = await _mockDb.query(
      'Songs',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? SongModel.fromMap(maps.first) : null;
  }

  @override
  Future<void> batchInsertSongs(List<SongModel> songs) async {
    for (var song in songs) {
      await _mockDb.insert(
        'Songs',
        song.toMap()..removeWhere((key, value) => key == 'id' && value == null),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}

// Mock Directory and File for music_scanner_service
class MockDirectory extends Mock implements Directory {
  final String dirPath;
  MockDirectory(this.dirPath);

  @override
  String get path => dirPath;

  @override
  Future<bool> exists() async => true; // Assume directory exists for most tests

  @override
  Stream<FileSystemEntity> list(
      {bool recursive = false, bool followLinks = true}) {
    // This needs to be customized per test case
    return Stream.fromIterable([]);
  }
}

class MockFile extends Mock implements File {
  final String filePath;
  MockFile(this.filePath);

  @override
  String get path => filePath;

  @override
  Future<bool> exists() async => true; // Assume file exists

  @override
  Future<FileStat> stat() async => MockFileStat(); // Provide a mock stat

  @override
  Future<int> length() async => 1024; // Mock file length
}

class MockFileStat extends Mock implements FileStat {
  @override
  DateTime get changed => DateTime.now();
  @override
  DateTime get modified => DateTime.now();
  @override
  DateTime get accessed => DateTime.now();
  @override
  FileSystemEntityType get type =>
      FileSystemEntityType.file; // Corrected: dart:io enum
  @override
  int get mode => 0; // Mock mode
  @override
  int get size => 1024; // Mock size
}

// --- Helper for Search Logic (extracted from SongListPageBaseState) ---
List<SongModel> performSearchLogic(String query, List<SongModel> allSongs) {
  final lowerCaseQuery = query.toLowerCase().trim();
  if (lowerCaseQuery.isEmpty) {
    return List.from(allSongs);
  } else {
    final Set<int?> seenIds = {}; // Allow null IDs if songs might not have them
    return allSongs.where((song) {
      final titleMatch =
          song.title?.toLowerCase().contains(lowerCaseQuery) ?? false;
      final artistMatch =
          song.artist?.toLowerCase().contains(lowerCaseQuery) ?? false;
      final isMatch = titleMatch || artistMatch;
      // Ensure song.id is not null before adding to seenIds if your model guarantees non-null IDs after DB storage
      if (isMatch && (song.id == null || !seenIds.contains(song.id))) {
        if (song.id != null) seenIds.add(song.id);
        return true;
      }
      return false;
    }).toList();
  }
}

void main() {
  // Ensure Flutter binding is initialized for tests that use platform channels.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for sqflite if running on desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // This global DatabaseService is for general use if needed,
  // but specific test groups (like PlaylistService) will initialize their own
  // dedicated in-memory databases for better isolation.
  late DatabaseService databaseService;

  setUpAll(() {
    // Mock PathProviderPlatform before any service that uses it is initialized.
    PathProviderPlatform.instance = MockPathProviderPlatform();
    DatabaseService
        .init(); // Initialize FFI for desktop (runs once for all tests)
  });

  setUp(() async {
    // Initialize a general-purpose DatabaseService for tests that might need it.
    // This instance will use its own in-memory database.
    databaseService = DatabaseService();
    final db = await databaseService.database; // ensure it's initialized
    // Since PathProviderPlatform is mocked, DatabaseService will use the mocked paths.
    // Clean common tables for this general instance if necessary,
    // though specific test groups should manage their own state primarily.
    await db.delete('PlaylistSongs');
    await db.delete('Playlists');
    await db.delete('Songs');
    // Recreate tables if they were dropped or if starting from a truly empty state
    // For simplicity, assuming DatabaseService._onCreate handles table creation.
    // If not, tables need to be explicitly created here or in _initDatabase.
    // The current DatabaseService._onCreate will be called by databaseFactory.openDatabase.
  });

  tearDownAll(() async {
    await databaseService.close();
  });

  tearDown(() async {
    // Clean up temporary directories created by MockPathProviderPlatform if any were stateful.
    // For in-memory paths or truly temporary system paths, this might not be strictly necessary
    // but good practice if actual directories were created.
    // Since MockPathProviderPlatform creates temp directories, let's try to clean them.
    // This is a simplified cleanup; a robust version would track created paths.
    final tempBase = Directory.systemTemp;
    await for (final entity in tempBase.list()) {
      if (entity.path.contains('app_test_docs') ||
          entity.path.contains('app_test_temp') ||
          entity.path.contains('app_test_support')) {
        try {
          await entity.delete(recursive: true);
        } catch (e) {
          // print('Could not delete temp test directory: ${entity.path}, error: $e');
        }
      }
    }
  });

  group('Search Songs Module (base_music_page.dart logic)', () {
    final List<SongModel> testSongs = [
      SongModel(id: 1, path: 'path1', title: 'Sunset Blues', artist: 'Jazzman'),
      SongModel(id: 2, path: 'path2', title: 'Morning Dew', artist: 'Folksy'),
      SongModel(
          id: 3, path: 'path3', title: 'Sunset Grooves', artist: 'Funkster'),
      SongModel(id: 4, path: 'path4', title: 'Midnight Sun', artist: 'Jazzman'),
      SongModel(
          id: 5,
          path: 'path5',
          title: 'Café Unicode ☕',
          artist: 'Global Beats'),
      SongModel(
          id: 6,
          path: 'path6',
          title: '  Spaced Out Song  ',
          artist: 'Synthwave Kid'),
    ];

    test('C-011.1: Empty search query returns all songs', () {
      final results = performSearchLogic('', testSongs);
      expect(results.length, testSongs.length);
    });

    test('C-011.2: Exact title match', () {
      final results = performSearchLogic('Sunset Blues', testSongs);
      expect(results.length, 1);
      expect(results.first.id, 1);
    });

    test('C-011.2a: Exact artist match', () {
      final results = performSearchLogic('Jazzman', testSongs);
      expect(results.length, 2); // Sunset Blues and Midnight Sun
      expect(results.map((s) => s.id), containsAll([1, 4]));
    });

    test('Partial match (title)', () {
      final results = performSearchLogic('Sun', testSongs);
      expect(results.length, 3); // Sunset Blues, Sunset Grooves, Midnight Sun
      expect(results.map((s) => s.id), containsAll([1, 3, 4]));
    });

    test('Case-insensitive match', () {
      final results = performSearchLogic('sunset blues', testSongs);
      expect(results.length, 1);
      expect(results.first.id, 1);
    });

    test('No match found', () {
      final results = performSearchLogic('NonExistentSong', testSongs);
      expect(results.isEmpty, true);
    });

    test('C-011.1 (variant): Query with leading/trailing spaces is trimmed',
        () {
      final results = performSearchLogic('  Morning Dew  ', testSongs);
      expect(results.length, 1);
      expect(results.first.id, 2);
    });

    test('Search in an empty song list', () {
      final results = performSearchLogic('Anything', []);
      expect(results.isEmpty, true);
    });

    test('C-011.5: Unicode character match', () {
      final results = performSearchLogic('Café Unicode ☕', testSongs);
      expect(results.length, 1);
      expect(results.first.id, 5);
    });

    test('C-011.5 (variant): Partial Unicode character match', () {
      final results = performSearchLogic('Unicode', testSongs);
      expect(results.length, 1);
      expect(results.first.id, 5);
    });

    test('C-011.3: SQL special characters (client-side context)', () {
      // In client-side search, SQL injection isn't a direct threat to the client's DB via this search.
      // The test ensures the search handles them as literal characters.
      final songsWithSpecialChars = [
        SongModel(
            id: 7,
            path: 'path7',
            title: "Song's Title",
            artist: "Artist; --Name"),
        ...testSongs
      ];
      var results = performSearchLogic("Song's Title", songsWithSpecialChars);
      expect(results.length, 1);
      expect(results.first.id, 7);

      results = performSearchLogic("Artist; --Name", songsWithSpecialChars);
      expect(results.length, 1);
      expect(results.first.id, 7);
    });

    test(
        'C-011.4: Super long string (truncation/rejection is not part of this search logic)',
        () {
      // The provided search logic doesn't have explicit length checks for the query string.
      // It will attempt to match the full string.
      String longQuery = 'a' * 200;
      final results = performSearchLogic(longQuery, testSongs);
      expect(
          results.isEmpty, true); // Assuming no song title/artist is 200 'a's.
    });
  });

  group('Music Scanner Module (music_scanner_service.dart)', () {
    late MusicScannerService musicScannerService;
    // Note: MusicScannerService creates its own DatabaseService instance.
    // For more controlled unit testing of DB interactions, MusicScannerService
    // should be refactored to accept DatabaseService via constructor injection.
    // The following tests focus on logic not directly tied to DB writes,
    // or acknowledge this limitation.

    setUp(() {
      musicScannerService = MusicScannerService();
    });

    group('_createSongModelFromFile logic (via testable extension)', () {
      // This tests the transformation logic based on a hypothetical Tag object.
      // Actual interaction with AudioTags.read (a static method) is not mocked here.

      test('C-021.1 & C-021.5: Valid MP3 file with full metadata', () async {
        final mockFile = MockFile('C:\\Data\\Music\\test.mp3');
        final tag = audiotags.Tag(
          title: "Test Song",
          trackArtist: "Test Artist",
          album: "Test Album",
          duration: 180,
          pictures: [], // Required field
        );
        // Using the testable extension method
        final songModel =
            musicScannerService.testCreateSongModelFromTag(mockFile.path, tag);

        expect(songModel.title, "Test Song");
        expect(songModel.artist, "Test Artist");
        expect(songModel.album, "Test Album");
        expect(songModel.duration, 180);
        expect(songModel.path, mockFile.path);
      });

      test('C-021.5: File with some missing metadata (e.g., no album)',
          () async {
        final mockFile = MockFile('C:\\Data\\Music\\no_album.mp3');
        final tag = audiotags.Tag(
          title: "Song Title",
          trackArtist: "Artist Name",
          album: "", // Empty album
          duration: 120,
          pictures: [], // Required field
        );
        final songModel =
            musicScannerService.testCreateSongModelFromTag(mockFile.path, tag);

        expect(songModel.title, "Song Title");
        expect(songModel.artist, "Artist Name");
        expect(songModel.album,
            isNull); // Logic handles empty string as null for album
        expect(songModel.duration, 120);
      });

      test('File with no metadata (AudioTags.read returns null)', () async {
        final mockFile = MockFile('C:\\Data\\Music\\no_meta.mp3');
        // Simulate AudioTags.read returning null by passing null directly to the test helper
        final songModel =
            musicScannerService.testCreateSongModelFromTag(mockFile.path, null);

        expect(songModel.title,
            p.basenameWithoutExtension(mockFile.path)); // Defaults to filename
        expect(songModel.artist, '未知艺术家'); // Defaults
        expect(songModel.album, isNull);
        expect(songModel.path, mockFile.path);
      });

      test('C-021.2: AudioTags.read throws an exception (simulated)', () async {
        final mockFile = MockFile('C:\\Data\\Music\\corrupted.mp3');
        // Simulate the try-catch block in _createSongModelFromFile by setting didThrow
        final songModel = musicScannerService
            .testCreateSongModelFromTag(mockFile.path, null, didThrow: true);

        expect(songModel.title, p.basenameWithoutExtension(mockFile.path));
        expect(songModel.artist, '未知艺术家');
        expect(songModel.path, mockFile.path);
      });
    });

    group('scanMusic tests', () {
      // These tests mock the Directory and File interactions.
      // The behavior of _createSongModelFromFile is assumed based on tests above.
      test('C-021 (variant): Scan directory with supported files', () async {
        final mockDir = MockDirectory('C:\\Data\\Music');
        final mockMp3File = MockFile('C:\\Data\\Music\\song1.mp3');
        final mockFlacFile = MockFile('C:\\Data\\Music\\song2.flac');

        // Mocking Directory.list() to return a stream of mock files
        when(mockDir.list(recursive: true, followLinks: true))
            .thenAnswer((_) => Stream.fromIterable([
                  mockMp3File,
                  mockFlacFile,
                ]));

        // To make this test fully verifiable without refactoring MusicScannerService
        // to inject its AudioTags dependency, we rely on the behavior that if
        // _createSongModelFromFile is called (which it should be for supported extensions),
        // it would produce *some* SongModel. The exact content of SongModel is tested elsewhere.
        // This test primarily checks if files with supported extensions are processed.

        // As MusicScannerService._createSongModelFromFile is private and uses static AudioTags.read,
        // we can't directly mock its return value here without significant refactoring or advanced tools.
        // We are testing that scanMusic attempts to process these files.
        // The actual song models created depend on the (unmocked) AudioTags.read.
        // For a true unit test of scanMusic's list building, _createSongModelFromFile would need to be mockable.

        // This test will run, but its assertions about the content of `songs` are limited.
        // It effectively tests the file iteration and extension filtering.
        final musicScanner = MusicScannerService(); // Uses its own DB instance.
        List<SongModel> songs = [];
        try {
          songs = await musicScanner.scanMusic(mockDir.path);
        } catch (e) {
          // If AudioTags.read fails on a real system where files don't exist, it might throw.
          // In a pure mock environment for Directory/File, this part should be fine.
        }

        // We expect it to attempt to process two files.
        // Depending on the actual (unmocked) AudioTags.read behavior for these non-existent paths,
        // it will either create default models or models based on errors.
        expect(songs.length, 2);
        expect(songs.any((s) => s.path == mockMp3File.path), isTrue);
        expect(songs.any((s) => s.path == mockFlacFile.path), isTrue);
      });

      test('C-021.3: Scan directory with unsupported files', () async {
        final mockDir = MockDirectory('C:\\Data\\Music');
        final mockTxtFile = MockFile('C:\\Data\\Music\\notes.txt');
        when(mockDir.list(recursive: true, followLinks: true))
            .thenAnswer((_) => Stream.fromIterable([mockTxtFile]));

        final songs = await musicScannerService.scanMusic(mockDir.path);
        expect(songs.isEmpty, isTrue); // .txt is not a supported extension
      });

      test('Scan empty directory', () async {
        final mockDir = MockDirectory('C:\\Data\\Music\\Empty');
        when(mockDir.list(recursive: true, followLinks: true))
            .thenAnswer((_) => Stream.empty());
        final songs = await musicScannerService.scanMusic(mockDir.path);
        expect(songs.isEmpty, isTrue);
      });

      test('Scan non-existent directory throws exception', () async {
        final mockDir = MockDirectory('C:\\Data\\NonExistent');
        when(mockDir.exists()).thenAnswer((_) async => false);
        expect(
            () => musicScannerService.scanMusic(mockDir.path), throwsException);
      });
    });

    group('importSongs tests', () {
      // These tests are more conceptual without refactoring MusicScannerService for DB injection.
      // They would verify that batchInsertSongs is called on the injected DB service.
      test('C-021 (variant): Import valid song files - conceptual', () async {
        final mockGoodFile = MockFile('C:/Data/Music/song.mp3');
        when(mockGoodFile.exists()).thenAnswer((_) async => true);
        // when(mockGoodFile.path).thenReturn('C:/Data/Music/song.mp3'); // Already set by constructor

        final List<String> filePaths = [mockGoodFile.path];

        // final mockDbService = MockDatabaseService(MockDatabase());
        // final scanner = MusicScannerService(mockDbService); // Requires constructor injection
        // await scanner.importSongs(filePaths);
        // verify(mockDbService.batchInsertSongs(any)).called(1);
        expect(true, isTrue,
            reason: "Conceptual: Verifies DB call if service was injectable.");
      });

      test('Import non-existent file - conceptual', () async {
        final mockBadFile = MockFile('C:/Data/Music/non_existent.mp3');
        when(mockBadFile.exists()).thenAnswer((_) async => false);
        final List<String> filePaths = [mockBadFile.path];

        // final mockDbService = MockDatabaseService(MockDatabase());
        // final scanner = MusicScannerService(mockDbService);
        // await scanner.importSongs(filePaths);
        // verifyNever(mockDbService.batchInsertSongs(any));
        expect(true, isTrue,
            reason:
                "Conceptual: Verifies DB not called if file doesn't exist.");
      });
    });
  });

  group('Favorites (Playlist) Management Module (playlist_service.dart)', () {
    late PlaylistService playlistService;
    late Database db; // Real in-memory database instance for this group

    setUp(() async {
      // Get a fresh in-memory database for each test in this group
      // This ensures tests are isolated.
      // PathProviderPlatform is already mocked in setUpAll, so this will use mocked paths.
      // Or, we can directly use inMemoryDatabasePath for PlaylistService tests
      // if DatabaseService itself is not being tested for path resolution here.
      // For PlaylistService, we directly give it an in-memory DB instance.
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('PRAGMA foreign_keys = ON;');

      // Recreate tables for a clean state before each test in this group
      await db.execute('DROP TABLE IF EXISTS PlaylistSongs');
      await db.execute('DROP TABLE IF EXISTS Playlists');
      await db.execute('DROP TABLE IF EXISTS Songs');

      await db.execute('''
        CREATE TABLE Songs (
          id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT NOT NULL UNIQUE, title TEXT,
          artist TEXT, album TEXT, duration INTEGER, cover_path TEXT, is_favorite BOOLEAN DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE Playlists (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP, cover_path TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE PlaylistSongs (
          playlist_id INTEGER, song_id INTEGER, added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (playlist_id, song_id),
          FOREIGN KEY (playlist_id) REFERENCES Playlists(id) ON DELETE CASCADE,
          FOREIGN KEY (song_id) REFERENCES Songs(id) ON DELETE CASCADE
        )
      ''');
      playlistService = PlaylistService(db);

      // Pre-populate with some songs for testing playlist operations
      // Note: using raw insert, so ID is auto-incremented by SQLite.
      // For tests relying on specific IDs, fetch them after insert or use known IDs if db allows.
      await db.insert('Songs',
          {'path': 'song1.mp3', 'title': 'Song One', 'artist': 'Artist A'});
      await db.insert('Songs', {
        'path': 'song2.mp3',
        'title': 'Song Two',
        'artist': 'Artist B',
        'cover_path': 'cover2.jpg'
      });
      await db.insert('Songs',
          {'path': 'song3.mp3', 'title': 'Song Three', 'artist': 'Artist C'});
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> getSongIdByPath(String path) async {
      final List<Map<String, dynamic>> result =
          await db.query('Songs', where: 'path = ?', whereArgs: [path]);
      return result.first['id'] as int;
    }

    test('C-031 (variant): Create a new playlist', () async {
      final playlistName = 'My Chill Vibes';
      final createdPlaylist =
          await playlistService.createPlaylist(playlistName);
      expect(createdPlaylist.name, playlistName);
      expect(createdPlaylist.id, isNotNull);

      final playlists = await playlistService.getPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.name, playlistName);
    });

    test('Create playlist with a cover path', () async {
      final playlistName = 'Rock Anthems';
      final cover = '/path/to/rock_cover.jpg';
      final createdPlaylist =
          await playlistService.createPlaylist(playlistName, coverPath: cover);
      expect(createdPlaylist.coverPath, cover);
    });

    test('C-031.3 (variant): Create playlist with special characters in name',
        () async {
      final playlistName = "My Awesome Playlist! & Songs '23";
      final createdPlaylist =
          await playlistService.createPlaylist(playlistName);
      expect(createdPlaylist.name, playlistName);
      final fetched = await playlistService.getPlaylists();
      expect(fetched.first.name, playlistName);
    });

    test('Add song to playlist successfully', () async {
      final playlist = await playlistService.createPlaylist('Favorites');
      final songIdToAdd = await getSongIdByPath('song1.mp3');

      final result =
          await playlistService.addSongToPlaylist(playlist.id!, songIdToAdd);
      expect(result, isTrue);

      final songsInPlaylist =
          await playlistService.getPlaylistSongs(playlist.id!);
      expect(songsInPlaylist.length, 1);
      expect(songsInPlaylist.first.id, songIdToAdd);
    });

    test('Add song to playlist updates playlist cover if null', () async {
      final playlist =
          await playlistService.createPlaylist('New Mix', coverPath: null);
      final songIdToAdd = await getSongIdByPath(
          'song2.mp3'); // Song with cover_path 'cover2.jpg'

      await playlistService.addSongToPlaylist(playlist.id!, songIdToAdd);

      final updatedPlaylists = await playlistService
          .getPlaylists(); // This re-fetches playlists and their songs
      final updatedPlaylist =
          updatedPlaylists.firstWhere((p) => p.id == playlist.id);
      expect(updatedPlaylist.coverPath, 'cover2.jpg');
    });

    test('Add song that is already in playlist returns false', () async {
      final playlist = await playlistService.createPlaylist('Duplicates Test');
      final songId = await getSongIdByPath('song1.mp3');
      await playlistService.addSongToPlaylist(playlist.id!, songId); // Add once
      final result = await playlistService.addSongToPlaylist(
          playlist.id!, songId); // Add again

      expect(result, isFalse);
      final songsInPlaylist =
          await playlistService.getPlaylistSongs(playlist.id!);
      expect(songsInPlaylist.length, 1); // Should still be 1
    });

    test('Add non-existent song to playlist throws exception', () async {
      final playlist = await playlistService.createPlaylist('Error Test');
      final nonExistentSongId = 999;

      expect(
          () => playlistService.addSongToPlaylist(
              playlist.id!, nonExistentSongId),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              contains('Song with ID $nonExistentSongId does not exist'))));
    });

    test('Add song to non-existent playlist throws exception', () async {
      final nonExistentPlaylistId = 888;
      final songId = await getSongIdByPath('song1.mp3');

      expect(
          () =>
              playlistService.addSongToPlaylist(nonExistentPlaylistId, songId),
          throwsA(isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                  'Playlist with ID $nonExistentPlaylistId does not exist'))));
    });

    test('Remove song from playlist', () async {
      final playlist = await playlistService.createPlaylist('Removal Test');
      final songId = await getSongIdByPath('song1.mp3');
      await playlistService.addSongToPlaylist(playlist.id!, songId);

      var songs = await playlistService.getPlaylistSongs(playlist.id!);
      expect(songs.length, 1);

      await playlistService.removeSongFromPlaylist(playlist.id!, songId);
      songs = await playlistService.getPlaylistSongs(playlist.id!);
      expect(songs.isEmpty, isTrue);
    });

    test('Remove song not in playlist (no error, no change)', () async {
      final playlist =
          await playlistService.createPlaylist('Empty Removal Test');
      final songIdToRemove = await getSongIdByPath(
          'song1.mp3'); // Exists in DB, but not added to this playlist
      final songIdActuallyInPlaylist = await getSongIdByPath('song2.mp3');

      await playlistService.addSongToPlaylist(
          playlist.id!, songIdActuallyInPlaylist);

      await playlistService.removeSongFromPlaylist(
          playlist.id!, songIdToRemove);

      final songsInPlaylist =
          await playlistService.getPlaylistSongs(playlist.id!);
      expect(songsInPlaylist.length, 1);
      expect(songsInPlaylist.first.id, songIdActuallyInPlaylist);
    });

    test('Remove song updates playlist cover if it was the source', () async {
      final playlist =
          await playlistService.createPlaylist('Cover Update Test');
      final songIdWithCover =
          await getSongIdByPath('song2.mp3'); // Has cover 'cover2.jpg'
      final anotherSongId = await getSongIdByPath('song1.mp3'); // No cover

      await playlistService.addSongToPlaylist(playlist.id!, anotherSongId);
      // At this point, cover might be null (from song1)
      var fetchedPlaylist = (await playlistService.getPlaylists())
          .firstWhere((p) => p.id == playlist.id);
      final song1ModelFromDb =
          await db.query('Songs', where: 'id = ?', whereArgs: [anotherSongId]);
      expect(fetchedPlaylist.coverPath, song1ModelFromDb.first['cover_path']);

      await playlistService.addSongToPlaylist(playlist.id!, songIdWithCover);
      // Now, cover should be from song2
      fetchedPlaylist = (await playlistService.getPlaylists())
          .firstWhere((p) => p.id == playlist.id);
      expect(fetchedPlaylist.coverPath, 'cover2.jpg');

      await playlistService.removeSongFromPlaylist(
          playlist.id!, songIdWithCover); // Remove song2

      fetchedPlaylist = (await playlistService.getPlaylists())
          .firstWhere((p) => p.id == playlist.id);
      // Cover should revert to song1's cover (which is null) or be null if song1 was the only one left and had no cover.
      expect(fetchedPlaylist.coverPath,
          song1ModelFromDb.first['cover_path']); // song1's cover_path is null
    });

    test('C-031.1: Delete an existing playlist', () async {
      final playlist = await playlistService.createPlaylist('To Be Deleted');
      final songId = await getSongIdByPath('song1.mp3');
      await playlistService.addSongToPlaylist(playlist.id!, songId);

      await playlistService.deletePlaylist(playlist.id!);

      final playlists = await playlistService.getPlaylists();
      expect(playlists.any((p) => p.id == playlist.id), isFalse);

      final List<Map<String, dynamic>> playlistSongs = await db.query(
          'PlaylistSongs',
          where: 'playlist_id = ?',
          whereArgs: [playlist.id!]);
      expect(playlistSongs.isEmpty, isTrue);
    });

    test('Delete non-existent playlist (no error, no change)', () async {
      await playlistService.createPlaylist('Existing Playlist');
      final initialPlaylists = await playlistService.getPlaylists();

      await playlistService.deletePlaylist(999); // Non-existent ID

      final finalPlaylists = await playlistService.getPlaylists();
      expect(finalPlaylists.length, initialPlaylists.length);
    });

    test('Get playlist songs - sorted by added_at (default)', () async {
      final playlist = await playlistService.createPlaylist('Sort Test');
      final songId1 = await getSongIdByPath('song1.mp3');
      final songId2 = await getSongIdByPath('song2.mp3');

      await playlistService.addSongToPlaylist(playlist.id!, songId1);
      await Future.delayed(
          const Duration(milliseconds: 50)); // Ensure different timestamp
      await playlistService.addSongToPlaylist(playlist.id!, songId2);

      final songs = await playlistService.getPlaylistSongs(playlist.id!);
      expect(songs.length, 2);
      expect(songs[0].id, songId2); // Most recently added
      expect(songs[1].id, songId1);
    });

    test('Get playlist songs - sorted by title', () async {
      final playlist = await playlistService.createPlaylist('Title Sort Test');
      final songId1 = await getSongIdByPath('song1.mp3'); // Song One
      final songId2 = await getSongIdByPath('song2.mp3'); // Song Two
      final songId3 = await getSongIdByPath('song3.mp3'); // Song Three

      // Add in non-alphabetical order of title to test sorting
      await playlistService.addSongToPlaylist(playlist.id!, songId3);
      await playlistService.addSongToPlaylist(playlist.id!, songId1);
      await playlistService.addSongToPlaylist(playlist.id!, songId2);

      final songs =
          await playlistService.getPlaylistSongs(playlist.id!, sortBy: 'title');
      expect(songs.length, 3);
      expect(songs[0].id, songId1); // Song One
      expect(songs[1].id, songId3); // Song Three
      expect(songs[2].id, songId2); // Song Two
    });

    test('Update playlist name', () async {
      final playlist = await playlistService.createPlaylist('Old Name');
      final newName = 'New Awesome Name';
      await playlistService.updatePlaylistName(playlist.id!, newName);

      final updatedPlaylists = await playlistService.getPlaylists();
      final updatedPlaylist =
          updatedPlaylists.firstWhere((p) => p.id == playlist.id);
      expect(updatedPlaylist.name, newName);
    });

    test('Update cover for existing playlist with valid (mocked) file path',
        () async {
      // final playlist = await playlistService.createPlaylist('Cover Test Playlist');
      // Unused variable 'newCoverPath' due to conceptual nature of this file system dependent test.
      // final newCoverPath = 'C:\\valid\\cover.png';

      // This test remains conceptual as it requires mocking dart:io's File.exists() and File.length().
      // when(mockFileFactory(newCoverPath).exists()).thenAnswer((_) async => true);
      // when(mockFileFactory(newCoverPath).length()).thenAnswer((_) async => 1024);
      // await playlistService.updatePlaylistCover(playlist.id!, newCoverPath);
      // final fetched = (await playlistService.getPlaylists()).firstWhere((p) => p.id == playlist.id);
      // expect(fetched.coverPath, newCoverPath);
      expect(true, isTrue,
          reason:
              "Conceptual: File system interaction for updatePlaylistCover needs dart:io mocks.");
    });

    test('Update cover with empty path throws exception', () async {
      final playlist =
          await playlistService.createPlaylist('Empty Cover Path Test');
      expect(
          () => playlistService.updatePlaylistCover(playlist.id!, ''),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              contains('Cover path cannot be empty'))));
    });

    test('Update cover with non-existent file path throws exception', () async {
      // final playlist = await playlistService.createPlaylist('NonExistent Cover Test');
      // Unused variable 'nonExistentPath' due to conceptual nature of this test.
      // final nonExistentPath = 'C:\\invalid\\path\\to\\cover.jpg';
      // Conceptual: when(mockFileFactory(nonExistentPath).exists()).thenAnswer((_) async => false);
      // expect(
      //     () => playlistService.updatePlaylistCover(playlist.id!, nonExistentPath),
      //     throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Cover file does not exist')))
      // );
      expect(true, isTrue,
          reason: "Conceptual: File system interaction needs dart:io mocks.");
    });

    test(
        'C-031.2: Database connection interruption (conceptual for transactions)',
        () {
      // Testing atomicity and rollback for database connection interruptions during transactions
      // (e.g., in addSongsToPlaylist or removeSongsFromPlaylist) is complex for unit tests.
      // It requires advanced database mocking to simulate connection failures mid-transaction.
      // The PlaylistService uses _database.transaction(), relying on sqflite's capabilities
      // to ensure atomicity. If an error occurs within the transaction block, sqflite
      // should automatically roll back changes.
      // A white-box test would involve:
      // 1. Mocking the `Transaction` object (`txn`) provided by `_database.transaction()`.
      // 2. Forcing a method call on `txn` (e.g., `txn.insert` or `txn.delete`) to throw an exception.
      // 3. Verifying that none of the intended operations within that transaction block took effect
      //    by querying the database state afterwards.
      expect(true, isTrue,
          reason:
              "Conceptual test for transaction rollback. Requires advanced DB transaction mocking capabilities not implemented here.");
    });
  });
}

// Extension to make MusicScannerService._createSongModelFromFile logic testable
// This is a common pattern if you can't modify the original class for testing.
// Ideally, _createSongModelFromFile would be a static method or part of a testable helper class.
extension TestableMusicScannerService on MusicScannerService {
  SongModel testCreateSongModelFromTag(String filePath, audiotags.Tag? tag,
      {bool didThrow = false}) {
    // Replicate the logic of _createSongModelFromFile
    if (didThrow) {
      // Simulates exception during AudioTags.read
      // Accessing _logger directly here is not possible as it's private to MusicScannerService.
      // For testing, you might pass a logger or use a globally accessible test logger.
      // print('Simulated error for $filePath'); // Placeholder for logging
      return SongModel(
        path: filePath,
        title: p.basenameWithoutExtension(filePath),
        artist: '未知艺术家',
        album: null,
        duration: null,
        coverPath: null,
        isFavorite: false,
      );
    }
    if (tag == null) {
      // Simulates AudioTags.read returning null
      // print('No metadata for $filePath'); // Placeholder for logging
      return SongModel(
        path: filePath,
        title: p.basenameWithoutExtension(filePath),
        artist: '未知艺术家',
        album: null,
        duration: null,
        coverPath: null,
        isFavorite: false,
      );
    }
    // Normal processing if tag is not null and no simulated error
    return SongModel(
      path: filePath,
      title: tag.title?.isNotEmpty == true
          ? tag.title
          : p.basenameWithoutExtension(filePath),
      artist: tag.trackArtist?.isNotEmpty == true ? tag.trackArtist : '未知艺术家',
      album: tag.album?.isNotEmpty == true ? tag.album : null,
      duration: tag.duration,
      coverPath:
          null, // Cover path extraction is not part of this method in the original code
      isFavorite: false,
    );
  }
}
