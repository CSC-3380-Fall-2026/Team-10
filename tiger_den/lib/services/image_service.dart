import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';
class ImageService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late Directory imageDir;

  //run every time
  Future<void> cleanUp() async{destroyImageFolder();}

  Future<XFile?> compressFile(XFile? file) async {
    makeImageFolder();
    String fileName = p.basename(file!.path);
    String targetPath = p.join(imageDir.path, "compressed_$fileName");
    XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 75,
    );


    return result;
  }

  Future<void> makeImageFolder() async {
    Directory tempDir = await getTemporaryDirectory();
    
    String imageDirectoryPath = p.join(tempDir.path, 'image_cache');
    imageDir = Directory(imageDirectoryPath);
    
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
  }
  Future<void> destroyImageFolder() async {
      if (await imageDir.exists()) {
      await imageDir.delete(recursive: true);
    }
  }

  /// Uploads the selected file to Firebase Storage and returns its download URL string.
  Future<String?> uploadImageToFirebaseStorage(image) async {
    // If the user didn't pick an image, return null immediately
    if (image == null) return null;

    try {
      // 1. Point to your default storage bucket (tigerdenfb.firebasestorage.app)
      final storageRef = FirebaseStorage.instance.ref();

      // 2. Generate a unique filename using a timestamp so files don't overwrite each other
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // 3. Define the destination folder structure inside the bucket
      final eventImageRef = storageRef.child('events/images/$fileName');

      // 4. Convert your XFile representation to a regular Dart File object and execute the upload
      final File fileToUpload = File(selectedImage!.path);
      await eventImageRef.putFile(fileToUpload);

      // 5. Ask Firebase for the public, viewable HTTP URL string
      final String downloadUrl = await eventImageRef.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint("Failed to upload image to tigerdenfb storage: $e");
      return null;
    }
  }



}