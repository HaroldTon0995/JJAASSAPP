class NotificationModel {
  final String id;
  final String? userId;
  final String? targetRole;
  final String title;
  final String message;
  final String type;
  final String? orderId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    this.userId,
    this.targetRole,
    required this.title,
    required this.message,
    this.type = 'order_update',
    this.orderId,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'target_role': targetRole,
      'title': title,
      'message': message,
      'type': type,
      'order_id': orderId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
      userId: json['user_id']?.toString() ?? json['userId']?.toString(),
      targetRole: json['target_role']?.toString() ?? json['targetRole']?.toString(),
      title: json['title']?.toString() ?? 'New Notification',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'order_update',
      orderId: json['order_id']?.toString() ?? json['orderId']?.toString(),
      isRead: json['is_read'] as bool? ?? json['isRead'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
