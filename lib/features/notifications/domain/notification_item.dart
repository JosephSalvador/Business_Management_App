enum NotificationCategory {
  all('Zote', 'All', null),
  cashSales('Fedha & Mauzo', 'Cash & Sales', 'Cash'),
  stock('Stock', 'Stock', 'Stock'),
  credit('Madeni', 'Credit', 'Credit');

  const NotificationCategory(this.labelSw, this.labelEn, this.apiValue);
  final String labelSw;
  final String labelEn;
  final String? apiValue;
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    this.userId,
    this.targetRole,
    this.branchId,
    required this.category,
    required this.type,
    required this.titleSw,
    required this.titleEn,
    required this.bodySw,
    required this.bodyEn,
    this.dataJson,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String? userId;
  final String? targetRole;
  final String? branchId;
  final String category;
  final String type;
  final String titleSw;
  final String titleEn;
  final String bodySw;
  final String bodyEn;
  final String? dataJson;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  String title(String languageCode) => languageCode == 'en' ? titleEn : titleSw;
  String body(String languageCode) => languageCode == 'en' ? bodyEn : bodySw;

  NotificationItem copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return NotificationItem(
      id: id,
      userId: userId,
      targetRole: targetRole,
      branchId: branchId,
      category: category,
      type: type,
      titleSw: titleSw,
      titleEn: titleEn,
      bodySw: bodySw,
      bodyEn: bodyEn,
      dataJson: dataJson,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      targetRole: json['targetRole'] as String?,
      branchId: json['branchId'] as String?,
      category: json['category'] as String? ?? 'General',
      type: json['type'] as String? ?? 'GENERAL',
      titleSw: json['titleSw'] as String? ?? '',
      titleEn: json['titleEn'] as String? ?? '',
      bodySw: json['bodySw'] as String? ?? '',
      bodyEn: json['bodyEn'] as String? ?? '',
      dataJson: json['dataJson'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
