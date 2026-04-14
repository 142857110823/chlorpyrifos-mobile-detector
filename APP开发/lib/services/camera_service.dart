import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 相机服务 - 拍摄样品参考照片
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  final ImagePicker _picker = ImagePicker();

  /// 拍摄样品照片
  /// 返回照片保存路径，失败返回null
  Future<String?> takeSamplePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo == null) return null;

      if (kIsWeb) {
        // Web平台直接返回临时路径
        return photo.path;
      }

      // 保存到应用私有目录
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = p.join(photosDir.path, 'sample_$timestamp.jpg');
      await File(photo.path).copy(savedPath);

      return savedPath;
    } catch (e) {
      print('拍照失败: $e');
      return null;
    }
  }

  /// 从相册选择照片
  Future<String?> pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo == null) return null;

      if (kIsWeb) {
        return photo.path;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = p.join(photosDir.path, 'sample_$timestamp.jpg');
      await File(photo.path).copy(savedPath);

      return savedPath;
    } catch (e) {
      print('选择照片失败: $e');
      return null;
    }
  }

  /// 删除样品照片
  Future<void> deletePhoto(String path) async {
    try {
      if (!kIsWeb) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print('删除照片失败: $e');
    }
  }
}
