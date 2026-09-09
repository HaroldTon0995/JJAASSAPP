import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

class PaymentResponse {
  final String orderId;
  final String paymentIntentId; // Holds link ID (link_xxxx), source ID (src_xxxx), or mock ID
  final String redirectUrl;
  final String status;
  final String? qrCodeUrl;
  final bool isMock;

  PaymentResponse({
    required this.orderId,
    required this.paymentIntentId,
    required this.redirectUrl,
    required this.status,
    this.qrCodeUrl,
    this.isMock = false,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      orderId: json['order_id'] ?? '',
      paymentIntentId: json['payment_intent_id'] ?? '',
      redirectUrl: json['redirect_url'] ?? '',
      status: json['status'] ?? 'pending',
      qrCodeUrl: json['qr_code_url'],
      isMock: json['is_mock'] ?? false,
    );
  }
}

class PaymentService {
  final http.Client _client = http.Client();

  // Helper to construct basic auth header
  String _getAuthHeader(String key) {
    return 'Basic ${base64Encode(utf8.encode("$key:"))}';
  }

  /// Initiates a GCash / E-Wallet payment via PayMongo Links or Sources API.
  Future<PaymentResponse> initiateGCashPayment({
    required String orderId,
    required double amount,
    required String role,
  }) async {
    final secretKey = AppConstants.paymongoSecretKey;
    final publicKey = AppConstants.paymongoPublicKey;

    // 1. Try PayMongo Payment Links API (Most modern and officially supported by PayMongo)
    if (secretKey.isNotEmpty && !secretKey.contains('your_secret_key_here')) {
      try {
        final amountInCentavos = (amount * 100).round();
        final endpoints = kIsWeb
            ? [
                'https://api.allorigins.win/raw?url=https://api.paymongo.com/v1/links',
                'https://corsproxy.io/?https://api.paymongo.com/v1/links',
                'https://api.paymongo.com/v1/links',
              ]
            : ['https://api.paymongo.com/v1/links'];

        for (final url in endpoints) {
          try {
            final response = await _client.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': _getAuthHeader(secretKey),
              },
              body: jsonEncode({
                'data': {
                  'attributes': {
                    'amount': amountInCentavos,
                    'description': 'JJAASS Water Order #$orderId',
                    'remarks': 'Order #$orderId ($role)',
                  }
                }
              }),
            );

            if (response.statusCode == 200 || response.statusCode == 201) {
              final json = jsonDecode(response.body);
              final linkId = json['data']['id'] ?? '';
              final checkoutUrl = json['data']['attributes']['checkout_url'] ?? '';
              final status = json['data']['attributes']['status'] ?? 'unpaid';

              if (checkoutUrl.isNotEmpty) {
                return PaymentResponse(
                  orderId: orderId,
                  paymentIntentId: linkId,
                  redirectUrl: checkoutUrl,
                  status: status,
                  qrCodeUrl: getQrCodeUrl(checkoutUrl),
                  isMock: false,
                );
              }
            }
          } catch (endpointErr) {
            debugPrint('PayMongo Links attempt failed on $url: $endpointErr');
          }
        }
      } catch (e) {
        debugPrint('PayMongo Links API error: $e');
      }
    }

    // 2. Try PayMongo Sources API with Public Key
    if (publicKey.isNotEmpty && !publicKey.contains('your_public_key_here')) {
      try {
        final amountInCentavos = (amount * 100).round();
        final endpoints = kIsWeb
            ? [
                'https://api.allorigins.win/raw?url=https://api.paymongo.com/v1/sources',
                'https://corsproxy.io/?https://api.paymongo.com/v1/sources',
                'https://api.paymongo.com/v1/sources',
              ]
            : ['https://api.paymongo.com/v1/sources'];

        for (final url in endpoints) {
          try {
            final response = await _client.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': _getAuthHeader(publicKey),
              },
              body: jsonEncode({
                'data': {
                  'attributes': {
                    'type': 'gcash',
                    'amount': amountInCentavos,
                    'currency': 'PHP',
                    'redirect': {
                      'success': 'https://jjaass-water.web.app/payment-success?orderId=$orderId',
                      'failed': 'https://jjaass-water.web.app/payment-failed?orderId=$orderId'
                    },
                    'metadata': {
                      'orderId': orderId,
                    }
                  }
                }
              }),
            );

            if (response.statusCode == 200 || response.statusCode == 201) {
              final json = jsonDecode(response.body);
              final sourceId = json['data']['id'];
              final checkoutUrl = json['data']['attributes']['redirect']['checkout_url'];
              final status = json['data']['attributes']['status'];

              return PaymentResponse(
                orderId: orderId,
                paymentIntentId: sourceId,
                redirectUrl: checkoutUrl,
                status: status,
                qrCodeUrl: getQrCodeUrl(checkoutUrl),
                isMock: false,
              );
            }
          } catch (endpointErr) {
            debugPrint('PayMongo Sources attempt failed on $url: $endpointErr');
          }
        }
      } catch (e) {
        debugPrint('PayMongo Sources API error: $e');
      }
    }

    // 3. Fallback to Safe In-App Test Mode (Never opens invalid test-sources.paymongo.com URLs)
    debugPrint('Using local sandbox simulation mode for payment.');
    return _mockInitiateGCashPayment(orderId, amount);
  }

  /// Polls or checks either PayMongo directly (Links or Sources API) or the Supabase DB
  Future<bool> checkPaymentStatus(String identifier) async {
    final secretKey = AppConstants.paymongoSecretKey;

    // Check PayMongo Links API (link_xxxx)
    if (identifier.startsWith('link_')) {
      if (secretKey.isEmpty || secretKey.contains('your_secret_key_here')) {
        return false;
      }
      try {
        final endpoints = kIsWeb
            ? [
                'https://api.allorigins.win/raw?url=https://api.paymongo.com/v1/links/$identifier',
                'https://corsproxy.io/?https://api.paymongo.com/v1/links/$identifier',
                'https://api.paymongo.com/v1/links/$identifier',
              ]
            : ['https://api.paymongo.com/v1/links/$identifier'];

        for (final url in endpoints) {
          try {
            final response = await _client.get(
              Uri.parse(url),
              headers: {
                'Accept': 'application/json',
                'Authorization': _getAuthHeader(secretKey),
              },
            );

            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              final status = json['data']['attributes']['status'];
              if (status == 'paid') {
                return true;
              }
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Error retrieving link status from PayMongo: $e');
      }
      return false;
    }

    // Check PayMongo Sources API (src_xxxx)
    if (identifier.startsWith('src_') && !identifier.startsWith('src_mock_')) {
      if (secretKey.isEmpty || secretKey.contains('your_secret_key_here')) {
        return false;
      }
      try {
        final url = kIsWeb
            ? 'https://corsproxy.io/?https://api.paymongo.com/v1/sources/$identifier'
            : 'https://api.paymongo.com/v1/sources/$identifier';

        final response = await _client.get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json',
            'Authorization': _getAuthHeader(secretKey),
          },
        );

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final status = json['data']['attributes']['status'];

          if (status == 'chargeable') {
            final amount = json['data']['attributes']['amount'];
            final currency = json['data']['attributes']['currency'];

            final payUrl = kIsWeb
                ? 'https://corsproxy.io/?https://api.paymongo.com/v1/payments'
                : 'https://api.paymongo.com/v1/payments';

            final payResponse = await _client.post(
              Uri.parse(payUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': _getAuthHeader(secretKey),
              },
              body: jsonEncode({
                'data': {
                  'attributes': {
                    'amount': amount,
                    'currency': currency,
                    'source': {
                      'id': identifier,
                      'type': 'source',
                    }
                  }
                }
              }),
            );

            if (payResponse.statusCode == 200) {
              final payJson = jsonDecode(payResponse.body);
              final payStatus = payJson['data']['attributes']['status'];
              return payStatus == 'succeeded' || payStatus == 'paid';
            }
          } else if (status == 'charged') {
            return true;
          }
        }
      } catch (e) {
        debugPrint('Error retrieving source status from PayMongo: $e');
      }
      return false;
    }

    // Mock Mode identifiers
    if (identifier.startsWith('mock_') || identifier.startsWith('src_mock_')) {
      return false;
    }

    // Otherwise, check Supabase DB for Order ID status updates
    final isSupabaseConfigured = (AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
        AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY');
    if (isSupabaseConfigured) {
      try {
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('orders')
            .select('paymentStatus')
            .eq('id', identifier)
            .single();

        return response['paymentStatus'] == 'Paid';
      } catch (e) {
        debugPrint('Error checking payment status from database: $e');
      }
    }

    return false;
  }

  Future<PaymentResponse> _mockInitiateGCashPayment(String orderId, double amount) async {
    await Future.delayed(AppConstants.apiMockDelay);
    final mockId = 'mock_${DateTime.now().millisecondsSinceEpoch}';

    return PaymentResponse(
      orderId: orderId,
      redirectUrl: '',
      paymentIntentId: mockId,
      status: 'pending',
      qrCodeUrl: 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=JJAASS-GCASH-PAYMENT-ORDER-$orderId',
      isMock: true,
    );
  }

  /// Helper to generate a helper QR Code link for any checkout URL.
  String getQrCodeUrl(String redirectUrl) {
    if (redirectUrl.isEmpty) {
      return 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=JJAASS-GCASH-PAYMENT';
    }
    return 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(redirectUrl)}';
  }
}
