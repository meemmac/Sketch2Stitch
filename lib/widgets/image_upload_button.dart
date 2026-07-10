// lib/widgets/image_upload_button.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sketch2stitch/services/cloudinary_service.dart';

class ImageUploadButton extends StatefulWidget {
  final Function(String imageUrl)? onUploadSuccess;
  final Function(String error)? onUploadError;
  final String? folder;
  final String buttonText;
  final IconData icon;
  final Color? buttonColor;
  final Color? textColor;

  const ImageUploadButton({
    super.key,
    this.onUploadSuccess,
    this.onUploadError,
    this.folder,
    this.buttonText = 'Upload Image',
    this.icon = Icons.cloud_upload,
    this.buttonColor,
    this.textColor,
  });

  @override
  State<ImageUploadButton> createState() => _ImageUploadButtonState();
}

class _ImageUploadButtonState extends State<ImageUploadButton> {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.buttonColor ?? Theme.of(context).primaryColor;
    
    return ElevatedButton.icon(
      onPressed: _isUploading ? null : _handleUpload,
      icon: _isUploading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(widget.icon),
      label: Text(_isUploading ? 'Uploading...' : widget.buttonText),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: widget.textColor ?? Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        minimumSize: const Size(120, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _handleUpload() async {
    setState(() => _isUploading = true);

    try {
      final File? imageFile = await _cloudinaryService.pickImageFromGallery();
      
      if (imageFile == null) {
        setState(() => _isUploading = false);
        return;
      }

      _showSnackBar('Uploading image...', isError: false);
      
      final String? imageUrl = await _cloudinaryService.uploadImage(
        imageFile,
        folder: widget.folder ?? 'temp',
      );

      if (imageUrl != null && mounted) {
        widget.onUploadSuccess?.call(imageUrl);
        _showSnackBar('✅ Image uploaded successfully!', isError: false);
      } else {
        _showSnackBar('❌ Failed to upload image', isError: true);
      }
    } catch (e) {
      widget.onUploadError?.call(e.toString());
      _showSnackBar('Upload failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}