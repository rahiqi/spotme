import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:spotme/core/theme.dart';

class TelegramLoginScreen extends StatefulWidget {
  final String loginUrl;
  const TelegramLoginScreen({super.key, required this.loginUrl});

  @override
  State<TelegramLoginScreen> createState() => _TelegramLoginScreenState();
}

class _TelegramLoginScreenState extends State<TelegramLoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('spotme://auth')) {
              try {
                final uri = Uri.parse(request.url);
                final name = uri.queryParameters['first_name'] ?? '';
                final photoUrl = uri.queryParameters['photo_url'] ?? '';
                Navigator.pop(context, {'name': name, 'photo_url': photoUrl});
              } catch (_) {
                Navigator.pop(context);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.loginUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        title: const Text(
          'Sign in with Telegram',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            ),
        ],
      ),
    );
  }
}
