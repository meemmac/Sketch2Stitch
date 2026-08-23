// lib/services/cloudinary_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class CloudinaryService {
  // Unsigned upload against Cloudinary's free tier. These two values are not
  // secrets (an unsigned preset is designed to ship in the client), but the
  // preset should be configured in the Cloudinary dashboard with an allowed
  // formats list and a max file size so the endpoint cannot be abused.
  // Callers additionally validate size and extension before uploading.
  static const String cloudName = 'eh11vsnw';
  static const String uploadPreset = 'sketch2stitch';

  static String get uploadUrl => 
      'https://api.cloudinary.com/v1_1/$cloudName/auto/upload';
  
  final ImagePicker _picker = ImagePicker();

  Future<String?> uploadImage(File file, {String? folder}) async {
    try {
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: path.basename(file.path),
        ),
      );

      // Using your preset: sketch2stitch
      request.fields['upload_preset'] = uploadPreset;
      request.fields['resource_type'] = 'auto'; // Explicitly set to auto
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseBody);
        return jsonResponse['secure_url'] as String?;
      } else {
        // The status code is enough to diagnose an upload failure; the raw
        // response body can carry the signed request details, so it is not
        // surfaced.
        throw Exception('Upload failed (${response.statusCode})');
      }
    } catch (e) {
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
    } catch (_) {
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
    } catch (_) {
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
    } catch (_) {
      return imageUrl;
    }
  }
}