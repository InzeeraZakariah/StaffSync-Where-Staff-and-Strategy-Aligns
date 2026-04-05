import 'dart:html' as html;

bool _audioUnlocked = false;

Future<void> initializePlatform() async {
  // Nothing to initialize for web
}

Future<bool> requestPlatformPermission() async {
  try {
    final permission = await html.Notification.requestPermission();
    return permission == 'granted';
  } catch (_) {
    return false;
  }
}

void unlockPlatformAudio() {
  if (_audioUnlocked) return;
  _audioUnlocked = true;
  try {
    for (final soundId in ['sound_notification', 'sound_emergency']) {
      final el = html.document.getElementById(soundId) as html.AudioElement?;
      if (el != null) {
        el.volume = 0;
        el.play().then((_) {
          el.pause();
          el.currentTime = 0;
          el.volume = 1.0;
        }).catchError((_) {});
      }
    }
  } catch (_) {}
}

void _playSound(String soundId, double volume, {int repeatTimes = 1}) {
  try {
    final el = html.document.getElementById(soundId) as html.AudioElement?;
    if (el == null) {
      print('Sound element not found: $soundId');
      return;
    }
    for (int i = 0; i < repeatTimes; i++) {
      final delayMs = i * 800;
      if (delayMs == 0) {
        el.volume = volume;
        el.currentTime = 0;
        el.play().catchError((e) {
          print('Audio play error: $e');
        });
      } else {
        Future.delayed(Duration(milliseconds: delayMs), () {
          try {
            el.volume = volume;
            el.currentTime = 0;
            el.play().catchError((_) {});
          } catch (_) {}
        });
      }
    }
  } catch (e) {
    print('_playSound error: $e');
  }
}

void _showBrowserNotification(String title, String body, int id) {
  try {
    if (html.Notification.supported &&
        html.Notification.permission == 'granted') {
      html.Notification(
        title,
        body: body,
        icon: '/icons/Icon-192.png',
        tag: id.toString(),
      );
    }
  } catch (_) {}
}

Future<void> showPlatformNotification({
  required int id,
  required String title,
  required String body,
  required String type,
}) async {
  switch (type) {
    case 'urgent':
      _playSound('sound_emergency', 1.0, repeatTimes: 3);
      break;
    case 'meeting':
      _playSound('sound_notification', 0.8);
      break;
    case 'chat':
      _playSound('sound_notification', 0.5);
      break;
    default:
      _playSound('sound_notification', 0.6);
  }
  _showBrowserNotification(title, body, id);
}

Future<void> cancelAllPlatform() async {}
Future<void> cancelPlatform(int id) async {}