import 'package:flutter/material.dart';

class ClaimModel {
  final String id;
  final String itemId;
  final String? itemTitle;
  final List<String> itemPhotos;
  final String? itemInstitutionName;
  final String? itemInstitutionId;
  final String claimantId;
  final String? claimantName;
  final String? claimantEmail;
  final String? claimantPhone;
  final String status;
  final String proofDescription;
  final String? proofImageUrl;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedById;
  final bool ownerConfirmed;
  final DateTime? confirmedAt;

  const ClaimModel({
    required this.id,
    required this.itemId,
    this.itemTitle,
    this.itemPhotos = const [],
    this.itemInstitutionName,
    this.itemInstitutionId,
    required this.claimantId,
    this.claimantName,
    this.claimantEmail,
    this.claimantPhone,
    required this.status,
    this.proofDescription = '',
    this.proofImageUrl,
    this.rejectionReason,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedById,
    this.ownerConfirmed = false,
    this.confirmedAt,
  });

  factory ClaimModel.fromJson(Map<String, dynamic> json) {
    String itemId = '';
    String? itemTitle;
    List<String> itemPhotos = [];
    String? itemInstitutionName;
    String? itemInstitutionId;

    final item = json['item'];
    if (item is Map) {
      itemId = item['_id'] as String? ?? item['id'] as String? ?? '';
      itemTitle = item['title'] as String?;
      itemPhotos = (item['photos'] as List?)?.cast<String>() ?? [];
      final inst = item['institution'];
      if (inst is Map) {
        itemInstitutionName = inst['name'] as String?;
        itemInstitutionId = inst['_id'] as String? ?? inst['id'] as String?;
      } else if (inst is String) {
        itemInstitutionId = inst;
      }
    } else if (item is String) {
      itemId = item;
    }

    String claimantId = '';
    String? claimantName;
    String? claimantEmail;
    String? claimantPhone;
    final claimant = json['claimant'];
    if (claimant is Map) {
      claimantId = claimant['_id'] as String? ?? claimant['id'] as String? ?? '';
      claimantName = claimant['fullName'] as String?;
      claimantEmail = claimant['email'] as String?;
      claimantPhone = claimant['phone'] as String?;
    } else if (claimant is String) {
      claimantId = claimant;
    }

    String? reviewedById;
    final reviewedBy = json['reviewedBy'];
    if (reviewedBy is Map) {
      reviewedById = reviewedBy['_id'] as String?;
    } else if (reviewedBy is String) {
      reviewedById = reviewedBy;
    }

    return ClaimModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      itemId: itemId,
      itemTitle: itemTitle,
      itemPhotos: itemPhotos,
      itemInstitutionName: itemInstitutionName,
      itemInstitutionId: itemInstitutionId,
      claimantId: claimantId,
      claimantName: claimantName,
      claimantEmail: claimantEmail,
      claimantPhone: claimantPhone,
      status: json['status'] as String? ?? 'submitted',
      proofDescription: json['proofDescription'] as String? ?? '',
      proofImageUrl: json['proofImageUrl'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.tryParse(json['reviewedAt'] as String)
          : null,
      reviewedById: reviewedById,
      ownerConfirmed: json['ownerConfirmed'] as bool? ?? false,
      confirmedAt: json['confirmedAt'] != null
          ? DateTime.tryParse(json['confirmedAt'] as String)
          : null,
    );
  }

  Color get statusColor {
    switch (status) {
      case 'submitted':
        return Colors.blue;
      case 'under_review':
        return Colors.orange;
      case 'approved':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      case 'returned':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'under_review':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'returned':
        return 'Returned';
      default:
        return status;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'submitted':
        return Icons.send_rounded;
      case 'under_review':
        return Icons.manage_search_rounded;
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'returned':
        return Icons.done_all_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  bool get canChat => status == 'approved' || status == 'returned';
}
