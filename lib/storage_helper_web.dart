// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void saveToStorage(String key, String value) {
  html.window.localStorage[key] = value;
}

String? getFromStorage(String key) {
  return html.window.localStorage[key];
}

void removeFromStorage(String key) {
  html.window.localStorage.remove(key);
}
