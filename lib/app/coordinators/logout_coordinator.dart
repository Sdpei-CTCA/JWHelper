typedef LogoutAuthFn = Future<void> Function();
typedef ClearDataFn = void Function();

class LogoutCoordinator {
  static Future<void> execute({
    required LogoutAuthFn logoutAuth,
    required ClearDataFn clearData,
  }) async {
    await logoutAuth();
    clearData();
  }
}
