class HomeNavigationCoordinator {
  static int? tabIndexFromWidgetHost(String? host) {
    if (host == null) return null;
    if (host == 'schedule') return 0;
    if (host == 'progress') return 3;
    return null;
  }
}
