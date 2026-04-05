// Stub file — required for compilation only, never runs
Future<void> initializePlatform() async {}
Future<bool> requestPlatformPermission() async => false;
void unlockPlatformAudio() {}
Future<void> showPlatformNotification({
  required int id,
  required String title,
  required String body,
  required String type,
}) async {}
Future<void> cancelAllPlatform() async {}
Future<void> cancelPlatform(int id) async {}