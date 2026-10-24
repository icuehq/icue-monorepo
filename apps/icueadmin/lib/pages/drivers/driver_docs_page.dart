import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../dialogs/delete_dialog.dart';
import '../../models/drivers.dart';
import '../../providers/driver_provider.dart';
import '../../utils/app_utils.dart';
import '../../widgets/file_upload_widget.dart';
import '../vehicle_management/reports/image_view.dart';
import '../webview_page.dart';

class DriverDocsPage extends StatefulWidget {
  const DriverDocsPage({super.key, required this.driver});

  final Driver driver;

  @override
  State<DriverDocsPage> createState() => _DriverDocsPageState();
}

class _DriverDocsPageState extends State<DriverDocsPage> {
  PlatformFile? licenseFile, aadharFile;
  final docsList = ['License', 'Id', 'Profile'];
  XFile? profileFile;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      for (final doc in docsList) {
        Provider.of<DriverProvider>(
          context,
          listen: false,
        ).getDriverDocs(widget.driver.id, doc);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final driverProvider = Provider.of<DriverProvider>(context);
    final licenseDoc = driverProvider.driverDocs['License'];
    final aadharDoc = driverProvider.driverDocs['Id'];
    final profileDoc = driverProvider.driverDocs['Profile'];

    return Scaffold(
      appBar: AppBar(title: const Text('Driver Documents')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 20,
          children: [
            ExpansionTile(
              // initiallyExpanded: false,
              title: const Text(
                'License',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              dense: true,
              childrenPadding: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.green),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.green),
              ),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'License: ${widget.driver.licenceNumber ?? '-'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Expiry: ${widget.driver.licenceExpiryDate.formatAsIndianDate()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FileFromUrl(
                      title: 'Front Side',
                      fileUrl: licenseDoc?.frontPhotoImageUrl,
                      contentType: licenseDoc?.frontPhotoContentType ?? '',
                      driverId: widget.driver.id,
                      type: licenseDoc?.type ?? 'License',
                      docId: licenseDoc?.frontPhotoDocumentId ?? '',
                      side: 'FrontPhoto',
                    ),
                    const SizedBox(width: 10),
                    FileFromUrl(
                      title: 'Back Side',
                      fileUrl: licenseDoc?.backPhotoImageUrl,
                      contentType: licenseDoc?.backPhotoContentType ?? '',
                      driverId: widget.driver.id,
                      type: licenseDoc?.type ?? 'License',
                      docId: licenseDoc?.backPhotoDocumentId ?? '',
                      side: 'BackPhoto',
                    ),
                  ],
                ),
              ],
            ),
            ExpansionTile(
              // initiallyExpanded: false,
              title: const Text(
                'Aadhar Card',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              dense: true,
              childrenPadding: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.green),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.green),
              ),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FileFromUrl(
                      title: 'Front Side',
                      fileUrl: aadharDoc?.frontPhotoImageUrl,
                      contentType: aadharDoc?.frontPhotoContentType ?? '',
                      driverId: widget.driver.id,
                      type: aadharDoc?.type ?? 'Id',
                      docId: aadharDoc?.frontPhotoDocumentId ?? '',
                      side: 'FrontPhoto',
                    ),
                    const SizedBox(width: 10),
                    FileFromUrl(
                      title: 'Back Side',
                      fileUrl: aadharDoc?.backPhotoImageUrl,
                      contentType: aadharDoc?.backPhotoContentType ?? '',
                      driverId: widget.driver.id,
                      type: aadharDoc?.type ?? 'Id',
                      docId: aadharDoc?.backPhotoDocumentId ?? '',
                      side: 'BackPhoto',
                    ),
                  ],
                ),
              ],
            ),
            ExpansionTile(
              // initiallyExpanded: false,
              title: const Text(
                'Passport Size Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              dense: true,
              childrenPadding: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.green),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.green),
              ),
              children: [
                Row(
                  children: [
                    FileFromUrl(
                      title: 'Profile Photo',
                      fileUrl: profileDoc?.docUrl,
                      contentType: profileDoc?.contentType ?? '',
                      driverId: widget.driver.id,
                      type: profileDoc?.type ?? 'Profile',
                      docId: profileDoc?.documentId ?? '',
                      side: 'File',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FileFromUrl extends StatelessWidget {
  const FileFromUrl({
    super.key,
    required this.title,
    this.fileUrl,
    required this.contentType,
    required this.docId,
    required this.type,
    required this.driverId,
    required this.side,
  });

  final String contentType;
  final String docId;
  final int driverId;
  final String? fileUrl;
  final String side;
  final String title;
  final String type;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DriverProvider>(context);
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ...(fileUrl == null || fileUrl!.isEmpty
                  ? [
                      FileUploadWidget(
                        title: 'Upload',
                        isPickImage: false,
                        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 5,
                        ),
                        hint:
                            'Only allow file types: jpg, jpeg, png, pdf\nMax file size: 300kb',
                        onDelete: () {},
                        onFilePick: (xFile, platformFile) {
                          if (xFile != null) {
                            provider.uploadDriverDocs(
                              context,
                              driverId,
                              type,
                              docId,
                              xFile,
                              side,
                            );
                          } else if (platformFile != null) {
                            if (platformFile.size > 300000) {
                              AppUtils.showErrorMessage(
                                context,
                                'File size should be less than 300kb',
                              );
                            } else {
                              provider.uploadDriverDocs(
                                context,
                                driverId,
                                type,
                                docId,
                                kIsWeb
                                    ? XFile.fromData(
                                        platformFile.bytes!,
                                        name: platformFile.name,
                                        mimeType: platformFile.extension,
                                      )
                                    : XFile(
                                        platformFile.path!,
                                        name: platformFile.name,
                                        mimeType: platformFile.extension,
                                      ),
                                side,
                              );
                            }
                          }
                        },
                      ),
                    ]
                  : [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Image.network(
                          fileUrl ?? '',
                          width: 100,
                          height: 100,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                                'assets/document_placeholder.png',
                                width: 100,
                                height: 100,
                              ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              if (contentType.contains('image')) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ImageView(
                                      url: fileUrl!,
                                      isBase64: false,
                                    ),
                                  ),
                                );
                              } else if (contentType.contains('application')) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WebviewPage(
                                      url:
                                          'https://docs.google.com/viewer?embedded=true&url=${Uri.encodeComponent(fileUrl!)}',
                                      title: 'Document',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.visibility),
                            iconSize: 40,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => DeleteDialog(
                                  onDelete: () {
                                    provider.deleteDriverDoc(
                                      context,
                                      driverId,
                                      type,
                                      docId,
                                    );
                                  },
                                ),
                              );
                            },
                            icon: const Icon(Icons.delete_forever),
                            iconSize: 40,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ]),
            ],
          ),
        ),
      ),
    );
  }
}
