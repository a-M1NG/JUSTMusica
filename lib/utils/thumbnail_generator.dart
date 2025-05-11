import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Assuming 'package:flutter/services.dart'; is still needed for rootBundle if AssetImages are used extensively for defaults.
import 'package:image/image.dart' as img;
import 'package:just_musica/models/song_model.dart'; // Assuming this model exists
// palette_generator is not used directly in the isolate in this solution to keep it pure Dart.
// If you want to use PaletteGenerator, it would typically run on the main thread with ImageProvider.
import 'package:path_provider/path_provider.dart';
import 'package:audiotags/audiotags.dart';
import '../services/database_service.dart'; // Assuming this service exists

// LRUCache remains the same as provided by the user
class LRUCache<K, V> {
  final int capacity;
  final Map<K, V> _cache = {};
  final LinkedHashMap<K, bool> _usage = LinkedHashMap<K, bool>();

  LRUCache(this.capacity) : assert(capacity > 0);

  V? get(K key) {
    if (!_cache.containsKey(key)) return null;
    _usage.remove(key);
    _usage[key] = true;
    return _cache[key];
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache[key] = value;
      _usage.remove(key);
      _usage[key] = true;
      return;
    }
    if (_cache.length >= capacity && _usage.isNotEmpty) {
      final oldestKey = _usage.keys.first;
      _cache.remove(oldestKey);
      _usage.remove(oldestKey);
    }
    _cache[key] = value;
    _usage[key] = true;
  }

  bool containsKey(K key) => _cache.containsKey(key);
  V? operator [](K key) => get(key);
  void operator []=(K key, V value) => put(key, value);
  void clear() {
    _cache.clear();
    _usage.clear();
  }
}

// Data classes for isolate communication
class _IsolateRequest {
  final String id;
  final String command;
  final dynamic payload;

  _IsolateRequest({required this.id, required this.command, this.payload});

  Map<String, dynamic> toJson() => {
        'id': id,
        'command': command,
        'payload': payload,
      };

  factory _IsolateRequest.fromJson(Map<String, dynamic> json) {
    return _IsolateRequest(
      id: json['id'],
      command: json['command'],
      payload: json['payload'],
    );
  }
}

class _IsolateResponse {
  final String id;
  final dynamic data;
  final String? error;

  _IsolateResponse({required this.id, this.data, this.error});

  Map<String, dynamic> toJson() => {
        'id': id,
        'data': data,
        'error': error,
      };

  factory _IsolateResponse.fromJson(Map<String, dynamic> json) {
    return _IsolateResponse(
      id: json['id'],
      data: json['data'],
      error: json['error'],
    );
  }
}

/// ThumbnailGenerator Singleton
/// Manages communication with the JustMusicaThumbservice isolate.
/// Handles caching of Flutter UI objects (ImageProvider, Image, LinearGradient).
class ThumbnailGenerator {
  static final ThumbnailGenerator _instance = ThumbnailGenerator._internal();
  factory ThumbnailGenerator() => _instance;

  ThumbnailGenerator._internal();

  static const int _thumbnailUiCacheCapacity = 200;
  static const int _originalCoverUiCacheCapacity = 20;
  static const int _gradientUiCacheCapacity = 50;

  final _imageCache =
      LRUCache<String, ImageProvider>(_thumbnailUiCacheCapacity);
  final _oriImageCache = LRUCache<String, Image>(_originalCoverUiCacheCapacity);
  final _gradientCache =
      LRUCache<int, LinearGradient?>(_gradientUiCacheCapacity);

  Isolate? _isolate;
  SendPort? _toIsolateSendPort;
  final ReceivePort _fromIsolateReceivePort = ReceivePort();
  final Map<String, Completer<dynamic>> _completers = {};
  String _thumbDirectoryPath = '';
  bool _isInitialized = false;
  int _requestIdCounter = 0;

  Future<void> init() async {
    if (_isInitialized) return;

    final docDir = await getApplicationDocumentsDirectory();
    _thumbDirectoryPath = '${docDir.path}/JUSTMUSIC/thumbs';
    final thumbDir = Directory(_thumbDirectoryPath);
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }

