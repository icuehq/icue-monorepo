import 'package:flutter/material.dart';

/// Status model for a manageable document (e.g. License, RC, Insurance).
class DocumentItemData {
  const DocumentItemData({
    required this.docType,
    required this.title,
    this.docNumber,
    this.expiryDate,
    this.fileUrl,
    this.hasLocalFile = false,
  });

  final String docType;
  final String title;
  final String? docNumber;
  final DateTime? expiryDate;
  final String? fileUrl;
  final bool hasLocalFile;

  bool get isUploaded => fileUrl != null && fileUrl!.isNotEmpty;

  /// Days remaining until expiration, if an expiry date exists.
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  /// Expiry status message for UI alerts.
  String? get expiryStatusMessage {
    final days = daysUntilExpiry;
    if (days == null) return null;
    if (days < 0) return 'Expired ${-days} days ago';
    if (days == 0) return 'Expires today';
    if (days <= 30) return 'Expires in $days days';
    return null;
  }
}

/// Reusable document management accordion section for drivers and vehicles.
class AppDocumentAccordion extends StatelessWidget {
  const AppDocumentAccordion({
    super.key,
    required this.document,
    this.onViewDocument,
    this.onUploadDocument,
    this.onDeleteDocument,
    this.onEditExpiry,
    this.isLoading = false,
  });

  final DocumentItemData document;
  final VoidCallback? onViewDocument;
  final VoidCallback? onUploadDocument;
  final VoidCallback? onDeleteDocument;
  final VoidCallback? onEditExpiry;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expiryAlert = document.expiryStatusMessage;
    final isExpired =
        document.daysUntilExpiry != null && document.daysUntilExpiry! < 0;

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isExpired
              ? Colors.red.shade300
              : (document.isUploaded
                    ? Colors.green.shade200
                    : Colors.grey.shade300),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isExpired
              ? Colors.red.shade50
              : (document.isUploaded
                    ? Colors.green.shade50
                    : Colors.grey.shade100),
          child: Icon(
            document.isUploaded
                ? Icons.verified_rounded
                : Icons.description_outlined,
            color: isExpired
                ? Colors.red
                : (document.isUploaded ? Colors.green : Colors.grey),
            size: 20,
          ),
        ),
        title: Text(
          document.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: expiryAlert != null
            ? Text(
                expiryAlert,
                style: TextStyle(
                  color: isExpired ? Colors.red : Colors.orange.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              )
            : (document.docNumber != null && document.docNumber!.isNotEmpty
                  ? Text(
                      'No: ${document.docNumber}',
                      style: const TextStyle(fontSize: 12),
                    )
                  : null),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                if (document.expiryDate != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Expiry Date:',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          '${document.expiryDate!.day}/${document.expiryDate!.month}/${document.expiryDate!.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (document.isUploaded && onViewDocument != null)
                      TextButton.icon(
                        onPressed: onViewDocument,
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('View'),
                      ),
                    if (document.isUploaded && onDeleteDocument != null) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onDeleteDocument,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 16,
                        ),
                        label: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                    if (onUploadDocument != null) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: onUploadDocument,
                        icon: Icon(
                          document.isUploaded
                              ? Icons.edit_rounded
                              : Icons.upload_file_rounded,
                          size: 16,
                        ),
                        label: Text(document.isUploaded ? 'Replace' : 'Upload'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
