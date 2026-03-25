# Cambios Realizados para Notificaciones Push en iOS

## 📋 Resumen

Se han identificado y corregido los problemas que impedían que las notificaciones push funcionaran en iOS. Los cambios incluyen mejoras en la app Flutter y en el plugin de WordPress.

## 🔧 Cambios en Flutter (lib/main.dart)

### Problema Original
- El user_id se perdía al cerrar la app
- El token FCM no se guardaba sin sesión activa
- No había manejo de notificaciones en foreground
- Carrera de condiciones entre obtener token y user_id

### Soluciones Implementadas

1. **Almacenamiento Seguro del User ID**
   ```dart
   final _secureStorage = FlutterSecureStorage();
   _currentUserId = await _secureStorage.read(key: 'wp_user_id');
   ```
   - Usa `FlutterSecureStorage` en lugar de `SharedPreferences`
   - El user_id persiste incluso después de cerrar la app

2. **Sincronización Automática del Token**
   ```dart
   Future<void> _handleUserLogin(String userId) async {
     _currentUserId = userId;
     await _secureStorage.write(key: 'wp_user_id', value: userId);
     await _saveFcmToken(userId);
   }
   ```
   - Cuando se detecta un nuevo user_id, se guarda automáticamente
   - Se envía el token FCM inmediatamente

3. **Listeners para Notificaciones**
   ```dart
   // Notificaciones en foreground
   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
     _showNotificationDialog(message);
   });

   // Cuando el usuario toca la notificación
   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
     _handleNotificationTap(message);
   });
   ```
   - Ahora muestra notificaciones incluso cuando la app está abierta
   - Maneja el tap en la notificación

4. **Mejor Manejo de Errores**
   - Logging detallado con emojis para fácil identificación
   - Timeout en las peticiones HTTP
   - Backup local del token en SharedPreferences

## 🔌 Cambios en WordPress (Plugin)

### Mejoras en `save_fcm_token()`
```php
public function save_fcm_token() {
    $user_id = intval($_POST['user_id']);
    $token = sanitize_text_field($_POST['token']);
    
    if (!$user_id || !$token) {
        error_log('❌ save_fcm_token: user_id o token vacío');
        wp_send_json_error('Datos incompletos');
        return;
    }
    
    update_user_meta($user_id, 'fcm_token', $token);
    error_log('✅ FCM Token guardado para usuario ' . $user_id);
    wp_send_json_success(array('message' => 'Token guardado correctamente'));
}
```
- Validación más robusta
- Logging detallado para debugging
- Respuesta JSON clara

### Mejoras en `send_push_notifications()`
```php
private function send_push_notifications($conversation_id, $sender_id, $message) {
    // Obtiene participantes con tokens
    // Logging detallado de cada envío
    // Manejo de errores mejorado
}
```
- Logging de cuántos participantes reciben notificación
- Información del token para debugging
- Mejor estructura del código

### Mejoras en `send_fcm_notification()`
```php
private function send_fcm_notification($token, $title, $body, $data = array()) {
    // Payload APNS mejorado para iOS
    $payload = array(
        'message' => array(
            'token' => $token,
            'notification' => array(...),
            'apns' => array(
                'payload' => array(
                    'aps' => array(
                        'alert' => array(
                            'title' => $title,
                            'body' => $body,
                        ),
                        'sound' => 'default',
                        'badge' => 1,
                        'mutable-content' => 1,
                        'category' => 'MESSAGE_CATEGORY',
                    ),
                ),
            ),
        ),
    );
}
```
- Payload APNS completo y correcto para iOS
- Incluye sonido, badge y categoría
- Mejor estructura para compatibilidad

## 📊 Flujo de Funcionamiento

```
1. App inicia
   ↓
2. Carga user_id guardado de almacenamiento seguro
   ↓
3. Inicializa Firebase Messaging
   ↓
4. Obtiene token FCM
   ↓
5. Carga WebView
   ↓
6. Detecta user_id del sitio web
   ↓
7. Guarda user_id en almacenamiento seguro
   ↓
8. Envía token FCM a WordPress
   ↓
9. WordPress guarda token en base de datos
   ↓
10. Cuando llega un mensaje:
    - WordPress obtiene token del usuario
    - Envía notificación a Firebase
    - Firebase envía a APNs
    - iOS muestra notificación
```

## 🧪 Cómo Probar

### 1. Verificar Token en Logs
```bash
flutter logs | grep "FCM Token"
```

### 2. Verificar Token en WordPress
```sql
SELECT user_id, meta_value FROM wp_usermeta 
WHERE meta_key = 'fcm_token' LIMIT 5;
```

### 3. Enviar Notificación de Prueba
```bash
curl -X POST https://www.zoomubik.com/wp-admin/admin-ajax.php \
  -d "action=zm_test_push&token=TU_TOKEN"
```

### 4. Enviar Mensaje Real
- Inicia sesión en la app
- Envía un mensaje a otro usuario
- Verifica que la notificación aparezca

## ⚠️ Requisitos Pendientes

1. **APNs Certificate en Firebase**
   - Subir el archivo .p8 desde Apple Developer
   - Sin esto, Firebase no puede enviar a iOS

2. **Push Notifications Capability en Xcode**
   - Añadir en Signing & Capabilities

3. **GoogleService-Info.plist Actualizado**
   - Descargar desde Firebase Console

4. **Reconstruir la App**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## 📝 Archivos Modificados

- `lib/main.dart` - Lógica de Firebase y almacenamiento
- `wordpress-plugin/zoomubik-messages-fixed-original-tables (1).php` - Endpoints y envío de notificaciones

## 📚 Documentación

Ver `NOTIFICACIONES_iOS_SETUP.md` para instrucciones detalladas de configuración.
