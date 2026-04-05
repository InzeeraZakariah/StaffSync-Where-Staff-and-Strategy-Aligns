class GroupModel {
  final int id;
  final String name;
  final String? description;
  final String? department;
  final int? createdBy;
  final bool isActive;
  final String? avatarUrl;
  final int memberCount;
  final String createdAt;
  final List<GroupMember> members;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.department,
    this.createdBy,
    required this.isActive,
    this.avatarUrl,
    required this.memberCount,
    required this.createdAt,
    this.members = const [],
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      department: json['department'],
      createdBy: json['created_by'],
      isActive: json['is_active'] ?? true,
      avatarUrl: json['avatar_url'],
      memberCount: json['member_count'] ?? 0,
      createdAt: json['created_at'],
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => GroupMember.fromJson(m))
              .toList() ??
          [],
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class GroupMember {
  final int id;
  final String fullName;
  final String department;
  final String designation;
  final String? avatarUrl;

  const GroupMember({
    required this.id,
    required this.fullName,
    required this.department,
    required this.designation,
    this.avatarUrl,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'],
      fullName: json['full_name'],
      department: json['department'],
      designation: json['designation'],
      avatarUrl: json['avatar_url'],
    );
  }

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.substring(0, 2).toUpperCase();
  }
}

class MessageModel {
  final int id;
  final int groupId;
  final MessageSender? sender;
  final String messageType;
  final String? content;
  final String? fileUrl;
  final String? fileName;
  final bool isDeleted;
  final int? replyToId;
  final String createdAt;

  const MessageModel({
    required this.id,
    required this.groupId,
    this.sender,
    required this.messageType,
    this.content,
    this.fileUrl,
    this.fileName,
    required this.isDeleted,
    this.replyToId,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      groupId: json['group_id'],
      sender: json['sender'] != null
          ? MessageSender.fromJson(json['sender'])
          : null,
      messageType: json['message_type'] ?? 'text',
      content: json['content'],
      fileUrl: json['file_url'],
      fileName: json['file_name'],
      isDeleted: json['is_deleted'] ?? false,
      replyToId: json['reply_to_id'],
      createdAt: json['created_at'],
    );
  }
}

class MessageSender {
  final int id;
  final String fullName;
  final String? avatarUrl;
  final String department;

  const MessageSender({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.department,
  });

  factory MessageSender.fromJson(Map<String, dynamic> json) {
    return MessageSender(
      id: json['id'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      department: json['department'],
    );
  }

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.substring(0, 2).toUpperCase();
  }
}