    _isolate = await Isolate.spawn(
      _justMusicaThumbserviceIsolateEntry,
      _InitializeMessage(_fromIsolateReceivePort.sendPort, _thumbDirectoryPath),
    );

    Completer<void> isolateReadyCompleter = Completer();

    _fromIsolateReceivePort.listen((dynamic message) {
      if (message is SendPort) {
        _toIsolateSendPort = message;
        _isInitialized = true;
        if (!isolateReadyCompleter.isCompleted) {
          isolateReadyCompleter.complete();
        }
        debugPrint("ThumbnailGenerator: Isolate connection established.");
      } else if (message is Map<String, dynamic>) {
        final response = _IsolateResponse.fromJson(message);
        final completer = _completers.remove(response.id);
        if (completer != null) {
          if (response.error != null) {
            completer.completeError(Exception(response.error));
          } else {
            completer.complete(response.data);
          }
        }
      }
    });
    await isolateReadyCompleter.future; // Wait for SendPort from isolate
  }

  Future<T> _sendRequest<T>(String command, dynamic payload) async {
    if (!_isInitialized || _toIsolateSendPort == null) {
      throw Exception(
          "ThumbnailGenerator is not initialized or isolate connection failed.");
    }
    final requestId = (_requestIdCounter++).toString();
    final completer = Completer<T>();
    _completers[requestId] = completer;

    _toIsolateSendPort!.send(
        _IsolateRequest(id: requestId, command: command, payload: payload)
            .toJson());
    return completer.future;
  }

  Future<ImageProvider> getThumbnailProvider(String songPath) async {
    if (_imageCache.containsKey(songPath)) {
      return _imageCache.get(songPath)!;
    }

    try {
      final String? filePath =
          await _sendRequest<String?>('getThumbnailPath', songPath);
      ImageProvider provider;
      if (filePath != null && filePath.isNotEmpty) {
        provider = FileImage(File(filePath));
      } else {
        provider = const AssetImage('assets/images/default_cover.jpg');
      }
      _imageCache.put(songPath, provider);
      return provider;
    } catch (e) {
      debugPrint('Error getting thumbnail provider for $songPath: $e');
      return const AssetImage('assets/images/default_cover.jpg');
    }
  }

  Future<Image> getOriginCover(String songPath) async {
    if (_oriImageCache.containsKey(songPath)) {
      return _oriImageCache.get(songPath)!;
    }
    try {
      final Uint8List? imageData =
          await _sendRequest<Uint8List?>('getOriginCoverData', songPath);
      Image image;
      if (imageData != null && imageData.isNotEmpty) {
        image = Image.memory(imageData);
      } else {
        image = Image.asset('assets/images/default_cover.jpg');
      }
      _oriImageCache.put(songPath, image);
      return image;
    } catch (e) {
      debugPrint('Error getting origin cover for $songPath: $e');
      return Image.asset('assets/images/default_cover.jpg');
    }
  }

  Future<LinearGradient?> generateGradient(SongModel song) async {
    if (song.id == null) return null;
    if (_gradientCache.containsKey(song.id!)) {
      return _gradientCache.get(song.id!);
    }

    try {
      // Request enhanced palette data (dominant, vibrant, lightVibrant RGB maps)
      final Map<String, dynamic>? paletteData =
          await _sendRequest<Map<String, dynamic>?>(
              'getEnhancedPaletteData', song.path);

      if (paletteData == null) {
        _gradientCache.put(song.id!, null);
        return null;
      }

      // Helper to parse color from map and provide a fallback
      Color parseColor(
          Map<String, dynamic>? colorMapData, Color fallbackColor) {
        if (colorMapData == null) return fallbackColor;
        final r = colorMapData['r'] as int?;
        final g = colorMapData['g'] as int?;
        final b = colorMapData['b'] as int?;
        if (r != null && g != null && b != null) {
          return Color.fromRGBO(r, g, b, 1.0);
        }
        return fallbackColor;
      }

      final defaultDominantColor = Colors.grey[800]!;

      final dominantColorMap = paletteData['dominant'] as Map<String, dynamic>?;
      final Color dominantColor =
          parseColor(dominantColorMap, defaultDominantColor);

      final vibrantColorMap = paletteData['vibrant'] as Map<String, dynamic>?;
      final Color vibrantColor =
          parseColor(vibrantColorMap, dominantColor); // Fallback to dominant

      final lightVibrantColorMap =
          paletteData['lightVibrant'] as Map<String, dynamic>?;
      final Color lightVibrantColor =
          parseColor(lightVibrantColorMap, vibrantColor); // Fallback to vibrant

      final res = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          lightVibrantColor.withOpacity(0.8),
          vibrantColor.withOpacity(0.8),
          dominantColor.withOpacity(0.8),
        ],
        stops: const [
          0.0,
          0.5,
          1.0
        ], // Ensure stops match colors length if not evenly distributed
      );
      _gradientCache.put(song.id!, res);
      return res;
    } catch (e) {
      debugPrint('Error generating gradient for ${song.title}: $e');
      _gradientCache.put(song.id!, null);
      return null;
    }
  }

  Future<void> prefetchInfo(SongModel song) async {
    if (song.id == null) {
      debugPrint('Cannot prefetch: song.id is null');
      return;
    }
    // Check if gradient is already cached, implying dependent data might also be cached or in process.
    if (_gradientCache.containsKey(song.id!)) {
      return;
    }

    try {
      // This request will trigger the isolate to cache original cover data
      // and the new enhanced palette data.
      await _sendRequest<bool>(
          'prefetchSongData', {'path': song.path, 'id': song.id});
      // Optionally, you could immediately fetch and cache UI elements here too,
      // but it might be better to let them be lazy-loaded by UI components.
      // Example:
      // if (!_oriImageCache.containsKey(song.path)) await getOriginCover(song.path);
      // if (!_gradientCache.containsKey(song.id!)) await generateGradient(song);
    } catch (e) {
      debugPrint('Error prefetching info for ${song.title}: $e');
    }
  }

  Future<String> getThumbnail(String songPath) async {
    try {
      final String? filePath =
          await _sendRequest<String?>('getThumbnailPath', songPath);
      return filePath ?? '';
    } catch (e) {
      debugPrint('Error getting thumbnail path for $songPath: $e');
      return '';
    }
  }

  Future<void> generateThumbnail(String songPath) async {
    try {
      await _sendRequest<bool>('ensureThumbnailExists', songPath);
    } catch (e) {
      // Use debugPrint for consistency, or a proper logger
      debugPrint('Failed to ensure thumbnail exists for $songPath: $e');
    }
  }

  Future<String> getThumbnailById(int songId) async {
    try {
      final song = await DatabaseService()
          .getSongById(songId); // Assuming DatabaseService is available
      if (song == null) return '';
      return await getThumbnail(song.path);
    } catch (e) {
      // Use debugPrint for consistency
      debugPrint('Error getting thumbnail by ID $songId: $e');
      return '';
    }
  }

  void close() {
    if (_toIsolateSendPort != null) {
      _toIsolateSendPort!
          .send(_IsolateRequest(id: 'shutdown', command: 'shutdown').toJson());
    }
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _fromIsolateReceivePort.close();
    _completers.clear();
    _isInitialized = false;
    debugPrint("ThumbnailGenerator: Isolate closed.");
  }
}

