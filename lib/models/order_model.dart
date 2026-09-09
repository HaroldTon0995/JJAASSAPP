import 'package:flutter/material.dart';

enum OrderStatus {
  pending,
  confirmed,
  assigned,
  onDelivery,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.assigned:
        return 'Assigned';
      case OrderStatus.onDelivery:
        return 'On Delivery';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.confirmed:
        return const Color(0xFF8B5CF6);
      case OrderStatus.assigned:
        return const Color(0xFFF43F5E);
      case OrderStatus.onDelivery:
        return const Color(0xFF0284C7);
      case OrderStatus.completed:
        return const Color(0xFF10B981);
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }
}

class OrderModel {
  final String id;
  final String txnId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String waterType;
  final int quantity;
  final double pricePerUnit;
  final double totalAmount;
  final String paymentMethod;
  String paymentStatus; // 'Pending' or 'Paid'
  OrderStatus orderStatus;
  String? driverId;
  String? driverName;
  final DateTime createdAt;
  DateTime? completedAt;
  final String distance;
  final double? latitude;
  final double? longitude;

  OrderModel({
    required this.id,
    required this.txnId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.waterType,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    this.driverId,
    this.driverName,
    required this.createdAt,
    this.completedAt,
    this.distance = '1.5 km',
    this.latitude,
    this.longitude,
  });

  String get formattedTotal => '₱${totalAmount.toStringAsFixed(2)}';
  String get itemsSummary => '$quantity x $waterType';

  bool get isWalkIn =>
      customerId == 'usr_walkin_guest' ||
      deliveryAddress.toLowerCase().contains('walk-in') ||
      deliveryAddress.toLowerCase().contains('pickup');

  bool get requiresDriver => !isWalkIn;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'txnId': txnId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'waterType': waterType,
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'orderStatus': orderStatus.name,
      'driverId': driverId,
      'driverName': driverName,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'distance': distance,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      txnId: json['txnId'] as String,
      customerId: json['customerId'] as String,
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String? ?? '+63 912 345 6789',
      deliveryAddress: json['deliveryAddress'] as String,
      waterType: json['waterType'] as String,
      quantity: (json['quantity'] as num).toInt(),
      pricePerUnit: (json['pricePerUnit'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] as String,
      paymentStatus: json['paymentStatus'] as String,
      orderStatus: OrderStatus.values.byName(json['orderStatus'] as String),
      driverId: json['driverId'] as String?,
      driverName: json['driverName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      distance: json['distance'] as String? ?? '1.5 km',
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    );
  }
}
