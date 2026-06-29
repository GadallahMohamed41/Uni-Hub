import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class CvViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const CvViewerScreen({
    super.key,
    required this.url,
    this.title = 'View PDF',
  });

  @override
  State<CvViewerScreen> createState() => _CvViewerScreenState();
}

class _CvViewerScreenState extends State<CvViewerScreen> {
   late final WebViewController _controller;

  bool _loading = true;
  bool _failed = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final requestUrl = _buildViewerUrl(widget.url);

     _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _failed = true;
                _loading = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _loading = false;
                _initialized = true;
              });
            }
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _failed = false;
              });
            }
          },
        ),
      );

     try {
      await _controller.loadRequest(Uri.parse(requestUrl));
      _initialized = true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }

    // Timeout بعد 15 ثانية
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _loading && !_failed) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    });
  }

  String _buildViewerUrl(String pdfUrl) {
    if (kIsWeb) return pdfUrl;
    final encoded = Uri.encodeComponent(pdfUrl);
    return 'https://docs.google.com/gview?embedded=1&url=$encoded';
  }

  Future<void> _openExternally() async {
    final uri = Uri.parse(widget.url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('Cannot open link');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'Open in browser',
          ),
        ],
      ),
      body: Stack(
        children: [
           if (_initialized && !_failed && !_loading)
            WebViewWidget(controller: _controller),

          if (_loading && !_failed)
            const Center(child: CircularProgressIndicator()),

          if (_failed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Could not display the PDF inside the app.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tap "Open in browser" to view it.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openExternally,
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: const Text('Open in browser'),
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
