import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📬 Notificación en background: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    print('❌ Error inicializando Firebase: $e');
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

class _HomePageState extends State<HomePage> {
  late final WebViewController _controller;
  final _secureStorage = FlutterSecureStorage();
  final _cookieManager = WebViewCookieManager();

  String? _currentUserId;
  bool _isInitialized = false;
  bool _loginProcesado = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // ---------------------- INIT APP ----------------------
  Future<void> _initializeApp() async {
    _currentUserId = await _secureStorage.read(key: 'wp_user_id');
    final sessionToken = await _secureStorage.read(key: 'zm_session_token');
    final savedCookies = await _secureStorage.read(key: 'wp_cookies');

    print('📱 User ID: $_currentUserId');
    print('🔐 Token: ${sessionToken != null ? 'Sí' : 'No'}');

    // 1️⃣ Inicializar Firebase
    await _initFirebaseMessaging();

    // 2️⃣ Restaurar cookies si existen
    if (savedCookies != null) {
      await _restoreCookies(savedCookies);
      print('🔄 Cookies restauradas');
    }

    // 3️⃣ Inicializar WebView
    _initWebView();

    // 4️⃣ Restaurar sesión usando token si existe
    if (_currentUserId != null && sessionToken != null) {
      await Future.delayed(const Duration(seconds: 2));
      await _restoreSession(_currentUserId!, sessionToken);
    }

    setState(() => _isInitialized = true);
  }

  // ---------------------- RESTORE SESSION ----------------------
  Future<void> _restoreSession(String userId, String token) async {
    try {
      print('🔄 Restaurando sesión con token...');

      final response = await http.post(
        Uri.parse('https://www.zoomubik.com/wp-admin/admin-ajax.php'),
        body: {
          'action': 'zm_restore_session',
          'user_id': userId,
          'token': token,
        },
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        print('✅ Sesión restaurada desde token');
        _controller.loadRequest(Uri.parse('https://www.zoomubik.com'));
      } else {
        print('❌ Token inválido');
      }
    } catch (e) {
      print('❌ Error restaurando sesión: $e');
    }
  }

  // ---------------------- RESTAURAR COOKIES ----------------------
  Future<void> _restoreCookies(String cookieString) async {
    final cookies = cookieString.split(';');
    for (var c in cookies) {
      final parts = c.split('=');
      if (parts.length < 2) continue;

      final name = parts[0].trim();
      final value = parts.sublist(1).join('=').trim();

      if (name.isNotEmpty && value.isNotEmpty) {
        await _cookieManager.setCookie(WebViewCookie(
          name: name,
          value: value,
          domain: 'www.zoomubik.com',
          path: '/',
          isSecure: true,
        ));
      }
    }
  }

  // ---------------------- WEBVIEW ----------------------
  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          print('💬 Mensaje web: ${message.message}');
          if (message.message.startsWith('user_id:')) {
            final userId = message.message.replaceFirst('user_id:', '');
            if (userId != '0' && userId.isNotEmpty) {
              _handleUserLogin(userId);
            }
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            print('🌐 Página cargada: $url');
            await Future.delayed(const Duration(seconds: 1));
            _injectUserId();
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.zoomubik.com'));
  }

  // ---------------------- HANDLE LOGIN ----------------------
  Future<void> _handleUserLogin(String userId) async {
    if (_loginProcesado) return;
    _loginProcesado = true;

    _currentUserId = userId;
    await _secureStorage.write(key: 'wp_user_id', value: userId);
    print('✅ Usuario guardado: $userId');

    // 1️⃣ Obtener token sesión
    try {
      final response = await http.post(
        Uri.parse('https://www.zoomubik.com/wp-admin/admin-ajax.php'),
        body: {
          'action': 'zm_get_session_token',
          'user_id': userId,
        },
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        await _secureStorage.write(
            key: 'zm_session_token', value: data['data']['token']);
        print('🔐 Token de sesión guardado');
      }
    } catch (e) {
      print('⚠️ Error obteniendo token: $e');
    }

    // 2️⃣ Guardar cookies de WordPress
    try {
      final cookies =
          await _controller.runJavaScriptReturningResult('document.cookie');
      await _secureStorage.write(key: 'wp_cookies', value: cookies.toString());
      print('🍪 Cookies guardadas: $cookies');
    } catch (e) {
      print('⚠️ Error guardando cookies: $e');
    }

    // 3️⃣ Guardar token FCM
    await _saveFcmToken(userId);
  }

  // ---------------------- OBTENER USER ID DESDE WEB ----------------------
  Future<void> _injectUserId() async {
    try {
      final result = await _controller.runJavaScriptReturningResult(
        'typeof zoomubik_user_id !== "undefined" ? zoomubik_user_id.toString() : "0"',
      );
      final userId = result.toString().replaceAll('"', '');
      if (userId != '0' && userId.isNotEmpty) {
        await _handleUserLogin(userId);
      }
    } catch (e) {
      print('⚠️ Error user_id: $e');
    }
  }

  // ---------------------- FIREBASE ----------------------
  Future<void> _initFirebaseMessaging() async {
    try {
      await FirebaseMessaging.instance.requestPermission();

      FirebaseMessaging.instance.getToken().then((token) {
        print('🔑 FCM token: $token');
      });

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        if (_currentUserId != null) await _saveFcmToken(_currentUserId!);
      });

      FirebaseMessaging.onMessage.listen((message) {
        print('📬 Notificación foreground: ${message.notification?.title}');
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _controller.runJavaScript('window.location.hash = "#mensajes-privados";');
      });
    } catch (e) {
      print('❌ Firebase error: $e');
    }
  }

  // ---------------------- GUARDAR FCM ----------------------
  Future<void> _saveFcmToken(String userId) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await http.post(
        Uri.parse('https://www.zoomubik.com/wp-admin/admin-ajax.php'),
        body: {'action': 'zm_save_fcm', 'fcm': token},
      );
      print('✅ FCM guardado');
    } catch (e) {
      print('❌ Error FCM: $e');
    }
  }

  // ---------------------- BUILD ----------------------
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
