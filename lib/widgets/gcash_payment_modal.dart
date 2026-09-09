import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/helpers.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../services/payment_service.dart';

class GCashPaymentModal extends StatefulWidget {
  final OrderModel order;
  final PaymentResponse paymentResponse;
  final PaymentService paymentService;
  final bool isDark;
  final VoidCallback? onPaymentSuccess;

  const GCashPaymentModal({
    super.key,
    required this.order,
    required this.paymentResponse,
    required this.paymentService,
    required this.isDark,
    this.onPaymentSuccess,
  });

  /// Static helper to initiate payment and open the checkout modal.
  static Future<void> show(
    BuildContext context, {
    required OrderModel order,
    required PaymentService paymentService,
    bool isDark = false,
    String role = 'customer',
    VoidCallback? onPaymentSuccess,
  }) async {
    // Show clean loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007DFE)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Connecting to GCash...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    PaymentResponse? response;
    try {
      response = await paymentService.initiateGCashPayment(
        orderId: order.id,
        amount: order.totalAmount,
        role: role,
      );
    } catch (e) {
      debugPrint('Failed to initiate GCash payment: $e');
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading

    if (response == null) {
      Helpers.showSnackBar(
        context,
        'Unable to initialize GCash checkout. Please try again.',
        isError: true,
      );
      return;
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => GCashPaymentModal(
          order: order,
          paymentResponse: response!,
          paymentService: paymentService,
          isDark: isDark,
          onPaymentSuccess: onPaymentSuccess,
        ),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: GCashPaymentModal(
              order: order,
              paymentResponse: response!,
              paymentService: paymentService,
              isDark: isDark,
              onPaymentSuccess: onPaymentSuccess,
            ),
          ),
        ),
      );
    }
  }

  @override
  State<GCashPaymentModal> createState() => _GCashPaymentModalState();
}

