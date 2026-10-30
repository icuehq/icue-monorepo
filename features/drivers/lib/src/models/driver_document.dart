class DriverDocs {
  const DriverDocs({
    required this.recordId,
    required this.type,
    this.frontPhotoDocumentId,
    this.frontPhotoImageUrl,
    this.frontPhotoContentType,
    this.backPhotoImageUrl,
    this.backPhotoContentType,
    this.backPhotoDocumentId,
    this.docUrl,
    this.contentType,
    this.documentId,
  });

  factory DriverDocs.fromJson(Map<String, dynamic> json) => DriverDocs(
        recordId: json['RecordId'] as int? ?? 0,
        type: json['Type'] as String? ?? '',
        frontPhotoDocumentId: json['FrontPhoto_DocumentId'] as String?,
        frontPhotoImageUrl: json['FrontPhoto_ImageUrl'] as String?,
        frontPhotoContentType: json['FrontPhoto_ContentType'] as String?,
        backPhotoImageUrl: json['BackPhoto_ImageUrl'] as String?,
        backPhotoContentType: json['BackPhoto_ContentType'] as String?,
        backPhotoDocumentId: json['BackPhoto_DocumentId'] as String?,
        docUrl: json['DocUrl'] as String?,
        contentType: json['ContentType'] as String?,
        documentId: json['DocumentId'] as String?,
      );

  final int recordId;
  final String type;
  final String? frontPhotoDocumentId;
  final String? frontPhotoImageUrl;
  final String? frontPhotoContentType;
  final String? backPhotoImageUrl;
  final String? backPhotoContentType;
  final String? backPhotoDocumentId;
  final String? docUrl;
  final String? contentType;
  final String? documentId;

  Map<String, dynamic> toJson() => {
        'RecordId': recordId,
        'Type': type,
        'FrontPhoto_DocumentId': frontPhotoDocumentId,
        'FrontPhoto_ImageUrl': frontPhotoImageUrl,
        'FrontPhoto_ContentType': frontPhotoContentType,
        'BackPhoto_ImageUrl': backPhotoImageUrl,
        'BackPhoto_ContentType': backPhotoContentType,
        'BackPhoto_DocumentId': backPhotoDocumentId,
        'DocUrl': docUrl,
        'ContentType': contentType,
        'DocumentId': documentId,
      };
}

class DriverDocumentResponse {
  const DriverDocumentResponse({
    required this.err,
    required this.message,
    this.docs,
  });

  factory DriverDocumentResponse.fromJson(Map<String, dynamic> json) =>
      DriverDocumentResponse(
        err: json['err'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        docs: json['docs'] is Map<String, dynamic>
            ? DriverDocs.fromJson(json['docs'] as Map<String, dynamic>)
            : null,
      );

  final bool err;
  final String message;
  final DriverDocs? docs;

  Map<String, dynamic> toJson() => {
        'err': err,
        'message': message,
        if (docs != null) 'docs': docs!.toJson(),
      };
}
