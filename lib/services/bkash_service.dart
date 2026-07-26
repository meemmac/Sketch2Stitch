import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// ─── bKash Sandbox Credentials ───────────────────────────────────────────
// Public sandbox values — safe to commit for development.
// Replace with live credentials (from bKash Merchant Portal) before release.
// See: https://developer.bka.sh/docs/tokenized-checkout-overview
const bool _isSandbox = true;
const String _sandboxBase =
    'https://tokenized.sandbox.bka.sh/v1.2.0-beta/tokenized';
const String _liveBase = 'https://tokenized.pay.bka.sh/v1.2.0-beta/tokenized';

const String _appKey = '4f6o0cjiki2rfm34kfdadl1eqq';
const String _appSecret = '2is7hdktrekvrbljjh44ll3d9l1dtjo4pasmjvs5vl5qr3fug4b';
const String _username = 'sandboxTokenizedUser02';
const String _password = 'sandboxTokenizedUser02@12345';

// ─── Exception ───────────────────────────────────────────────────────────

class BkashException implements Exception {
  final String message;
  final String? statusCode;

  const BkashException(this.message, {this.statusCode});

  @override
  String toString() => 'BkashException: $message${statusCode != null ? ' (code: $statusCode)' : ''}';
}

// ─── Result models ───────────────────────────────────────────────────────

class BkashTokenResult {
  final String idToken;
  final String refreshToken;
  const BkashTokenResult({required this.idToken, required this.refreshToken});
}

class BkashPaymentResult {
  final String paymentID;
  final String bkashURL;
  const BkashPaymentResult({required this.paymentID, required this.bkashURL});
}

class BkashExecuteResult {
  final String paymentID;
  final String trxID;
  final String transactionStatus; // 'Completed', 'Initiated', etc.
  final double amount;

  const BkashExecuteResult({
    required this.paymentID,
    required this.trxID,
    required this.transactionStatus,
    required this.amount,
  });

  bool get isCompleted => transactionStatus == 'Completed';
}

// ─── Service ─────────────────────────────────────────────────────────────

/// bKash Tokenized Checkout v1.2.0-beta service.
///
/// Usage flow:
///   1. [grantToken]      — get id_token / refresh_token
///   2. [createPayment]   — get bkashURL + paymentID
///   3. [launchBkashUrl]  — open bkashURL in browser (user pays)
///   4. [executePayment]  — confirm payment after user returns to app
///
/// All network errors and non-200 responses throw [BkashException].
class BkashService {
  BkashService._();
  static final BkashService instance = BkashService._();

  String get _base => _isSandbox ? _sandboxBase : _liveBase;

  Map<String, String> get _baseHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ── Grant Token ────────────────────────────────────────────────────