class _GCashPaymentModalState extends State<GCashPaymentModal>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  bool _isChecking = false;
  bool _isSuccess = false;
  bool _showQrCode = false;
  bool _hasAutoLaunched = false;
  String? _statusMessage;

  static const Color gcashBlue = Color(0xFF007DFE);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Auto-polling for payment confirmation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPolling();
      _autoLaunchIfMobile();
    });
  }

  void _autoLaunchIfMobile() {
    final isMobile = MediaQuery.of(context).size.width < 700;
    if (isMobile &&
        !_hasAutoLaunched &&
        widget.paymentResponse.redirectUrl.isNotEmpty &&
        !widget.paymentResponse.isMock) {
      _hasAutoLaunched = true;
      _launchCheckoutUrl();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 3000), (timer) {
      if (!_isChecking && !_isSuccess) {
        _checkStatus(isBackgroundPoll: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isSuccess) {
      // Returned from GCash or browser
      _checkStatus(isBackgroundPoll: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _launchCheckoutUrl() async {
    final url = widget.paymentResponse.redirectUrl;
    if (url.isEmpty) return;

    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        Helpers.showSnackBar(
          context,
          'Please tap "Open GCash" or copy the payment link.',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('Error launching payment URL: $e');
    }
  }

  void _copyPaymentLink() {
    final url = widget.paymentResponse.redirectUrl;
    if (url.isEmpty) return;

    Clipboard.setData(ClipboardData(text: url));
    Helpers.showSnackBar(
      context,
      'Payment link copied to clipboard.',
    );
  }

  Future<void> _checkStatus({bool isBackgroundPoll = false}) async {
    if (_isChecking || _isSuccess || !mounted) return;

    if (!isBackgroundPoll) {
      setState(() {
        _isChecking = true;
        _statusMessage = 'Checking payment status...';
      });
    }

    try {
      final isPaid = await widget.paymentService.checkPaymentStatus(
        widget.paymentResponse.paymentIntentId,
      );

      if (isPaid && mounted) {
        _handlePaymentSuccess();
        return;
      }
    } catch (e) {
      debugPrint('Error verifying GCash status: $e');
    } finally {
      if (mounted && !isBackgroundPoll && !_isSuccess) {
        setState(() {
          _isChecking = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _handlePaymentSuccess() async {
    if (_isSuccess) return;

    _pollTimer?.cancel();
    setState(() {
      _isSuccess = true;
      _isChecking = false;
    });

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    await orderProvider.markOrderAsPaid(widget.order.id);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? AppTheme.darkSurface : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: Colors.white10) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: _isSuccess
            ? _buildSuccessView(isDark)
            : _buildCheckoutView(isDark),
      ),
    );
  }

  Widget _buildCheckoutView(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;
    final containerBg = isDark ? const Color(0xFF1E2430) : const Color(0xFFF8F9FA);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: gcashBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: gcashBlue,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GCash Payment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Order #${widget.order.id}',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              onPressed: () {
                _pollTimer?.cancel();
                Navigator.of(context).pop();
              },
              icon: Icon(Icons.close, size: 20, color: subtextColor),
              splashRadius: 20,
              tooltip: 'Close',
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Total Amount Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: containerBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 12,
                      color: subtextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.order.quantity}x ${widget.order.waterType}',
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '₱${widget.order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: gcashBlue,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Primary Action Button (Open GCash)
        if (widget.paymentResponse.redirectUrl.isNotEmpty && !widget.paymentResponse.isMock) ...[
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _launchCheckoutUrl,
              style: ElevatedButton.styleFrom(
                backgroundColor: gcashBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.open_in_new, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Open GCash',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _copyPaymentLink,
                  icon: Icon(Icons.link, size: 16, color: subtextColor),
                  label: Text(
                    'Copy Link',
                    style: TextStyle(
                      fontSize: 13,
                      color: subtextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showQrCode = !_showQrCode;
                    });
                  },
                  icon: Icon(
                    _showQrCode ? Icons.visibility_off_outlined : Icons.qr_code_2_outlined,
                    size: 16,
                    color: subtextColor,
                  ),
                  label: Text(
                    _showQrCode ? 'Hide QR' : 'Show QR',
                    style: TextStyle(
                      fontSize: 13,
                      color: subtextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],

        // QR Code Preview (Optional)
        if (_showQrCode) ...[
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  if (widget.paymentResponse.qrCodeUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.paymentResponse.qrCodeUrl!,
                        height: 160,
                        width: 160,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            height: 160,
                            width: 160,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        },
                        errorBuilder: (context, err, stack) =>
                            const Icon(Icons.qr_code_2, size: 160, color: Colors.black87),
                      ),
                    )
                  else
                    const Icon(Icons.qr_code_2, size: 160, color: Colors.black87),
                  const SizedBox(height: 8),
                  Text(
                    'Scan with GCash app to pay',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 6),

        // Status Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: containerBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(subtextColor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _statusMessage ?? 'Waiting for payment confirmation...',
                  style: TextStyle(
                    fontSize: 12,
                    color: subtextColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Secondary Action: Refresh / Check Status
        SizedBox(
          height: 42,
          child: OutlinedButton(
            onPressed: _isChecking ? null : () => _checkStatus(isBackgroundPoll: false),
            style: OutlinedButton.styleFrom(
              foregroundColor: textColor,
              side: BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isChecking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'I Have Paid (Verify)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
          ),
        ),

        const SizedBox(height: 6),

        // Cancel / Dismiss
        TextButton(
          onPressed: () {
            _pollTimer?.cancel();
            Navigator.of(context).pop();
          },
          child: Text(
            'Pay with Cash on Delivery instead',
            style: TextStyle(
              fontSize: 12,
              color: subtextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;
    final containerBg = isDark ? const Color(0xFF1E2430) : const Color(0xFFF8F9FA);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.check,
                color: Colors.green,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Payment Received',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Your transaction has been verified successfully.',
            style: TextStyle(
              fontSize: 13,
              color: subtextColor,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Receipt Details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: containerBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              _buildRow('Order ID', '#${widget.order.id}', textColor, subtextColor),
              const SizedBox(height: 10),
              _buildRow('Items', '${widget.order.quantity}x ${widget.order.waterType}', textColor, subtextColor),
              const SizedBox(height: 10),
              _buildRow('Payment Method', 'GCash', textColor, subtextColor),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              _buildRow(
                'Amount Paid',
                '₱${widget.order.totalAmount.toStringAsFixed(2)}',
                gcashBlue,
                subtextColor,
                isBold: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onPaymentSuccess?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(
    String label,
    String value,
    Color valueColor,
    Color labelColor, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: labelColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
