# Configuración de Notificaciones Push en iOS - Zoomubik

## Resumen del Problema

Las notificaciones no se mostraban porque:
1. El token FCM no se guardaba correctamente (sesión perdida al cerrar app)
2. Faltaba manejo de notificaciones en foreground
3. Falta configuración de APNs en Firebase
4. El payload de APNS no estaba optimizado para iOS

## Cambios Realizados

### 1. Flutter (lib/main.dart)
✅ Almacenamiento seguro del user_id con `FlutterSecureStorage`
✅ Sincronización automática del token cuando se recupera la sesión
✅ Listeners para notificaciones en foreground y cuando se toca la notificación
✅ Mejor manejo de errores y logging

### 2. WordPress (Plugin)
✅ Mejor logging del guardado de tokens
✅ Payload APNS mejorado con configuración correcta para iOS
✅ Mejor manejo de errores en envío de FCM

## Pasos Pendientes (CRÍTICO)

### Paso 1: Configurar APNs en Firebase Console

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto: `ios-app-42b04`
3. Ve a **Project Settings** → **Cloud Messaging**
4. En la sección **iOS app configuration**, busca **APNs Authentication Key**
5. Haz clic en **Upload** y sube tu APNs key (archivo .p8)
   - Si no tienes, crea uno en [Apple Developer](https://developer.apple.com/account/resources/certificates/list)
   - Ve a **Certificates, Identifiers & Profiles** → **Keys**
   - Crea una nueva key con permisos de **Apple Push Notifications service (APNs)**
   - Descarga el archivo .p8

### Paso 2: Verificar Certificados en Xcode

1. Abre `ios/Runner.xcworkspace` en Xcode
2. Selecciona **Runner** → **Signing & Capabilities**
3. Asegúrate de que:
   - **Team** está seleccionado correctamente
   - **Bundle Identifier** es correcto
   - **Signing Certificate** es válido
4. Haz clic en **+ Capability** y añade:
   - **Push Notifications**
   - **Background Modes** (Remote notifications)

### Paso 3: Verificar GoogleService-Info.plist

1. Descarga el archivo `GoogleService-Info.plist` desde Firebase Console
2. Reemplaza el archivo en `ios/Runner/GoogleService-Info.plist`
3. En Xcode, asegúrate de que está en el target **Runner**

### Paso 4: Verificar Podfile

Abre `ios/Podfile` y asegúrate de que tiene:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_NOTIFICATIONS=1',
      ]
    end
  end
end
```

### Paso 5: Limpiar y Reconstruir

```bash
cd ios
rm -rf Pods
rm Podfile.lock
cd ..
flutter clean
flutter pub get
cd ios
pod install --repo-update
cd ..
flutter run
```

## Pruebas

### Test 1: Verificar Token FCM

1. Abre la app en iOS
2. Revisa los logs en Xcode (Cmd+Shift+2)
3. Busca: `🔑 FCM Token: ey...`
4. Verifica que el token se guarde en WordPress:
   - Ve a WordPress Admin
   - Abre la consola del navegador (F12)
   - Ejecuta: `wp.ajax.post('zmoriginal_flutter_get_unread_count', {user_id: 123})`

### Test 2: Enviar Notificación de Prueba

1. En WordPress, ve a **Herramientas** → **Zoomubik Messages**
2. Busca el endpoint de prueba: `/wp-admin/admin-ajax.php?action=zm_test_push&token=TU_TOKEN`
3. O usa curl:

```bash
curl -X POST https://www.zoomubik.com/wp-admin/admin-ajax.php \
  -d "action=zm_test_push&token=TU_FCM_TOKEN"
```

### Test 3: Enviar Mensaje Real

1. Inicia sesión en la app
2. Envía un mensaje a otro usuario
3. Verifica que la notificación aparezca en el dispositivo del receptor

## Debugging

### Logs en Flutter

```bash
flutter logs
```

Busca líneas con:
- `🔑 FCM Token:`
- `✅ Token guardado`
- `📬 Notificación`

### Logs en WordPress

```bash
tail -f /var/log/php-errors.log
# o en wp-content/debug.log si está habilitado
```

Busca líneas con:
- `✅ FCM Token guardado`
- `📤 Enviando notificaciones`
- `✅ FCM enviado correctamente`

### Verificar Token en Base de Datos

```sql
SELECT user_id, meta_value FROM wp_usermeta 
WHERE meta_key = 'fcm_token' 
ORDER BY user_id DESC LIMIT 10;
```

## Checklist Final

- [ ] APNs key subida a Firebase
- [ ] Push Notifications capability en Xcode
- [ ] GoogleService-Info.plist actualizado
- [ ] Podfile configurado correctamente
- [ ] App reconstruida (`flutter clean && flutter run`)
- [ ] Token FCM visible en logs
- [ ] Token guardado en WordPress
- [ ] Notificación de prueba recibida
- [ ] Mensaje real genera notificación

## Notas Importantes

1. **Certificados**: Los certificados de APNs expiran. Renuévalos antes de que caduquen.
2. **Bundle ID**: Debe coincidir exactamente con el de Apple Developer
3. **Sesión**: La app ahora mantiene el user_id incluso después de cerrar
4. **Tokens**: Se guardan automáticamente cuando se renuevan
5. **Logs**: Revisa siempre los logs para debugging

## Contacto

Si las notificaciones aún no funcionan:
1. Revisa los logs en Xcode
2. Verifica que el token se guarde en WordPress
3. Prueba el endpoint de test push
4. Revisa que el project_id sea correcto: `ios-app-42b04`
