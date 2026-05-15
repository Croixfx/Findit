import 'package:flutter/material.dart';

class ItemModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String color;
  final String brand;
  final String condition;
  final String locationFound;
  final DateTime? dateFound;
  final String? storageReference;
  final List<String> photos;
  final String status;
  final String institutionId;
  final String institutionName;
  final String? institutionType;
  final String loggedById;
  final String? loggedByName;
  final DateTime createdAt;

  const ItemModel({
    required this.id,
    required this.title,
    this.description = '',
    this.category = '',
    this.color = '',
    this.brand = '',
    this.condition = '',
    this.locationFound = '',
    this.dateFound,
    this.storageReference,
    this.photos = const [],
    required this.status,
    required this.institutionId,
    this.institutionName = '',
    this.institutionType,
    required this.loggedById,
    this.loggedByName,
    required this.createdAt,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    String institutionId = '';
    String institutionName = '';
    String? institutionType;
    final inst = json['institution'];
    if (inst is Map) {
      institutionId = inst['_id'] as String? ?? inst['id'] as String? ?? '';
      institutionName = inst['name'] as String? ?? '';
      institutionType = inst['type'] as String?;
    } else if (inst is String) {
      institutionId = inst;
    }

    String loggedById = '';
    String? loggedByName;
    final loggedBy = json['loggedBy'];
    if (loggedBy is Map) {
      loggedById = loggedBy['_id'] as String? ?? '';
      loggedByName = loggedBy['fullName'] as String?;
    } else if (loggedBy is String) {
      loggedById = loggedBy;
    }

    return ItemModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      color: json['color'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      locationFound: json['locationFound'] as String? ?? '',
      dateFound: json['dateFound'] != null
          ? DateTime.tryParse(json['dateFound'] as String)
          : null,
      storageReference: json['storageReference'] as String?,
      photos: (json['photos'] as List?)?.cast<String>() ?? [],
      status: json['status'] as String? ?? 'available',
      institutionId: institutionId,
      institutionName: institutionName,
      institutionType: institutionType,
      loggedById: loggedById,
      loggedByName: loggedByName,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get firstPhoto => photos.isNotEmpty ? photos.first : '';
  bool get hasPhoto => photos.isNotEmpty;
  bool get isTerminal => status == 'returned' || status == 'discarded';

  Color get statusColor {
    switch (status) {
      case 'available':
        return Colors.blue;
      case 'claimed':
        return Colors.orange;
      case 'ready_for_pickup':
        return Colors.teal;
      case 'returned':
        return Colors.green;
      case 'discarded':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'available':
        return 'Available';
      case 'claimed':
        return 'Claimed';
      case 'ready_for_pickup':
        return 'Ready for Pickup';
      case 'returned':
        return 'Returned';
      case 'discarded':
        return 'Discarded';
      default:
        return status;
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'electronics':
        return Icons.phone_android_rounded;
      case 'clothing':
        return Icons.checkroom_rounded;
      case 'accessories':
        return Icons.watch_rounded;
      case 'documents':
        return Icons.description_rounded;
      case 'keys':
        return Icons.vpn_key_rounded;
      case 'bags':
        return Icons.backpack_rounded;
      case 'jewelry':
        return Icons.diamond_rounded;
      case 'money':
        return Icons.attach_money_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }
}
