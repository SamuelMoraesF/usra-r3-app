class AppUpdateService {
  Stream<void> get updates => const Stream<void>.empty();

  Future<void> activate() async {}
}

AppUpdateService createAppUpdateService() => AppUpdateService();
