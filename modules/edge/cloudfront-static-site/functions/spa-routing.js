// Enrutado de la aplicación de una sola página (CloudFront Functions, cloudfront-js-2.0, viewer-request del
// comportamiento por defecto): las rutas sin extensión (/, /tenants/42) se sirven con /index.html; los ficheros
// (/assets/app.js) pasan tal cual. No afecta a los comportamientos de API ni a las respuestas del WAF.
function handler(event) {
  var request = event.request;
  var uri = request.uri;
  var last = uri.substring(uri.lastIndexOf('/') + 1);
  if (last.indexOf('.') === -1) {
    request.uri = '/index.html';
  }
  return request;
}
