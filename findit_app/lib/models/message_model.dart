class MessageModel {
  final String id;
  final String claimId;
  final String senderId;
  final String? senderName;
  final String content;
  final String? imageUrl;
  final bool isRead;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.claimId,
    required this.senderId,
    this.senderName,
    required this.content,
    this.imageUrl,
    this.isRead = false,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    String senderId = '';
    String? senderName;
    final sender = json['sender'];
    if (sender is Map) {
      senderId = sender['_id'] as String? ?? '';
      senderName = sender['fullName'] as String?;
    } else if (sender is String) {
      senderId = sender;
    }

    return MessageModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      claimId: json['claim'] as String? ?? '',
      senderId: senderId,
      senderName: senderName,
      content: json['content'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
