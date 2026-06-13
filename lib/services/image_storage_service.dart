import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  static final ImageStorageService instance = ImageStorageService._();
  ImageStorageService._();

  Future<String?> saveImage(File source, String folder) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(join(dir.path, 'images', folder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final targetPath = join(targetDir.path, fileName);
    await source.copy(targetPath);
    return targetPath;
  }
}
