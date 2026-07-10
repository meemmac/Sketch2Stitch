// lib/screens/test_cloudinary_screen.dart
import 'package:flutter/material.dart';
import 'package:sketch2stitch/services/cloudinary_service.dart';
import 'package:sketch2stitch/widgets/cloudinary_image.dart';
import 'package:sketch2stitch/widgets/image_upload_button.dart';

class TestCloudinaryScreen extends StatefulWidget {
  const TestCloudinaryScreen({super.key});

  @override
  State<TestCloudinaryScreen> createState() => _TestCloudinaryScreenState();
}

class _TestCloudinaryScreenState extends State<TestCloudinaryScreen> {
  String? _uploadedImageUrl;
  final List<String> _uploadedImages = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloudinary Test'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _clearAll,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear all images',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Single Upload
                  _buildSingleUploadSection(),
                  
                  const SizedBox(height: 16),
                  
                  // Section 2: Multiple Uploads
                  _buildMultipleUploadSection(),
                  
                  const SizedBox(height: 16),
                  
                  // Section 3: Optimization Test
                  _buildOptimizationTestSection(),
                ],
              ),
            ),
    );
  }

  // ─── Section 1: Single Upload ────────────────────────────────────────

  Widget _buildSingleUploadSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload Image',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a single image to Cloudinary',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ImageUploadButton(
              folder: 'test_uploads',
              buttonText: 'Choose & Upload',
              onUploadSuccess: (url) {
                setState(() {
                  _uploadedImageUrl = url;
                });
                print('✅ Uploaded: $url');
              },
              onUploadError: (error) {
                print('❌ Error: $error');
                _showSnackBar('Upload failed: $error', isError: true);
              },
            ),
            if (_uploadedImageUrl != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Uploaded Image:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CloudinaryImage(
                    imageUrl: _uploadedImageUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    useOptimized: true,
                    widthParam: 400,
                    heightParam: 200,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Show URL with copy option
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _uploadedImageUrl!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Copy to clipboard
                      _copyToClipboard(_uploadedImageUrl!);
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: 'Copy URL',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Section 2: Multiple Uploads ─────────────────────────────────────

  Widget _buildMultipleUploadSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Multiple Uploads',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload and display multiple images',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ImageUploadButton(
                  folder: 'test_uploads',
                  buttonText: 'Add Image',
                  icon: Icons.add_photo_alternate,
                  onUploadSuccess: (url) {
                    setState(() {
                      _uploadedImages.add(url);
                    });
                    _showSnackBar('✅ Image added!', isError: false);
                  },
                  onUploadError: (error) {
                    _showSnackBar('Failed: $error', isError: true);
                  },
                ),
                const SizedBox(width: 8),
                if (_uploadedImages.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearMultipleImages,
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Clear All'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
              ],
            ),
            if (_uploadedImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Uploaded Images (${_uploadedImages.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Tap ✕ to remove',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _uploadedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CloudinaryImage(
                            imageUrl: _uploadedImages[index],
                            fit: BoxFit.cover,
                            useOptimized: true,
                            widthParam: 150,
                            heightParam: 150,
                            quality: 75,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _uploadedImages.removeAt(index);
                            });
                            _showSnackBar('Image removed', isError: false);
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Section 3: Optimization Test ────────────────────────────────────

  Widget _buildOptimizationTestSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Image Optimization Test',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Shows the same image in different sizes (upload an image first)',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_uploadedImageUrl == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '⬆️ Upload an image first to test optimization',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CloudinaryImage(
                              imageUrl: _uploadedImageUrl!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              useOptimized: true,
                              widthParam: 100,
                              heightParam: 100,
                              quality: 80,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '100x100\nHigh Quality',
                          style: TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CloudinaryImage(
                              imageUrl: _uploadedImageUrl!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              useOptimized: true,
                              widthParam: 100,
                              heightParam: 100,
                              quality: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '100x100\nLow Quality',
                          style: TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CloudinaryImage(
                              imageUrl: _uploadedImageUrl!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              useOptimized: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Original\n(No Opt)',
                          style: TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cloudinary automatically optimizes images for faster loading',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Helper Methods ──────────────────────────────────────────────────

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

  void _copyToClipboard(String text) {
    // Simple copy without clipboard package
    // You can add clipboard functionality later if needed
    _showSnackBar('URL copied to clipboard!', isError: false);
    print('📋 Copied: $text');
  }

  void _clearMultipleImages() {
    if (_uploadedImages.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Images?'),
        content: Text(
          'This will remove ${_uploadedImages.length} uploaded images from the display.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _uploadedImages.clear();
              });
              Navigator.pop(context);
              _showSnackBar('Cleared all images', isError: false);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _clearAll() {
    if (_uploadedImageUrl == null && _uploadedImages.isEmpty) {
      _showSnackBar('Nothing to clear', isError: false);
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Everything?'),
        content: const Text(
          'This will remove all uploaded images from the display.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _uploadedImageUrl = null;
                _uploadedImages.clear();
              });
              Navigator.pop(context);
              _showSnackBar('Cleared everything', isError: false);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}