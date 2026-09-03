# ANTOJERIA GONZALEZ - Guía de conexión en línea

Esta etapa conecta dos apps:

1. **ANTOJERIA GONZALEZ POS v0.6**: crea/cobra/cancela pedidos y los publica en la nube.
2. **ANTOJERIA GONZALEZ SOCIOS v1.0**: cada socio inicia sesión y solo ve los productos que le corresponden.

## 1. Crear el proyecto Firebase

1. Entra a Firebase Console y crea un proyecto, por ejemplo `antojeria-gonzalez`.
2. Activa **Cloud Firestore**.
3. En **Authentication > Sign-in method**, activa:
   - Email/Password
   - Anonymous
4. Agrega dos aplicaciones Android dentro del mismo proyecto Firebase:
   - POS: `com.antojeria.gonzalez.pos`
   - Socios: `com.antojeria.gonzalez.socios`

## 2. Poner la configuración en ambos proyectos

La forma recomendada es instalar FlutterFire CLI y ejecutar `flutterfire configure` dentro de cada proyecto.

Si prefieres hacerlo manualmente, abre `lib/firebase_options.dart` en cada app y sustituye:

- CAMBIAR_API_KEY
- CAMBIAR_APP_ID
- CAMBIAR_SENDER_ID
- CAMBIAR_PROJECT_ID

Los dos proyectos usan el mismo `projectId` y `messagingSenderId`, pero cada aplicación Android tiene su propio `appId`.

## 3. Crear las 4 cuentas de socios

En Firebase Console > Authentication > Users crea 4 usuarios con correo y contraseña.

Después abre Firestore y crea la colección `partner_users`.

El ID de cada documento debe ser el UID del usuario de Firebase Authentication.

Ejemplo del documento del Socio 1:

```json
{
  "partnerId": 1,
  "name": "Juan"
}
```

Socio 2 usa partnerId 2, Socio 3 usa 3 y Socio 4 usa 4.

**Importante:** los IDs 1,2,3,4 deben corresponder a los mismos cuatro socios de la app POS.

## 4. Publicar las reglas de Firestore

Desde la carpeta `firebase` ejecuta:

```bash
firebase login
firebase use --add
firebase deploy --only firestore:rules
```

Las reglas incluidas son adecuadas para esta primera fase de pruebas. Antes de distribuir la app fuera del negocio se recomienda endurecer el rol del POS con Custom Claims/App Check.

## 5. Activar notificaciones push

Instala Firebase CLI y despliega la función:

```bash
cd firebase/functions
npm install
cd ..
firebase deploy --only functions
```

La función `notifyPartnerTask` manda notificación cuando:

- llega un pedido nuevo;
- el pedido cambia de productos/cantidades;
- se cancela el pedido o la parte de un socio.

Los cambios de **Recibido / Preparando / Listo** no generan notificación al mismo socio; se sincronizan directamente con el POS. Los tokens de notificación se guardan en `partner_devices`.

## 6. Flujo de prueba

1. Abre el POS conectado a internet.
2. Abre la app Socios en cada teléfono e inicia sesión.
3. En el POS crea un pedido con productos de dos socios.
4. Cada socio debe recibir únicamente su parte.
5. En Socios pulsa RECIBIDO, PREPARANDO y LISTO.
6. El POS debe actualizar el estado general:
   - si alguien prepara: PREPARANDO;
   - si todos terminaron: LISTO.
7. Cobra el pedido en POS. En Mis ventas del socio aparecerá el importe de su parte.
8. Cancela un pedido de prueba y verifica la notificación de cancelación.

## 7. Funcionamiento sin internet

El POS conserva SQLite y sigue vendiendo localmente aunque Firebase no esté disponible. Firestore en Android mantiene caché local, pero para notificaciones y sincronización entre teléfonos se necesita conexión a internet.

En una versión posterior se puede agregar una cola explícita en el POS para reintentar automáticamente pedidos que no se hayan podido publicar en Firebase.
