# ANTOJERIA GONZALEZ SOCIOS v1.1

App Flutter para los 4 socios conectada al Firebase real del proyecto ANTOJERIA GONZALEZ.

## Flujo
- Inicio de sesión por socio.
- Lee su perfil desde `partners/{uid}`.
- Lee exclusivamente sus documentos en `partner_orders` usando `partnerNumber`.
- Estados: NUEVO -> RECIBIDO/CONFIRMADO -> PREPARANDO -> LISTO -> ENTREGADO.
- LISTO no desaparece hasta confirmar ENTREGADO.
- Temporizador visible y alertas de demora mientras la app está abierta.
- Registro de token FCM en `partner_devices/{uid}`.
- Historial y resumen de producción/ventas.

## Firebase
Android package: `com.antojeria.gonzalez.socios`
Project ID: `antojeria-gonzalez`

Las notificaciones push cuando la app está cerrada requieren desplegar el backend de Cloud Functions/FCM. La sincronización de pedidos y estados funciona con Firestore.
