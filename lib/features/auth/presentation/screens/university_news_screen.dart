import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:project_test2/core/theme/theme.dart';

/// University news for new students without ID - embedded Facebook page
class UniversityNewsScreen extends StatefulWidget {
  const UniversityNewsScreen({super.key});

  @override
  State<UniversityNewsScreen> createState() => _UniversityNewsScreenState();
}

class _UniversityNewsScreenState extends State<UniversityNewsScreen> {
  static const String _universityFacebookUrl =
      'https://www.facebook.com/share/1AmieG2N3Q/';

  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(_universityFacebookUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('University News'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: AppTheme.surface,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading university news...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
