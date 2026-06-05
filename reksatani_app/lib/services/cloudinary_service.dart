import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/env/env.dart';

class CloudinaryService {
  final String _cloudName = Env.cloudinaryCloudName;
  final String _uploadPreset = Env.cloudinaryUploadPreset;

  Future<String?> uploadImage(String filePath) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      print('Error: Cloudinary config is missing in Env');
      return null;
    }

    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseString);
        return jsonResponse['secure_url'] as String;
      } else {
        print('Cloudinary Upload Failed: $responseString');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }
}
