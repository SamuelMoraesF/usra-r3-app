class AppUpdateService {
  Stream<void> get updates => const Stream<void>.empty();

  Future<void> activate() async {}

  Future<void> checkForUpdate() async {}

  Future<void> clearCache() async {}
}

AppUpdateService createAppUpdateService() => AppUpdateService();