/// Message class for initialization
class _InitializeMessage {
  final SendPort sendPort;
  final String thumbDirPath;
  _InitializeMessage(this.sendPort, this.thumbDirPath);
}

/// Isolate Entry Point
void _justMusicaThumbserviceIsolateEntry(_InitializeMessage initMessage) async {
  final mainToIsolateReceivePort = ReceivePort();
  final isolateService = JustMusicaThumbservice(initMessage.thumbDirPath);

  // Send the SendPort for this isolate back to the main isolate
  initMessage.sendPort.send(mainToIsolateReceivePort.sendPort);

  await for (final dynamic message in mainToIsolateReceivePort) {
    if (message is Map<String, dynamic>) {
      final request = _IsolateRequest.fromJson(message);

      if (request.command == 'shutdown') {
        mainToIsolateReceivePort.close();
        isolateService.dispose();
        debugPrint("JustMusicaThumbservice: Shutting down.");
        break;
      }

      dynamic resultData;
      String? errorMsg;

      try {
        switch (request.command) {
          case 'getThumbnailPath':
            resultData = await isolateService
                .getThumbnailPath(request.payload as String);
            break;
          case 'getOriginCoverData':
            resultData = await isolateService
                .getOriginCoverData(request.payload as String);
            break;
          case 'getEnhancedPaletteData': // Updated command
            resultData = await isolateService
                .getEnhancedPaletteData(request.payload as String);
            break;
          case 'ensureThumbnailExists':
            await isolateService
                .ensureThumbnailExists(request.payload as String);
            resultData = true; // Indicate success
            break;
          case 'prefetchSongData':
            final payloadMap = request.payload as Map<String, dynamic>;
            final songPath = payloadMap['path'] as String;
            // Prefetch cover and the new enhanced palette data
            await isolateService.getOriginCoverData(songPath);
            await isolateService.getEnhancedPaletteData(songPath);
            resultData = true;
            break;
          default:
            errorMsg = 'Unknown command: ${request.command}';
        }
      } catch (e, s) {
        debugPrint(
            "Error in JustMusicaThumbservice (${request.command}): $e\n$s");
        errorMsg = e.toString();
      }
      initMessage.sendPort.send(
          _IsolateResponse(id: request.id, data: resultData, error: errorMsg)
              .toJson());
    }
  }
  Isolate.exit();
}

