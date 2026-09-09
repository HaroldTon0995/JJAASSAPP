import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjaassapp2/services/payment_service.dart';

void main() {
  test('Test PaymentService GCash Flow', () async {
    final paymentService = PaymentService();

    // Test payment initiation
    final response = await paymentService.initiateGCashPayment(
      orderId: 'test_order_999',
      amount: 150.00,
      role: 'customer',
    );

    expect(response.orderId, 'test_order_999');
    expect(response.status, isNotEmpty);
    expect(response.redirectUrl, isNotEmpty);
    expect(response.paymentIntentId.startsWith('link_') || response.paymentIntentId.startsWith('src_'), isTrue);

    debugPrint('Initiated payment successfully:');
    debugPrint('  Order ID: ${response.orderId}');
    debugPrint('  Source ID: ${response.paymentIntentId}');
    debugPrint('  Status: ${response.status}');
    debugPrint('  Redirect URL: ${response.redirectUrl}');
    debugPrint('  QR Code: ${response.qrCodeUrl}');

    // Test checking status of the created source
    final isPaid = await paymentService.checkPaymentStatus(
      response.paymentIntentId,
    );
    expect(
      isPaid,
      isFalse,
    ); // Since it was just created and not authorized, it should be false
    debugPrint('Checked payment status successfully. isPaid: $isPaid');
  });
}
