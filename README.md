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

Las notificaciones push en segundo plano se reciben mediante FCM. En este proyecto ya se usa el servicio externo de Google Apps Script configurado para revisar `partner_orders` y enviar avisos de pedido nuevo, modificado, cancelado y recordatorios, sin depender de Cloud Functions.

## v1.2.0 - Pedidos modificados
- Muestra notas del cliente por producto.
- En una modificación resalta: NUEVO/PREPARAR, YA SERVIDO/NO REPETIR y ELIMINADO/NO PREPARAR.
- Muestra cuando el socio fue asignado para realizar el envío y el importe que le corresponde.
- La estadística del socio suma productos + envíos asignados.
