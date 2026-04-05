import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════
//   RESOURCE MODEL
// ══════════════════════════════════════════════════════════════════

class ResourceModel {
  final int id;
  final int? uploadedBy;
  final String resourceType;   // pdf | ppt | image | video | link | document
  final String title;
  final String? description;
  final String? fileUrl;
  final String? fileName;
  final int? fileSizeBytes;
  final String? mimeType;
  final String? linkUrl;
  final String visibility;     // department | all_staff | private
  final String? department;
  final int downloadCount;
  final bool isActive;
  final String? tags;          // comma-separated
  final String createdAt;
  final ResourceUploader? uploader;

  const ResourceModel({
    required this.id,
    this.uploadedBy,
    required this.resourceType,
    required this.title,
    this.description,
    this.fileUrl,
    this.fileName,
    this.fileSizeBytes,
    this.mimeType,
    this.linkUrl,
    required this.visibility,
    this.department,
    required this.downloadCount,
    required this.isActive,
    this.tags,
    required this.createdAt,
    this.uploader,
  });

  factory ResourceModel.fromJson(Map<String, dynamic> json) => ResourceModel(
        id:            json['id'] as int,
        uploadedBy:    json['uploaded_by'] as int?,
        resourceType:  json['resource_type'] as String? ?? 'document',
        title:         json['title'] as String? ?? '',
        description:   json['description'] as String?,
        fileUrl:       json['file_url'] as String?,
        fileName:      json['file_name'] as String?,
        fileSizeBytes: json['file_size_bytes'] as int?,
        mimeType:      json['mime_type'] as String?,
        linkUrl:       json['link_url'] as String?,
        visibility:    json['visibility'] as String? ?? 'department',
        department:    json['department'] as String?,
        downloadCount: json['download_count'] as int? ?? 0,
        isActive:      json['is_active'] as bool? ?? true,
        tags:          json['tags'] as String?,
        createdAt:     json['created_at'] as String? ?? '',
        uploader: json['uploader'] != null
            ? ResourceUploader.fromJson(
                json['uploader'] as Map<String, dynamic>)
            : null,
      );

  // ── Computed helpers ────────────────────────────────────────────

  bool get isLink => resourceType == 'link';
  bool get isFile => !isLink;

  List<String> get tagList => tags != null
      ? tags!.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
      : [];

  String get fileSizeLabel {
    if (fileSizeBytes == null) return '';
    final kb = fileSizeBytes! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  String get typeLabel {
    switch (resourceType) {
      case 'pdf':      return 'PDF';
      case 'ppt':      return 'PPT';
      case 'image':    return 'Image';
      case 'video':    return 'Video';
      case 'link':     return 'Link';
      default:         return 'File';
    }
  }

  IconData get typeIcon {
    switch (resourceType) {
      case 'pdf':      return Icons.picture_as_pdf_rounded;
      case 'ppt':      return Icons.slideshow_rounded;
      case 'image':    return Icons.image_rounded;
      case 'video':    return Icons.play_circle_rounded;
      case 'link':     return Icons.link_rounded;
      default:         return Icons.insert_drive_file_rounded;
    }
  }

  Color get typeColor {
    switch (resourceType) {
      case 'pdf':      return const Color(0xFFEF4444);
      case 'ppt':      return const Color(0xFFF97316);
      case 'image':    return const Color(0xFF10B981);
      case 'video':    return const Color(0xFF8B5CF6);
      case 'link':     return const Color(0xFF3B82F6);
      default:         return const Color(0xFF6B7280);
    }
  }
}

// ══════════════════════════════════════════════════════════════════
//   RESOURCE UPLOADER
// ══════════════════════════════════════════════════════════════════

class ResourceUploader {
  final int id;
  final String fullName;
  final String department;
  final String? avatarUrl;

  const ResourceUploader({
    required this.id,
    required this.fullName,
    required this.department,
    this.avatarUrl,
  });

