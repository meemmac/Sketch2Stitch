// lib/services/cloudinary_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class CloudinaryService {
  // !!! REPLACE WITH YOUR ACTUAL CLOUDINARY VALUES !!!
  static const String cloudName = 'eh11vsnw'; // Get this from your dashboard
  static const String uploadPreset = 'sketch2stitch'; // Your preset name from the image
  
  static String get uploadUrl => 
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  
  final ImagePicker _picker = ImagePicker();

  Future<String?> uploadImage(File imageFile, {String? folder}) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: path.basename(imageFile.path),
        ),
      );

      // Using your preset: sketch2stitch
      request.fields['upload_preset'] = uploadPreset;
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }

      print('📤 Uploading image to Cloudinary...');
      print('📁 Folder: ${folder ?? 'root'}');
      print('📎 File: ${path.basename(imageFile.path)}');
      print('🌐 URL: $uploadUrl');
      print('🔑 Preset: $uploadPreset');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseBody);
        final secureUrl = jsonResponse['secure_url'] as String?;
        print('✅ Upload successful!');
        print('🔗 URL: $secureUrl');
        return secureUrl;
      } else {
        print('❌ Upload failed with status: ${response.statusCode}');
        print('📄 Response: $responseBody');
        throw Exception('Upload failed (${response.statusCode}): $responseBody');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }

  Future<File?> pickImageFromGallery({
    double maxWidth = 2048,
    double maxHeight = 2048,
    int imageQuality = 85,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('❌ Error picking image from gallery: $e');
      return null;
    }
  }

  Future<File?> pickImageFromCamera({
    double maxWidth = 2048,
    double maxHeight = 2048,
    int imageQuality = 85,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('❌ Error taking photo from camera: $e');
      return null;
    }
  }

  String getOptimizedImageUrl(
    String imageUrl, {
    int width = 400,
    int height = 400,
    String crop = 'fill',
    int quality = 80,
  }) {
    if (!imageUrl.contains('cloudinary.com')) {
      return imageUrl;
    }

    try {
      String transformation = 'c_$crop,w_$width,h_$height,q_$quality';
      
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length < 3) return imageUrl;
      
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1) return imageUrl;
      
      final beforeUpload = pathSegments.sublist(0, uploadIndex + 1);
      final afterUpload = pathSegments.sublist(uploadIndex + 1);
      
      final newPath = [...beforeUpload, transformation, ...afterUpload];
      final newUri = uri.replace(path: newPath.join('/'));
      
      return newUri.toString();
    } catch (e) {
      print('❌ Error optimizing image URL: $e');
      return imageUrl;
    }
  }
}