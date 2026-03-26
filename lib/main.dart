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
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Recuperar sesión
    _currentUserId = await _secureStorage.read(key: 'wp_user_id');
    final token = await _secureStorage.read(key: 'zm_session_token');
    final phpsessid = await _secureStorage.read(key: 'zoomubik_phpsessid');

    // Restaurar PHPSESSID en cookies antes de cargar WebView
    if (phpsessid != null) {
      await _cookieManager.setCookie(WebViewCookie(
        name: 'PHPSESSID',
        value: phpsessid,
        domain: 'www.zoomubik.com',
        path: '/',
      ));
      print('🔄 Sesión restaurada instantáneamente: $phpsessid');
    }

    _initWebView();
    await _initFirebaseMessaging();

    // Restaurar sesión en WordPress si tenemos token
    if (_currentUserId != null && token != null) {
      await _restoreSession(_currentUserId!, token);
    }

    setState(() => _isInitialized = true);
  }

  Future<void> _restoreSession(String userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('https://www.zoomubik.com/wp-admin/admin-ajax.php'),
        body: {'action': 'zm_restore_session', 'user_id': userId, 'token': token},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        print('✅ Sesión restaurada instantáneamente');
        _controller.reload();
      }
    } catch (e) {
      print('❌ Error restaurando sesión: $e');
    }
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          if (message.message.startsWith('user_id:')) {
            final userId = message.message.replaceFirst('user_id:', '');
            if (userId != '0' && userId.isNotEmpty) {
              await _handleUserLogin(userId);
            }
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) async {
          // Inyectar user_id solo si hay login nuevo
          try {
            final result = await _controller.runJavaScriptReturningResult(
              'typeof zoomubik_user_id !== "undefined" ? zoomubik_user_id.toString() : "0"',
            );
            final userId = result.toString().replaceAll('"', '');
            if (userId != '0' && userId.isNotEmpty) {
              await _handleUserLogin(userId);
            }
          } catch (_) {}
        },
      ))
      ..loadRequest(Uri.parse('https://www.zoomubik.com'));
  }

  Future<void> _handleUserLogin(String userId) async {
    _currentUserId = userId;
    await _secureStorage.write(key: 'wp_user_id', value: userId);

    // Obtener token de sesión
    try {
      final response = await http.post(
        Uri.parse('https://www.zoomubik.com/wp-admin/admin-ajax.php'),
        body: {'action': 'zm_get_session_token', 'user_id': userId},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final token = data['data']['token'];
        await _secureStorage.write(key: 'zm_session_token', value: token);

        // Guardar PHPSESSID instantáneamente
        final cookies = await _controller.runJavaScriptReturningResult('document.cookie');
        final match = RegExp(r'PHPSESSID=([^;]+)').firstMatch(cookies.toString());
        if (match != null) {
          await _secureStorage.write(key: 'zoomubik_phpsessid', value: match.group(1));
        }
      }
    } catch (e) {
      print('⚠️ Error login: $e');
    }

    await _saveFcmToken(userId);
  }

  Future<void> _initFirebaseMessaging() async {
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    print('🔑 FCM Token: $token');

    FirebaseMessaging.onMessage.listen((msg) => print('📬 ${msg.notification?.title}'));
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _controller.runJavaScript('window.location.hash = "#mensajes-privados";');
    });
  }

  Future<void> _saveFcmToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(body: SafeArea(child: WebViewWidget(controller: _controller)));
  }
}