  factory ResourceUploader.fromJson(Map<String, dynamic> json) =>
      ResourceUploader(
        id:         json['id'] as int,
        fullName:   json['full_name'] as String? ?? '',
        department: json['department'] as String? ?? '',
        avatarUrl:  json['avatar_url'] as String?,
      );

  String get initials {
    final p = fullName.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    if (fullName.length >= 2) return fullName.substring(0, 2).toUpperCase();
    return fullName.toUpperCase();
  }
}

// ══════════════════════════════════════════════════════════════════
//   RESOURCE SHARE MODEL
// ══════════════════════════════════════════════════════════════════

class ResourceShareModel {
  final int id;
  final int resourceId;
  final int? sharedToStaffId;
  final int? sharedToGroupId;
  final int? sharedBy;
  final String sharedAt;

  const ResourceShareModel({
    required this.id,
    required this.resourceId,
    this.sharedToStaffId,
    this.sharedToGroupId,
    this.sharedBy,
    required this.sharedAt,
  });

  factory ResourceShareModel.fromJson(Map<String, dynamic> json) =>
      ResourceShareModel(
        id:                json['id'] as int,
        resourceId:        json['resource_id'] as int,
        sharedToStaffId:   json['shared_to_staff_id'] as int?,
        sharedToGroupId:   json['shared_to_group_id'] as int?,
        sharedBy:          json['shared_by'] as int?,
        sharedAt:          json['shared_at'] as String? ?? '',
      );

  bool get isStaffShare => sharedToStaffId != null;
  bool get isGroupShare  => sharedToGroupId != null;
}

// ══════════════════════════════════════════════════════════════════
//   NOTE MODEL
// ══════════════════════════════════════════════════════════════════

class NoteModel {
  final int id;
  final int? createdBy;
  final String title;
  final String content;
  final String? department;
  final bool isPinned;
  final String? tags;
  final int? lastEditedBy;
  final String createdAt;
  final String updatedAt;
  final NoteAuthor? creator;
  final NoteAuthor? editor;

  const NoteModel({
    required this.id,
    this.createdBy,
    required this.title,
    required this.content,
    this.department,
    required this.isPinned,
    this.tags,
    this.lastEditedBy,
    required this.createdAt,
    required this.updatedAt,
    this.creator,
    this.editor,
  });

  // Backward-compat alias
  NoteAuthor? get author => creator;

  List<String> get tagList => tags != null
      ? tags!.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
      : [];

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
        id:            json['id'] as int,
        createdBy:     json['created_by'] as int?,
        title:         json['title'] as String? ?? '',
        content:       json['content'] as String? ?? '',
        department:    json['department'] as String?,
        isPinned:      json['is_pinned'] as bool? ?? false,
        tags:          json['tags'] as String?,
        lastEditedBy:  json['last_edited_by'] as int?,
        createdAt:     json['created_at'] as String? ?? '',
        updatedAt:     json['updated_at'] as String? ?? '',
        creator: json['creator'] != null
            ? NoteAuthor.fromJson(json['creator'] as Map<String, dynamic>)
            : null,
        editor: json['editor'] != null
            ? NoteAuthor.fromJson(json['editor'] as Map<String, dynamic>)
            : null,
      );
}

// ══════════════════════════════════════════════════════════════════
//   NOTE AUTHOR
// ══════════════════════════════════════════════════════════════════

class NoteAuthor {
  final int id;
  final String fullName;
  final String? avatarUrl;

  const NoteAuthor({
    required this.id,
    required this.fullName,
    this.avatarUrl,
  });

  factory NoteAuthor.fromJson(Map<String, dynamic> json) => NoteAuthor(
        id:        json['id'] as int,
        fullName:  json['full_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
      );

  String get initials {
    final p = fullName.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    if (fullName.length >= 2) return fullName.substring(0, 2).toUpperCase();
    return fullName.toUpperCase();
  }
}