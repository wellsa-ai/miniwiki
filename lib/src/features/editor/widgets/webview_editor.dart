import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// TipTap-based rich text editor using WKWebView.
/// Bypasses Flutter's broken macOS IME handling for proper Korean input.
class WebViewEditor extends StatefulWidget {
  final String initialContent;
  final bool isDarkMode;
  final ValueChanged<String>? onContentChanged;

  const WebViewEditor({
    super.key,
    this.initialContent = '',
    this.isDarkMode = false,
    this.onContentChanged,
  });

  @override
  State<WebViewEditor> createState() => WebViewEditorState();
}

class WebViewEditorState extends State<WebViewEditor> {
  InAppWebViewController? _controller;
  bool _isReady = false;

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  Future<String> getContent() async {
    if (_controller == null || !_isReady) return widget.initialContent;
    final result = await _controller!.evaluateJavascript(
      source: 'window.getContent()',
    );
    return result?.toString() ?? '';
  }

  Future<void> setContent(String html) async {
    if (_controller == null || !_isReady) return;
    final escaped = html
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
    await _controller!.evaluateJavascript(
      source: "window.setContent('$escaped')",
    );
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialFile: 'assets/editor/editor.html',
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        disableHorizontalScroll: true,
        supportZoom: false,
        allowsBackForwardNavigationGestures: false,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'onContentChanged',
          callback: (args) {
            if (args.isNotEmpty) {
              widget.onContentChanged?.call(args[0].toString());
            }
          },
        );
      },
      onLoadStop: (controller, url) async {
        _isReady = true;
        // Apply dark mode
        if (widget.isDarkMode) {
          await controller.evaluateJavascript(
            source: 'window.setDarkMode(true)',
          );
        }
        // Set initial content
        if (widget.initialContent.isNotEmpty) {
          await setContent(widget.initialContent);
        }
      },
    );
  }
}
