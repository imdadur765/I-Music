import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class FilePickerService {
  
  // ✅ IMPROVED PERMISSION CHECK FOR ALL ANDROID VERSIONS
  static Future<bool> _checkStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        // Check Android version
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        
        if (sdkInt >= 33) {
          // Android 13+ - Use new permissions
          final status = await Permission.audio.status;
          if (!status.isGranted) {
            final result = await Permission.audio.request();
            return result.isGranted;
          }
          return true;
        } else {
          // Android 12 and below - Use storage permission
          final status = await Permission.storage.status;
          if (!status.isGranted) {
            final result = await Permission.storage.request();
            return result.isGranted;
          }
          return true;
        }
      }
      return true; // For iOS, return true
    } catch (e) {
      // If any error, try with basic storage permission
      try {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          final result = await Permission.storage.request();
          return result.isGranted;
        }
        return true;
      } catch (e) {
        return false;
      }
    }
  }

  // ✅ PICK AUDIO FILES WITH BETTER ERROR HANDLING
  static Future<List<File>> pickAudioFiles() async {
    try {
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied. Please grant storage permission in app settings.');
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'flac', 'ogg', 'lrc', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        List<File> audioFiles = [];
        for (var platformFile in result.files) {
          if (platformFile.path != null) {
            audioFiles.add(File(platformFile.path!));
          }
        }
        return audioFiles;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  // ✅ PICK SINGLE AUDIO FILE
  static Future<File?> pickSingleAudioFile() async {
    try {
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied. Please grant storage permission in app settings.');
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'flac', 'ogg'],
      );

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        return File(result.files.first.path!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // ✅ PICK LYRICS TEXT FILE WITH PERMISSION CHECK
  static Future<String?> pickLyricsTextFile() async {
    try {
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied. Please grant storage permission in app settings.');
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'lrc'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        final file = File(result.files.first.path!);
        final contents = await file.readAsString();
        return contents;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // ✅ PICK IMAGE FILE FOR ALBUM ART
  static Future<File?> pickImageFile() async {
    try {
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied. Please grant storage permission in app settings.');
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif'],
      );

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        return File(result.files.first.path!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // ✅ OPEN APP SETTINGS FOR PERMISSION
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  // ✅ CHECK PERMISSION STATUS
  static Future<bool> get isStoragePermissionGranted async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        
        if (sdkInt >= 33) {
          return await Permission.audio.isGranted;
        } else {
          return await Permission.storage.isGranted;
        }
      }
      return true;
    } catch (e) {
      return await Permission.storage.isGranted;
    }
  }

  // ✅ GET FILE SIZE FOR DISPLAY
  static String getFileSize(File file) {
    final sizeInBytes = file.lengthSync();
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1048576) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeInBytes / 1048576).toStringAsFixed(1)} MB';
    }
  }

  // ✅ GET FILE EXTENSION
  static String getFileExtension(File file) {
    final path = file.path;
    final extension = path.split('.').last.toLowerCase();
    return extension;
  }
}