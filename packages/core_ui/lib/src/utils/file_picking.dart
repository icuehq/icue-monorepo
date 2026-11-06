import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A file chosen by the user, held in memory for upload.
@immutable
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;

  bool get isPdf => name.toLowerCase().endsWith('.pdf');
}

/// Asks the user for a photo (camera/gallery) or, with [allowDocuments], any
/// of [documentExtensions]. Images are compressed (quality 30) like the legacy
/// app. Returns null when cancelled.
Future<PickedFile?> pickFile(
  BuildContext context, {
  bool allowDocuments = false,
  List<String> documentExtensions = const ['jpg', 'jpeg', 'png', 'pdf'],
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(allowDocuments ? Icons.folder : Icons.photo),
            title: Text(allowDocuments ? 'Choose file' : 'Gallery'),
            onTap: () => Navigator.pop(sheetContext, 'gallery'),
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
        ],
      ),
    ),
  );
  if (choice == null) return null;

  if (choice == 'gallery' && allowDocuments) {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: documentExtensions,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;
    return PickedFile(name: file.name, bytes: bytes);
  }

  final image = await ImagePicker().pickImage(
    source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 30,
  );
  if (image == null) return null;
  return PickedFile(name: image.name, bytes: await image.readAsBytes());
}