/// JustMusicaThumbservice (Runs in a separate Isolate)
/// Handles all actual image processing and file I/O.
/// Manages its own caches for raw data.
class JustMusicaThumbservice {
  final String _thumbDirectoryPath;

  static const int _thumbnailSize = 100;
  static const int _rawThumbnailPathCacheCapacity = 200;
  static const int _rawOriginalCoverCacheCapacity = 20;
  static const int _rawEnhancedPaletteDataCacheCapacity =
      50; // Updated cache name

  // Caches for raw/processed data within the isolate
  final _thumbnailPathCache =
      LRUCache<String, String?>(_rawThumbnailPathCacheCapacity);
  final _originalCoverDataCache =
      LRUCache<String, Uint8List?>(_rawOriginalCoverCacheCapacity);
  // Updated cache for enhanced palette data
  final _enhancedPaletteDataCache =
      LRUCache<String, Map<String, Map<String, int>?>?>(
          _rawEnhancedPaletteDataCacheCapacity);

  JustMusicaThumbservice(this._thumbDirectoryPath);

  String _generateFileName(String songPath) {
    final bytes = utf8.encode(songPath);
    final hash = md5.convert(bytes).toString();
    return '$hash.jpg';
  }

  static Uint8List? _decodeAndEncodeImage(Uint8List coverData,
      {int? width, int? height, int quality = 80}) {
    final image = img.decodeImage(coverData);
    if (image == null) return null;

    img.Image resizedImage;
    if (width != null && height != null) {
      resizedImage = img.copyResize(
        image,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );
    } else {
      resizedImage = image;
    }
    return Uint8List.fromList(img.encodeJpg(resizedImage, quality: quality));
  }

