import 'dart:js_interop';

@JS('window.isSecureContext')
external bool get locationContextIsSecure;
