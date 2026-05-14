import 'package:flutter/material.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool read;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.read = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  IconData get typeIcon {
    switch (type) {
      case 'claim_approved':
        return Icons.check_circle_rounded;
      case 'claim_rejected':
        return Icons.cancel_rounded;
      case 'claim_returned':
        return Icons.done_all_rounded;
      case 'claim_under_review':
        return Icons.hourglass_top_rounded;
      case 'new_claim':
        return Icons.assignment_rounded;
      case 'institution_approved':
        return Icons.verified_rounded;
      case 'institution_rejected':
        return Icons.block_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}
