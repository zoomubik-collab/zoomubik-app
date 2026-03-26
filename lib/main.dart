import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  runApp(ZoomubikApp());
}

class ZoomubikApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zoomubik',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late InAppWebViewController _webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri('https://www.zoomubik.com'),
          ),
          initialSettings: InAppWebViewSettings(
            useShouldOverrideUrlLoading: true,
            mediaPlaybackRequiresUserGesture: false,
            useHybridComposition: true,
            databaseEnabled: true,
            domStorageEnabled: true,
            cacheEnabled: true,
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;
            print('🌐 WebView creado');
          },
          onLoadStart: (controller, url) {
            print('⏳ Cargando: $url');
          },
          onLoadStop: (controller, url) {
            print('✅ Página cargada: $url');
          },
          onLoadError: (controller, url, code, message) {
            print('❌ Error: $code - $message');
          },
        ),
      ),
    );
  }
}
