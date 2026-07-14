import 'package:crmapp/data/models/common_models.dart';

class LeadDocument {
  final String id;
  final String label;
  final String fieldKey;
  final String fileType;
  final int size;
  final String r2Key;
  final bool isLocked;
  final String uploadedBy; // 'Staff' or 'Client'
  final UploaderInfo? uploader;
  final String createdAt;
  final IdName? lead; // Included in global list

  LeadDocument({
    required this.id,
    required this.label,
    required this.fieldKey,
    required this.fileType,
    required this.size,
    required this.r2Key,
    required this.isLocked,
    required this.uploadedBy,
    this.uploader,
    required this.createdAt,
    this.lead,
  });

  factory LeadDocument.fromJson(Map<String, dynamic> json) {
    return LeadDocument(
      id: json['_id'] ?? json['id'] ?? '',
      label: json['label'] ?? '',
      fieldKey: json['fieldKey'] ?? '',
      fileType: json['fileType'] ?? '',
      size: json['size'] ?? 0,
      r2Key: json['r2Key'] ?? '',
      isLocked: json['isLocked'] ?? false,
      uploadedBy: json['uploadedBy'] ?? 'Staff',
      uploader: json['uploader'] is Map<String, dynamic> ? UploaderInfo.fromJson(json['uploader']) : null,
      createdAt: json['createdAt'] ?? '',
      lead: json['lead'] is Map<String, dynamic> ? IdName.fromJson(json['lead']) : null,
    );
  }
}

class UploaderInfo {
  final String name;
  final String systemRole;

  UploaderInfo({required this.name, required this.systemRole});

  factory UploaderInfo.fromJson(Map<String, dynamic> json) {
    return UploaderInfo(
      name: json['name'] ?? '',
      systemRole: json['systemRole'] ?? '',
    );
  }
}

class DocumentFormField {
  final String label;
  final bool required;

  DocumentFormField({required this.label, required this.required});

  factory DocumentFormField.fromJson(Map<String, dynamic> json) {
    return DocumentFormField(
      label: json['label'] ?? '',
      required: json['required'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'required': required,
  };
}

class DocumentForm {
  final String id;
  final String name;
  final List<DocumentFormField> fields;
  final bool isActive;
  final String createdAt;

  DocumentForm({
    required this.id,
    required this.name,
    required this.fields,
    required this.isActive,
    required this.createdAt,
  });

  factory DocumentForm.fromJson(Map<String, dynamic> json) {
    return DocumentForm(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      fields: (json['fields'] as List?)
              ?.map((e) => DocumentFormField.fromJson(e))
              .toList() ??
          [],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] ?? '',
    );
  }
}
