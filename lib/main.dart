import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    print('Error inicializando Firebase: $e');
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

  @override
  void initState() {
    super.initState();
    _initFirebaseMessaging();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          print('Mensaje desde web: ${message.message}');
          if (message.message.startsWith('user_id:')) {
            final userId = message.message.replaceFirst('user_id:', '');
            if (userId != '0' && userId.isNotEmpty) {
              _saveFcmToken(userId);
            }
          }
          // Guardar cookies cuando WordPress confirma login
          if (message.message.startsWith('cookies:')) {
            final cookies = message.message.replaceFirst('cookies:', '');
            _saveCookies(cookies);
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) async {
          // Guardar cookies actuales
          await _saveCurrentCookies();
          _injectUserId();
        },
      ))
      ..loadRequest(Uri.parse('https://www.zoomubik.com'));
  }

  Future<void> _saveCurrentCookies() async {
    try {
      final cookies = await _controller.runJavaScriptReturningResult(
        'document.cookie'
      );
      final cookieString = cookies.toString().replaceAll('"', '');
      if (cookieString.isNotEmpty && cookieString != 'null') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('wp_cookies', cookieString);
        print('Cookies guardadas: $cookieString');
      }
    } catch (e) {
      print('Error guardando cookies: $e');
    }
  }

  Future<void> _saveCookies(String cookies) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wp_cookies', cookies);
    print('Cookies guardadas desde canal: $cookies');
  }

  Future<String?> _getSavedCookies() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('wp_cookies');
  }

  Future<void> _injectUserId() async {
    await Future.delayed(Duration(seconds: 2));
    try {
      final response = await http.post(
        Uri.parse('https://www.zoomubik.com/wp-admin/admin-ajax.php'),
        body: {'action': 'zm_get_user_id'},
      );
      print('Respuesta user_id: ${response.body}');
      final decoded = json.decode(response.body);
      final userId = decoded['data']['user_id'].toString();
      print('User ID obtenido: $userId');
      if (userId != '0' && userId.isNotEmpty) {
        await _saveFcmToken(userId);
      } else {
        // Intentar via JavaScript como fallback
        final result = await _controller.runJavaScriptReturningResult(
          'typeof zoomubik_user_id !== "undefined" ? zoomubik_user_id.toString() : "0"'
        );
        final jsUserId = result.toString().replaceAll('"', '');
        print('User ID desde JS: $jsUserId');
        if (jsUserId != '0' && jsUserId.isNotEmpty) {
          await _saveFcmToken(jsUserId);
        }
      }
    } catch (e) {
      print('Error obteniendo user_id: $e');
    }
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      String? token = await FirebaseMessaging.instance.getToken();
      print('FCM Token: $token');
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        print('FCM Token renovado: $newToken');
        try {
          final response = await http.post(
            Uri.parse('https://www.zoomubik.com/wp-admin/admin-ajax.php'),
            body: {'action': 'zm_get_user_id'},
          );
          final decoded = json.decode(response.body);
          final userId = decoded['data']['user_id'].toString();
          if (userId != '0') await _saveFcmToken(userId);
        } catch (e) {
          print('Error en onTokenRefresh: $e');
        }
      });
    } catch (e) {
      print('Error en Firebase Messaging: $e');
    }
  }

  Future<void> _saveFcmToken(String userId) async {
    try {
      // Guardar user_id para usarlo después
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wp_user_id', userId);

      String? token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      // Obtener cookies guardadas
      final savedCookies = await _getSavedCookies();

      final headers = <String, String>{};
      if (savedCookies != null && savedCookies.isNotEmpty) {
        headers['Cookie'] = savedCookies;
      }

      final response = await http.post(
        Uri.parse('https://www.zoomubik.com/wp-admin/admin-ajax.php'),
        headers: headers,
        body: {
          'action': 'zmoriginal_save_fcm_token',
          'user_id': userId,
          'token': token,
        },
      );
      print('Token guardado en WordPress: ${response.statusCode}');
      print('Respuesta: ${response.body}');
    } catch (e) {
      print('Error guardando token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
