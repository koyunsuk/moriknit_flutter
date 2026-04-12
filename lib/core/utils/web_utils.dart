// Web-only implementation using dart:js_interop
import 'package:web/web.dart' as web;
void goToWebUrl(String url) => web.window.location.href = url;
