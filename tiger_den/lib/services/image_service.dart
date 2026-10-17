import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert'; 

///Manages image compression and upload
class ImageService {
  ///The service used to communicate with Cloud Firestore
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  ///User local directory used to temporarily store images for compression
  late Directory imageDir;


  ///Disposes what is left over after using
  Future<void> cleanUp() async{await destroyImageFolder();}

  ///Compresses image file and gives it a unique time based name
  Future<XFile?> compressFile(XFile? file) async {
    makeImageFolder();
    String fileName = p.basename(file!.path);
    String targetPath = p.join(imageDir.path, "compressed_${fileName}_${DateTime.now().millisecondsSinceEpoch}.jpg".trim());
    XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 75,
    );
    return result;
  }
  
  ///Makes user local folder to temporarily store images
  Future<void> makeImageFolder() async {
    Directory tempDir = await getTemporaryDirectory();
    String imageDirectoryPath = p.join(tempDir.path, 'image_cache');
    imageDir = Directory(imageDirectoryPath);
    
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
  }
    ///Disposes temporary image folder and all its contents
  Future<void> destroyImageFolder() async {
      if (await imageDir.exists()) {
      await imageDir.delete(recursive: true);
    }
  }

  ///Uploads the selected file to Imgbb and returns its URL string.
  Future<String?> uploadImageToImgbb(XFile? image) async {
      try {
        String? apiKey = dotenv.env['IMGBB_IMAGE_API_KEY']?.trim();
        if(apiKey == null) return null; 
        final uri = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
        if (image == null) return null;

        final request = http.MultipartRequest('POST', uri);
        request.files.add(
          await http.MultipartFile.fromPath(
            'image', 
            image.path,
          ),
        );
        
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        print('Status code: ${response.statusCode}');
        print('Response body: ${response.body}'); 

        final jsonData = jsonDecode(response.body);

        if(jsonData['data'] != null){
          String url = jsonData['data']['image']['url'];
          return url;
        } else {
          print("Failed to grab data from json");
          return null;}
      } catch (e) {
        print('Upload failed: $e');
      }
  }
}