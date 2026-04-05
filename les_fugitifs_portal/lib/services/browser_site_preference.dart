import 'dart:html' as html;

class BrowserSitePreference {
  static const String storageKey = 'henigma_cashier_default_site_id';
  static const String lockKey = 'henigma_cashier_site_locked';

  static String? getDefaultSiteId() {
    try {
      return html.window.localStorage[storageKey];
    } catch (_) {
      return null;
    }
  }

  static void setDefaultSiteId(String siteId) {
    try {
      html.window.localStorage[storageKey] = siteId;
    } catch (_) {}
  }

  static void clearDefaultSiteId() {
    try {
      html.window.localStorage.remove(storageKey);
    } catch (_) {}
  }

  static bool isLocked() {
    try {
      return html.window.localStorage[lockKey] == 'true';
    } catch (_) {
      return false;
    }
  }

  static void setLocked(bool value) {
    try {
      html.window.localStorage[lockKey] = value.toString();
    } catch (_) {}
  }
}