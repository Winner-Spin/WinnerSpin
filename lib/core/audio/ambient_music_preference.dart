import 'package:flutter/foundation.dart';

import 'ambient_music_preference_store.dart';

class AmbientMusicPreference {
  AmbientMusicPreference._();

  static bool _enabled = true;
  static AmbientMusicPreferenceStore? _store;
  static Future<void> _persistence = Future.value();

  static bool get enabled => _enabled;

  static Future<void> initialize({AmbientMusicPreferenceStore? store}) async {
    final preferenceStore = store ?? LocalAmbientMusicPreferenceStore();
    _store = preferenceStore;
    _enabled = true;
    try {
      _enabled = await preferenceStore.readEnabled() ?? true;
    } catch (error, stackTrace) {
      debugPrint(
        'Ambient music preference could not be loaded: $error\n$stackTrace',
      );
    }
  }

  static Future<void> setEnabled(bool enabled) {
    _enabled = enabled;
    final store = _store;
    if (store == null) return Future.value();

    final persistence = _persistence.then(
      (_) => _persistEnabled(store, enabled),
    );
    _persistence = persistence;
    return persistence;
  }

  static Future<void> _persistEnabled(
    AmbientMusicPreferenceStore store,
    bool enabled,
  ) async {
    try {
      await store.writeEnabled(enabled);
    } catch (error, stackTrace) {
      debugPrint(
        'Ambient music preference could not be saved: $error\n$stackTrace',
      );
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _enabled = true;
    _store = null;
    _persistence = Future.value();
  }
}
