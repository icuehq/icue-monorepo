import 'package:api_client/api_client.dart';
import 'package:core_ui/core_ui.dart';
import 'package:drivers/drivers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DriverDocsPage extends StatefulWidget {
  const DriverDocsPage({super.key, required this.driver});

  final Driver driver;

  @override
  State<DriverDocsPage> createState() => _DriverDocsPageState();
}

class _DriverDocsPageState extends State<DriverDocsPage> {
  static const List<String> _docTypes = ['License', 'Id', 'Profile'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<DriverProvider>();
        for (final doc in _docTypes) {
          provider.fetchDriverDoc(widget.driver.id, doc);
        }
      }
    });
  }

  void _onViewDoc(String title, String? url) {
    if (url == null || url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text(title),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            Flexible(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('Unable to preview document.')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDoc(String docType) async {
    // License and ID carry two photos; the profile document is a single file.
    var fileKey = 'File';
    if (docType != 'Profile') {
      final side = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Front side'),
                onTap: () => Navigator.pop(ctx, 'FrontPhoto'),
              ),
              ListTile(
                title: const Text('Back side'),
                onTap: () => Navigator.pop(ctx, 'BackPhoto'),
              ),
            ],
          ),
        ),
      );
      if (side == null) return;
      fileKey = side;
    }
    if (!mounted) return;
    final picked = await pickFile(context, allowDocuments: true);
    if (picked == null || !mounted) return;
    if (picked.isPdf && picked.bytes.length > 300000) {
      _showResult(success: false, message: 'File size should be under 300 KB');
      return;
    }
    final provider = context.read<DriverProvider>();
    final extension = picked.name.split('.').last.toLowerCase();
    final success = await provider.uploadDriverDoc(
      driverId: widget.driver.id,
      docType: docType,
      formData: FormData.fromMap({
        'Source': 'adminapp',
        'Type': docType,
        'RecordId': widget.driver.id,
        'Target': 'Driver',
        fileKey: MultipartFile.fromBytes(
          picked.bytes,
          filename: picked.name,
          contentType: picked.isPdf
              ? DioMediaType('application', 'pdf')
              : DioMediaType('image', extension),
        ),
      }),
    );
    _showResult(
      success: success,
      message: success
          ? 'Document uploaded successfully'
          : (provider.errorMessage ?? 'Failed to upload'),
    );
  }

  void _showResult({required bool success, required String message}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _confirmDeleteDoc(String docType) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $docType Document'),
        content: Text(
          'Are you sure you want to delete the uploaded $docType file for ${widget.driver.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final provider = context.read<DriverProvider>();
              final success = await provider.deleteDriverDoc(
                widget.driver.id,
                docType,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '$docType document removed'
                          : (provider.errorMessage ?? 'Failed to delete'),
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Driver Documents')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Documents for ${widget.driver.fullName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ..._docTypes.map((docType) {
              final doc = provider.driverDocs[docType];
              final isLicense = docType == 'License';

              final parsedExpiry = isLicense
                  ? widget.driver.licenceExpiryDate.toDateOrNull()
                  : null;

              final itemData = DocumentItemData(
                docType: docType,
                title: '$docType Document',
                docNumber: isLicense ? widget.driver.licenceNumber : null,
                expiryDate: parsedExpiry,
                fileUrl: doc?.frontPhotoImageUrl,
              );

              return AppDocumentAccordion(
                document: itemData,
                isLoading: provider.isLoading,
                onViewDocument: doc?.frontPhotoImageUrl != null
                    ? () => _onViewDoc(docType, doc!.frontPhotoImageUrl)
                    : null,
                onDeleteDocument: doc?.frontPhotoImageUrl != null
                    ? () => _confirmDeleteDoc(docType)
                    : null,
                onUploadDocument: () => _uploadDoc(docType),
              );
            }),
          ],
        ),
      ),
    );
  }
}
