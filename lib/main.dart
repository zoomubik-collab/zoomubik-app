import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kDebugMode) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(false);
  }

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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late InAppWebViewController _webViewController;
  final String _homeUrl = 'https://www.zoomubik.com';

  final InAppWebViewSettings _settings = InAppWebViewSettings(
    sharedCookiesEnabled: true,
    incognito: false,
    thirdPartyCookiesEnabled: true,
    databaseEnabled: true,
    domStorageEnabled: true,
    cacheEnabled: true,
    cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,
    useShouldOverrideUrlLoading: true,
    mediaPlaybackRequiresUserGesture: false,
    useHybridComposition: true,
    allowsInlineMediaPlayback: true,
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSessionAlive();
    }
  }

  Future<void> _checkSessionAlive() async {
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri(_homeUrl),
    );
    final isLoggedIn = cookies.any(
      (c) => c.name.startsWith('wordpress_logged_in'),
    );
    debugPrint(isLoggedIn ? '✅ Sesión activa' : '⚠️ Sin sesión');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(_homeUrl),
          ),
          initialSettings: _settings,
          onWebViewCreated: (controller) {
            _webViewController = controller;
            debugPrint('🌐 WebView creado');
          },
          onLoadStart: (controller, url) {
            debugPrint('⏳ Cargando: $url');
          },
          onLoadStop: (controller, url) async {
            debugPrint('✅ Página cargada: $url');
            await _checkSessionAlive();
          },
          onReceivedError: (controller, request, error) {
            debugPrint('❌ Error: ${error.description}');
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final url = navigationAction.request.url?.toString() ?? '';
            if (!url.startsWith('https://www.zoomubik.com')) {
              debugPrint('🔗 URL externa bloqueada: $url');
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
        ),
      ),
    );
  }
}