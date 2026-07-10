// lib/widgets/cloudinary_image.dart
import 'package:flutter/material.dart';
import 'package:sketch2stitch/services/cloudinary_service.dart';

class CloudinaryImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? placeholderAsset;
  final bool useOptimized;
  final int quality;
  final int? widthParam;
  final int? heightParam;
  final String crop;
  final Widget? placeholderWidget;
  final Widget? errorWidget;
  final Duration fadeInDuration;

  const CloudinaryImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderAsset,
    this.useOptimized = true,
    this.quality = 80,
    this.widthParam,
    this.heightParam,
    this.crop = 'fill',
    this.placeholderWidget,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    // Return placeholder if URL is empty
    if (imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    String finalUrl = imageUrl;
    
    if (useOptimized) {
      // Handle infinity values safely
      int effectiveWidth = 400; // Default
      int effectiveHeight = 400; // Default
      
      // Only use widthParam or width if they are valid finite numbers
      if (widthParam != null && widthParam!.isFinite && widthParam! > 0) {
        effectiveWidth = widthParam!;
      } else if (width != null && width!.isFinite && width! > 0) {
        effectiveWidth = width!.toInt();
      }
      
      if (heightParam != null && heightParam!.isFinite && heightParam! > 0) {
        effectiveHeight = heightParam!;
      } else if (height != null && height!.isFinite && height! > 0) {
        effectiveHeight = height!.toInt();
      }
      
      finalUrl = CloudinaryService().getOptimizedImageUrl(
        imageUrl,
        width: effectiveWidth,
        height: effectiveHeight,
        crop: crop,
        quality: quality,
      );
    }

    return Image.network(
      finalUrl,
      width: width?.isFinite == true ? width : null,
      height: height?.isFinite == true ? height : null,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return FadeIn(
            duration: fadeInDuration,
            child: child,
          );
        }
        return _buildLoadingIndicator(context);
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ Image load error: $error');
        print('🔗 URL: $finalUrl');
        return _buildErrorWidget(context);
      },
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return Container(
      width: width?.isFinite == true ? width : 50,
      height: height?.isFinite == true ? height : 50,
      color: Colors.grey[100],
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (placeholderWidget != null) return placeholderWidget!;
    
    if (placeholderAsset != null && placeholderAsset!.isNotEmpty) {
      return Container(
        width: width?.isFinite == true ? width : 50,
        height: height?.isFinite == true ? height : 50,
        color: Colors.grey[200],
        child: Image.asset(
          placeholderAsset!,
          fit: BoxFit.cover,
        ),
      );
    }
    
    return Container(
      width: width?.isFinite == true ? width : 50,
      height: height?.isFinite == true ? height : 50,
      color: Colors.grey[100],
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    if (errorWidget != null) return errorWidget!;
    
    return Container(
      width: width?.isFinite == true ? width : 50,
      height: height?.isFinite == true ? height : 50,
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 32,
            color: Colors.grey[400],
          ),
          if (width != null && width! > 100)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Image not found',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Helper widget for fade-in animation
class FadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const FadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}