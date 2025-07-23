import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

/// Service for handling image caching and compression
class ImageCacheService {
  static const String _cacheKey = 'reva_image_cache';
  static const int _maxCacheObjects = 200;
  static const Duration _maxAge = Duration(days: 30);
  static const int _compressionQuality = 85;
  static const int _maxImageWidth = 1024;
  static const int _maxImageHeight = 1024;

  static CacheManager? _cacheManager;

  /// Get the cache manager instance
  static CacheManager get cacheManager {
    _cacheManager ??= CacheManager(
      Config(
        _cacheKey,
        maxNrOfCacheObjects: _maxCacheObjects,
        stalePeriod: _maxAge,
        repo: JsonCacheInfoRepository(databaseName: _cacheKey),
      ),
    );
    return _cacheManager!;
  }

  /// Get cached image file or download and cache if not available
  static Future<File?> getCachedImage(String url) async {
    try {
      final file = await cacheManager.getSingleFile(url);
      return file;
    } catch (e) {
      debugPrint('Error getting cached image: $e');
      return null;
    }
  }

  /// Compress image file
  static Future<Uint8List?> compressImage(
    File imageFile, {
    int quality = _compressionQuality,
    int maxWidth = _maxImageWidth,
    int maxHeight = _maxImageHeight,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  /// Compress image from bytes
  static Future<Uint8List?> compressImageFromBytes(
    Uint8List imageBytes, {
    int quality = _compressionQuality,
    int maxWidth = _maxImageWidth,
    int maxHeight = _maxImageHeight,
  }) async {
    try {
      // Decode image to get dimensions
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Check if compression is needed
      if (image.width <= maxWidth && image.height <= maxHeight) {
        return imageBytes;
      }

      // Create temporary file for compression
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final result = await compressImage(
        tempFile,
        quality: quality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return result;
    } catch (e) {
      debugPrint('Error compressing image from bytes: $e');
      return null;
    }
  }

  /// Get image dimensions without loading full image
  static Future<Size?> getImageDimensions(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image != null) {
        return Size(image.width.toDouble(), image.height.toDouble());
      }
      return null;
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
      return null;
    }
  }

  /// Clear image cache
  static Future<void> clearCache() async {
    try {
      await cacheManager.emptyCache();
    } catch (e) {
      debugPrint('Error clearing image cache: $e');
    }
  }

  /// Get cache size in bytes
  static Future<int> getCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/$_cacheKey');
      if (!await cacheDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0;
    }
  }

  /// Remove old cache files based on last access time
  static Future<void> cleanupOldCache() async {
    try {
      final cutoffTime = DateTime.now().subtract(_maxAge);
      await cacheManager.emptyCache();
    } catch (e) {
      debugPrint('Error cleaning up old cache: $e');
    }
  }
}

/// Size class for image dimensions
class Size {
  final double width;
  final double height;

  const Size(this.width, this.height);

  @override
  String toString() => 'Size($width, $height)';
}