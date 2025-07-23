import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/performance/image_cache_service.dart';

/// Optimized image widget with caching and compression
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableMemoryCache;
  final bool enableDiskCache;
  final Duration? cacheMaxAge;
  final Map<String, String>? httpHeaders;
  final int? compressionQuality;
  final int? maxWidth;
  final int? maxHeight;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableMemoryCache = true,
    this.enableDiskCache = true,
    this.cacheMaxAge,
    this.httpHeaders,
    this.compressionQuality,
    this.maxWidth,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheManager: ImageCacheService.cacheManager,
      memCacheWidth: maxWidth,
      memCacheHeight: maxHeight,
      httpHeaders: httpHeaders,
      placeholder: placeholder != null
          ? (context, url) => placeholder!
          : (context, url) => _buildDefaultPlaceholder(),
      errorWidget: errorWidget != null
          ? (context, url, error) => errorWidget!
          : (context, url, error) => _buildDefaultErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
      useOldImageOnUrlChange: true,
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.error_outline,
        color: Colors.grey,
      ),
    );
  }
}

/// Optimized avatar image with circular clipping
class OptimizedAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? fallbackText;

  const OptimizedAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 20,
    this.placeholder,
    this.errorWidget,
    this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: OptimizedImage(
          imageUrl: imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          maxWidth: (radius * 2 * MediaQuery.of(context).devicePixelRatio).round(),
          maxHeight: (radius * 2 * MediaQuery.of(context).devicePixelRatio).round(),
          placeholder: placeholder ?? _buildPlaceholder(),
          errorWidget: errorWidget ?? _buildErrorWidget(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (fallbackText != null && fallbackText!.isNotEmpty) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        color: Colors.grey[400],
        child: Center(
          child: Text(
            fallbackText![0].toUpperCase(),
            style: TextStyle(
              fontSize: radius * 0.8,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      color: Colors.grey[300],
      child: Icon(
        Icons.person,
        size: radius,
        color: Colors.grey[600],
      ),
    );
  }
}

/// Optimized image gallery with lazy loading
class OptimizedImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final double itemHeight;
  final double itemWidth;
  final EdgeInsetsGeometry? padding;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final void Function(String imageUrl, int index)? onImageTap;

  const OptimizedImageGallery({
    super.key,
    required this.imageUrls,
    this.itemHeight = 120,
    this.itemWidth = 120,
    this.padding,
    this.crossAxisCount = 3,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
    this.onImageTap,
  });

  @override
  State<OptimizedImageGallery> createState() => _OptimizedImageGalleryState();
}

class _OptimizedImageGalleryState extends State<OptimizedImageGallery> {
  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      padding: widget.padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        crossAxisSpacing: widget.crossAxisSpacing,
        mainAxisSpacing: widget.mainAxisSpacing,
        childAspectRatio: widget.itemWidth / widget.itemHeight,
      ),
      itemCount: widget.imageUrls.length,
      itemBuilder: (context, index) {
        final imageUrl = widget.imageUrls[index];
        
        return GestureDetector(
          onTap: () => widget.onImageTap?.call(imageUrl, index),
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: OptimizedImage(
                imageUrl: imageUrl,
                width: widget.itemWidth,
                height: widget.itemHeight,
                fit: BoxFit.cover,
                maxWidth: (widget.itemWidth * MediaQuery.of(context).devicePixelRatio).round(),
                maxHeight: (widget.itemHeight * MediaQuery.of(context).devicePixelRatio).round(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Hero image widget for smooth transitions
class OptimizedHeroImage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedHeroImage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: OptimizedImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
      ),
    );
  }
}