  // Replaces _analyzeDominantColor with a more sophisticated version
  static Map<String, Map<String, int>?> _analyzeEnhancedPaletteColors(
      Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    Map<String, int> defaultDominant = {
      'r': 128,
      'g': 128,
      'b': 128
    }; // Default grey
    Map<String, int> defaultVibrant = {
      'r': 100,
      'g': 100,
      'b': 150
    }; // Default muted blue
    Map<String, int> defaultLightVibrant = {
      'r': 150,
      'g': 150,
      'b': 200
    }; // Default lighter blue

    if (image == null) {
      return {
        "dominant": defaultDominant,
        "vibrant": defaultVibrant,
        "lightVibrant": defaultLightVibrant,
      };
    }

    final colorCount = <int, int>{};
    int r, g, b;

    // Downsample for performance, consistent with previous dominant color logic
    final step = (image.width * image.height > 10000)
        ? (image.width > 100
            ? image.width ~/ 100
            : (image.width > 10
                ? image.width ~/ 10
                : 2)) // Avoid division by zero or too small step
        : 1;

    int analyzedPixelCount = 0;
    for (var y = 0; y < image.height; y += step) {
      for (var x = 0; x < image.width; x += step) {
        final pixel = image.getPixel(x, y);
        r = pixel.r.toInt();
        g = pixel.g.toInt();
        b = pixel.b.toInt();
        final key = (r << 16) | (g << 8) | b;
        colorCount[key] = (colorCount[key] ?? 0) + 1;
        analyzedPixelCount++;
      }
    }

    Map<String, int> dominantColorMap;
    if (colorCount.isEmpty || analyzedPixelCount == 0) {
      dominantColorMap = defaultDominant;
    } else {
      final dominantIntKey =
          colorCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      dominantColorMap = {
        'r': (dominantIntKey >> 16) & 0xFF,
        'g': (dominantIntKey >> 8) & 0xFF,
        'b': dominantIntKey & 0xFF
      };
    }

    // --- Placeholder logic for Vibrant and LightVibrant ---
    // This is a very simplified approach. True palette generation is more complex,
    // involving color spaces like HSL/HSV, saturation, brightness, and clustering.
    Map<String, int> vibrantColorMap;
    Map<String, int> lightVibrantColorMap;

    // Attempt to find a "vibrant" color by slightly shifting dominant and increasing saturation (conceptually)
    // If dominant is greyscale, pick a default vibrant.
    if (dominantColorMap['r'] == dominantColorMap['g'] &&
        dominantColorMap['g'] == dominantColorMap['b']) {
      vibrantColorMap = defaultVibrant;
    } else {
      vibrantColorMap = {
        'r': (dominantColorMap['r']! * 0.7 + Colors.blue.red * 0.3)
            .toInt()
            .clamp(0, 255),
        'g': (dominantColorMap['g']! * 0.7 + Colors.blue.green * 0.3)
            .toInt()
            .clamp(0, 255),
        'b': (dominantColorMap['b']! * 0.7 + Colors.blue.blue * 0.3)
            .toInt()
            .clamp(0, 255),
      };
      // Ensure it's reasonably different from dominant
      if (((vibrantColorMap['r']! - dominantColorMap['r']!).abs() < 30) &&
          ((vibrantColorMap['g']! - dominantColorMap['g']!).abs() < 30) &&
          ((vibrantColorMap['b']! - dominantColorMap['b']!).abs() < 30)) {
        vibrantColorMap = {
          'r': (dominantColorMap['r']! + 40) % 256,
          'g': (dominantColorMap['g']! - 20 + 256) % 256,
          'b': dominantColorMap['b']!
        };
      }
    }

    // Attempt for a "light vibrant" color - often a lighter, desaturated version of vibrant or dominant
    if (dominantColorMap['r'] == dominantColorMap['g'] &&
        dominantColorMap['g'] == dominantColorMap['b'] &&
        dominantColorMap['r']! > 200) {
      // if dominant is very light grey
      lightVibrantColorMap = {'r': 220, 'g': 220, 'b': 250}; // A light default
    } else {
      lightVibrantColorMap = {
        'r': (dominantColorMap['r']! + 100)
            .clamp(0, 255), // Lighter version of dominant
        'g': (dominantColorMap['g']! + 100).clamp(0, 255),
        'b': (dominantColorMap['b']! + 120)
            .clamp(0, 255), // Slightly bluer light
      };
      // Ensure it's different from vibrant and dominant
      if (((lightVibrantColorMap['r']! - vibrantColorMap['r']!).abs() < 30) &&
          ((lightVibrantColorMap['g']! - vibrantColorMap['g']!).abs() < 30)) {
        lightVibrantColorMap = {
          'r': vibrantColorMap['r']!,
          'g': (vibrantColorMap['g']! + 50).clamp(0, 255),
          'b': (vibrantColorMap['b']! + 50).clamp(0, 255)
        };
      }
    }
    // --- End of placeholder logic ---

    return {
      "dominant": dominantColorMap,
      "vibrant": vibrantColorMap,
      "lightVibrant": lightVibrantColorMap,
    };
  }

