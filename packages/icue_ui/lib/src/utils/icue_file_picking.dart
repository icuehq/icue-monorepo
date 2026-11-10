import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A file chosen by the user, held in memory for upload.
@immutable
class IcuePickedFile {
  const IcuePickedFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;

  bool get isPdf => name.toLowerCase().endsWith('.pdf');
}

/// Asks the user for a photo (camera/gallery) or, with [allowDocuments], any
/// of [documentExtensions]. Images are compressed (quality 30) like the legacy
/// app. Returns null when cancelled.
Future<IcuePickedFile?> pickFile(
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
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: documentExtensions,
    );
    if (file == null) return null;
    return IcuePickedFile(name: file.name, bytes: await file.readAsBytes());
  }

  final image = await ImagePicker().pickImage(
    source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 30,
  );
  if (image == null) return null;
  return IcuePickedFile(name: image.name, bytes: await image.readAsBytes());
}
