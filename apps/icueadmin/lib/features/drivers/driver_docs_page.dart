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
                  child: Center(
                    child: Text('Unable to preview document.'),
                  ),
                ),
              ),
            ),
          ],
        ),
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
              final success = await provider.deleteDriverDoc(widget.driver.id, docType);
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
      appBar: AppBar(
        title: const Text('Driver Documents'),
      ),
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
                  ? AppDateUtils.tryParseDate(widget.driver.licenceExpiryDate)
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
                onUploadDocument: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('File picker opened for $docType'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