  /// Obtains a fresh id_token using App Key + App Secret + credentials.
  /// Call this immediately before [createPayment] — tokens are short-lived.
  Future<BkashTokenResult> grantToken() async {
    final uri = Uri.parse('$_base/checkout/token/grant');
    final body = jsonEncode({
      'app_key': _appKey,
      'app_secret': _appSecret,
    });
    final headers = {
      ..._baseHeaders,
      'username': _username,
      'password': _password,
    };

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));

    final data = _parseResponse(response, 'grantToken');

    final token = data['id_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (token == null || refresh == null) {
      throw const BkashException('grantToken: missing token fields in response');
    }
    return BkashTokenResult(idToken: token, refreshToken: refresh);
  }

  // ── Create Payment ─────────────────────────────────────────────────

  /// Initiates a new payment session.
  ///
  /// [amount]            — payment amount in BDT (e.g. 1200.00)
  /// [merchantInvoiceNo] — unique invoice ID you generate per transaction
  /// [idToken]           — from [grantToken]
  /// [callbackURL]       — where bKash redirects after the user pays.
  ///                       For mobile apps, use a deep-link or any HTTPS URL
  ///                       you can detect. The default is a placeholder.
  Future<BkashPaymentResult> createPayment({
    required double amount,
    required String merchantInvoiceNo,
    required String idToken,
    // After payment, bKash redirects here. Using google.com avoids the
    // "site not found" error while we await a real backend callback URL.
    String callbackURL = 'https://www.google.com',
    String currency = 'BDT',
    String intent = 'sale',
  }) async {
    final uri = Uri.parse('$_base/checkout/create');
    final body = jsonEncode({
      'mode': '0011', // Tokenized Checkout mode
      'payerReference': ' ',
      'callbackURL': callbackURL,
      'amount': amount.toStringAsFixed(2),
      'currency': currency,
      'intent': intent,
      'merchantInvoiceNumber': merchantInvoiceNo,
    });
    final headers = {
      ..._baseHeaders,
      'Authorization': idToken,
      'X-APP-Key': _appKey,
    };

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));

    final data = _parseResponse(response, 'createPayment');

    final paymentID = data['paymentID'] as String?;
    final bkashURL = data['bkashURL'] as String?;
    if (paymentID == null || bkashURL == null) {
      throw const BkashException('createPayment: missing paymentID or bkashURL');
    }
    return BkashPaymentResult(paymentID: paymentID, bkashURL: bkashURL);
  }

  // ── Execute Payment ────────────────────────────────────────────────

  /// Confirms the payment after the user completes it in the bKash page.
  /// Call this after the user returns to the app from the bKash browser.
  Future<BkashExecuteResult> executePayment({
    required String paymentID,
    required String idToken,
  }) async {
    final uri = Uri.parse('$_base/checkout/execute');
    final body = jsonEncode({'paymentID': paymentID});
    final headers = {
      ..._baseHeaders,
      'Authorization': idToken,
      'X-APP-Key': _appKey,
    };

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));

    final data = _parseResponse(response, 'executePayment');

    final status = data['transactionStatus'] as String? ?? 'Unknown';
    final trxID = data['trxID'] as String? ?? '';
    final rawAmount = data['amount'];
    final amount = rawAmount is String
        ? double.tryParse(rawAmount) ?? 0.0
        : (rawAmount as num?)?.toDouble() ?? 0.0;

    if (status != 'Completed') {
      throw BkashException(
        'executePayment: transaction not completed (status: $status)',
        statusCode: status,
      );
    }
    return BkashExecuteResult(
      paymentID: paymentID,
      trxID: trxID,
      transactionStatus: status,
      amount: amount,
    );
  }

  // ── Query Payment ──────────────────────────────────────────────────

  /// Polls the status of an existing payment. Useful when the user returns
  /// to the app and you want to confirm before calling execute.
  Future<Map<String, dynamic>> queryPayment({
    required String paymentID,
    required String idToken,
  }) async {
    final uri = Uri.parse('$_base/checkout/payment/status');
    final body = jsonEncode({'paymentID': paymentID});
    final headers = {
      ..._baseHeaders,
      'Authorization': idToken,
      'X-APP-Key': _appKey,
    };

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));

    return _parseResponse(response, 'queryPayment');
  }

  // ── Launch URL ─────────────────────────────────────────────────────

  /// Opens the bKash payment page in the device browser.
  ///
  /// Launch order:
  ///   1. inAppBrowserView  → Chrome Custom Tabs (Android) / SFSafariViewController (iOS).
  ///      Works even when the device's default browser doesn't register standard
  ///      https intents (common on TECNO / Transsion / OEM-skin devices).
  ///   2. externalApplication → fires an ACTION_VIEW intent to the default browser.
  ///   3. platformDefault     → lets Android/iOS pick any handler.
  Future<bool> launchBkashUrl(String bkashURL) async {
    // bKash URLs may contain raw characters like ( ) ! that Uri.parse handles
    // but that can confuse Android's intent resolver — encode the query string.
    final rawUri = Uri.parse(bkashURL);
    // Rebuild the URI so Dart properly percent-encodes query components.
    final uri = rawUri.hasQuery
        ? rawUri.replace(
            queryParameters: rawUri.queryParameters, // re-encodes query params
          )
        : rawUri;

    for (final mode in [
      LaunchMode.inAppBrowserView,   // Chrome Custom Tabs — most reliable
      LaunchMode.externalApplication, // System browser via ACTION_VIEW intent
      LaunchMode.platformDefault,     // OS picks any matching handler
    ]) {
      try {
        final launched = await launchUrl(uri, mode: mode);
        if (launched) return true;
      } catch (_) {
        // Try next mode.
      }
    }
    return false;
  }

  // ── Full Payment Flow ──────────────────────────────────────────────

  /// Convenience method: grant token → create payment → launch browser.
  /// Returns the [paymentID] and [idToken] you need to call
  /// [executePayment] after the user returns to the app.
  ///
  /// [invoicePrefix] is prepended to a timestamp to form a unique invoice.
  Future<({String paymentID, String idToken})> initiatePayment({
    required double amount,
    String invoicePrefix = 'INV',
    String callbackURL = 'https://sketch2stitch.example.com/bkash/callback',
  }) async {
    final invoiceNo =
        '${invoicePrefix}_${DateTime.now().millisecondsSinceEpoch}';

    final tokenResult = await grantToken();
    final paymentResult = await createPayment(
      amount: amount,
      merchantInvoiceNo: invoiceNo,
      idToken: tokenResult.idToken,
      callbackURL: callbackURL,
    );

    final launched = await launchBkashUrl(paymentResult.bkashURL);
    if (!launched) {
      throw const BkashException('Could not open bKash payment page');
    }

    return (paymentID: paymentResult.paymentID, idToken: tokenResult.idToken);
  }

  // ── Helpers ────────────────────────────────────────────────────────

  Map<String, dynamic> _parseResponse(http.Response response, String caller) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw BkashException(
        '$caller: invalid JSON response (HTTP ${response.statusCode})',
        statusCode: response.statusCode.toString(),
      );
    }

    final statusCode = data['statusCode'] as String?;
    final statusMessage = data['statusMessage'] as String?;

    // bKash uses HTTP 200 for almost everything; errors are in the body.
    if (response.statusCode != 200 ||
        (statusCode != null && statusCode != '0000')) {
      throw BkashException(
        '$caller: ${statusMessage ?? 'unknown error'}',
        statusCode: statusCode ?? response.statusCode.toString(),
      );
    }
    return data;
  }
}
