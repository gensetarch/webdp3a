// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// === localStorage (persists across sessions — for admin login) ===
void saveToStorage(String key, String value) {
  html.window.localStorage[key] = value;
}

String? getFromStorage(String key) {
  return html.window.localStorage[key];
}

void removeFromStorage(String key) {
  html.window.localStorage.remove(key);
}

// === sessionStorage (cleared when tab closes — for public room/item views) ===
void saveToSession(String key, String value) {
  html.window.sessionStorage[key] = value;
}

String? getFromSession(String key) {
  return html.window.sessionStorage[key];
}

void removeFromSession(String key) {
  html.window.sessionStorage.remove(key);
}

bool isPageReload() {
  try {
    final nav = html.window.performance.navigation;
    if (nav.type == html.PerformanceNavigation.TYPE_RELOAD) {
      return true;
    }
  } catch (_) {}
  try {
    final entries = html.window.performance.getEntriesByType('navigation');
    if (entries.isNotEmpty) {
      final entry = entries.first;
      final jsType = (entry as dynamic).type;
      if (jsType == 'reload') {
        return true;
      }
    }
  } catch (_) {}
  return false;
}

