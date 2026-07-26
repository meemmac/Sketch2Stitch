import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A full-screen page that loads the bKash payment URL inside an in-app
/// WebView. When bKash redirects to the callback URL after the user
/// finishes paying, the WebView intercepts the redirect and pops
/// itself — the user never sees an error page and never has to manually
/// close anything.
///
/// Returns `true` if the redirect was intercepted (payment likely
/// completed), or `false` / `null` if the user manually closed the page.
///
/// Usage:
/// ```dart
/// final success = await Navigator.push<bool>(
///   context,
///   MaterialPageRoute(
///     builder: (_) => BkashPaymentScreen(
///       bkashURL: paymentResult.bkashURL,
///       callbackURL: 'https://www.google.com',
///     ),
///   ),
/// );
/// ```
class BkashPaymentScreen extends StatefulWidget {
  final String bkashURL;
  final String callbackURL;

  const BkashPaymentScreen({
    super.key,
    required this.bkashURL,
    this.callbackURL = 'https://www.google.com',
  });

  @override
  State<BkashPaymentScreen> createState() => _BkashPaymentScreenState();
}

class _BkashPaymentScreenState extends State<BkashPaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            // When bKash redirects to the callback URL, intercept it
            // and pop back with success = true. The user never sees
            // the callback page — the WebView closes instantly.
            if (request.url.startsWith(widget.callbackURL)) {
              if (mounted) Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            // If the callback URL itself causes a load error (e.g.
            // custom scheme), treat it as a successful redirect.
            if (error.url != null &&
                error.url!.startsWith(widget.callbackURL)) {
              if (mounted) Navigator.pop(context, true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.bkashURL));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text(
          'bKash Payment',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1B5E20),
              ),
            ),
        ],
      ),
    );
  }
}
