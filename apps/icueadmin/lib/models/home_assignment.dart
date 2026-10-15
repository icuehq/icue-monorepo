// To parse this JSON data, do
//
//     final homeAssignmentResponse = homeAssignmentResponseFromJson(jsonString);

import 'dart:convert';

import 'meta_data.dart';

HomeAssignmentResponse homeAssignmentResponseFromJson(String str) =>
    HomeAssignmentResponse.fromJson(json.decode(str));

String homeAssignmentResponseToJson(HomeAssignmentResponse data) =>
    json.encode(data.toJson());

class HomeAssignmentResponse {
  HomeAssignmentResponse({
    required this.metadata,
    required this.data,
    required this.err,
    required this.message,
  });

  factory HomeAssignmentResponse.fromJson(Map<String, dynamic> json) =>
      HomeAssignmentResponse(
        metadata: Metadata.fromJson(json['metadata']),
        data: List<HomeAssignment>.from(
          json['data'].map((x) => HomeAssignment.fromJson(x)),
        ),
        err: json['err'],
        message: json['message'],
      );

  final List<HomeAssignment> data;
  final bool err;
  final String message;
  final Metadata metadata;

  Map<String, dynamic> toJson() => {
    'metadata': metadata.toJson(),
    'data': List<dynamic>.from(data.map((x) => x.toJson())),
    'err': err,
    'message': message,
  };
}

class HomeAssignment {
  HomeAssignment({
    required this.id,
    required this.section,
    required this.standard,
    required this.numberOfStudents,
    required this.homeWorkDate,
    required this.subject,
    required this.work,
    required this.submissionDate,
    required this.images,
    required this.isActive,
  });

  factory HomeAssignment.fromJson(Map<String, dynamic> json) => HomeAssignment(
    id: json['Id'],
    section: json['Section'],
    standard: json['Standard'],
    numberOfStudents: json['NumberOfStudents'],
    homeWorkDate: json['HomeWorkDate'],
    subject: json['Subject'],
    work: json['Work'],
    submissionDate: json['SubmissionDate'],
    images: List<String>.from(json['Images'].map((x) => x)),
    isActive: json['IsActive'],
  );

  final String homeWorkDate;
  final int id;
  final List<String> images;
  final bool isActive;
  final int numberOfStudents;
  final String section;
  final String standard;
  final String subject;
  final String submissionDate;
  final String work;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Section': section,
    'Standard': standard,
    'NumberOfStudents': numberOfStudents,
    'HomeWorkDate': homeWorkDate,
    'Subject': subject,
    'Work': work,
    'SubmissionDate': submissionDate,
    'Images': List<dynamic>.from(images.map((x) => x)),
    'IsActive': isActive,
  };
}

DocumentImagesResponse documentImagesResponseFromJson(String str) =>
    DocumentImagesResponse.fromJson(json.decode(str));

String documentImagesResponseToJson(DocumentImagesResponse data) =>
    json.encode(data.toJson());

class DocumentImagesResponse {
  DocumentImagesResponse({
    required this.err,
    required this.message,
    required this.images,
  });

  factory DocumentImagesResponse.fromJson(Map<String, dynamic> json) =>
      DocumentImagesResponse(
        err: json['err'],
        message: json['message'],
        images: List<Image>.from(json['Images'].map((x) => Image.fromJson(x))),
      );

  final bool err;
  final List<Image> images;
  final String message;

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'Images': List<dynamic>.from(images.map((x) => x.toJson())),
  };
}

class Image {
  Image({required this.documentId, required this.imageUrl});

  factory Image.fromJson(Map<String, dynamic> json) =>
      Image(documentId: json['DocumentId'], imageUrl: json['ImageUrl']);

  final String documentId;
  final String imageUrl;

  Map<String, dynamic> toJson() => {
    'DocumentId': documentId,
    'ImageUrl': imageUrl,
  };
}
