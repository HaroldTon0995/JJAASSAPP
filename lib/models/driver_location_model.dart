class DriverLocationModel {
  final String driverId;
  final String driverName;
  final String? orderId;
  final double latitude;
  final double longitude;
  final double heading;
  final double speed;
  final DateTime updatedAt;

  DriverLocationModel({
    required this.driverId,
    required this.driverName,
    this.orderId,
    required this.latitude,
    required this.longitude,
    this.heading = 0.0,
    this.speed = 0.0,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'driver_id': driverId,
      'driver_name': driverName,
      'order_id': orderId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DriverLocationModel.fromJson(Map<String, dynamic> json) {
    return DriverLocationModel(
      driverId: json['driver_id']?.toString() ?? json['driverId']?.toString() ?? '',
      driverName: json['driver_name']?.toString() ?? json['driverName']?.toString() ?? 'Driver',
      orderId: json['order_id']?.toString() ?? json['orderId']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 14.5995,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 120.9842,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
