class BrowserSitePreference {
  static const String storageKey = 'henigma_cashier_default_site_id';
  static const String lockKey = 'henigma_cashier_site_locked';

  static String? getDefaultSiteId() {
    return null;
  }

  static void setDefaultSiteId(String siteId) {}

  static void clearDefaultSiteId() {}

  static bool isLocked() {
    return false;
  }

  static void setLocked(bool value) {}
}