  Future<String?> getThumbnailPath(String songPath) async {
    if (_thumbnailPathCache.containsKey(songPath)) {
      final cached = _thumbnailPathCache.get(songPath);
      if (cached != null && await File(cached).exists()) {
        return cached;
      }
    }

    final fileName = _generateFileName(songPath);
    final thumbPath = '$_thumbDirectoryPath/$fileName';

    if (await File(thumbPath).exists()) {
      _thumbnailPathCache.put(songPath, thumbPath);
      return thumbPath;
    }

    try {
      final tag = await AudioTags.read(songPath);
      final coverData = tag?.pictures.firstOrNull?.bytes;

      if (coverData == null || coverData.isEmpty) {
        _thumbnailPathCache.put(songPath, null);
        return null;
      }

      final jpgData = _decodeAndEncodeImage(coverData,
          width: _thumbnailSize, height: _thumbnailSize, quality: 80);

      if (jpgData == null) {
        _thumbnailPathCache.put(songPath, null);
        return null;
      }

      final thumbFile = File(thumbPath);
      await thumbFile.writeAsBytes(jpgData);
      _thumbnailPathCache.put(songPath, thumbPath);
      return thumbPath;
    } catch (e) {
      debugPrint('Isolate: Failed to generate thumbnail for $songPath: $e');
      _thumbnailPathCache.put(songPath, null);
      return null;
    }
  }

  Future<void> ensureThumbnailExists(String songPath) async {
    await getThumbnailPath(songPath);
  }

  Future<Uint8List?> getOriginCoverData(String songPath) async {
    if (_originalCoverDataCache.containsKey(songPath)) {
      return _originalCoverDataCache.get(songPath);
    }
    try {
      final tag = await AudioTags.read(songPath);
      final coverData = tag?.pictures.firstOrNull?.bytes;

      if (coverData == null || coverData.isEmpty) {
        _originalCoverDataCache.put(songPath, null);
        return null;
      }

      final image = img.decodeImage(coverData);
      if (image == null) {
        _originalCoverDataCache.put(songPath, null);
        return null;
      }
      // Encode to PNG for consistency and because Image.memory handles it well.
      final pngBytes = Uint8List.fromList(img.encodePng(image));
      _originalCoverDataCache.put(songPath, pngBytes);
      return pngBytes;
    } catch (e) {
      debugPrint('Isolate: Failed to get origin cover for $songPath: $e');
      _originalCoverDataCache.put(songPath, null);
      return null;
    }
  }

  // Updated method to get enhanced palette data
  Future<Map<String, Map<String, int>?>?> getEnhancedPaletteData(
      String songPath) async {
    if (_enhancedPaletteDataCache.containsKey(songPath)) {
      return _enhancedPaletteDataCache.get(songPath);
    }
    try {
      final coverData = await getOriginCoverData(
          songPath); // Leverage existing method and its cache
      if (coverData == null || coverData.isEmpty) {
        _enhancedPaletteDataCache.put(songPath, null);
        return null;
      }

      // Use the new analysis method
      final Map<String, Map<String, int>?>? paletteMap =
          _analyzeEnhancedPaletteColors(coverData);
      _enhancedPaletteDataCache.put(songPath, paletteMap);
      return paletteMap;
    } catch (e) {
      debugPrint(
          'Isolate: Failed to generate enhanced palette for $songPath: $e');
      _enhancedPaletteDataCache.put(songPath, null);
      return null;
    }
  }

  void dispose() {
    _thumbnailPathCache.clear();
    _originalCoverDataCache.clear();
    _enhancedPaletteDataCache.clear(); // Clear the new cache
    debugPrint("JustMusicaThumbservice resources disposed.");
  }
}
