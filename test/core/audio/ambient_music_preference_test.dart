import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/audio/ambient_music_preference.dart';
import 'package:winner_spin/core/audio/ambient_music_preference_store.dart';

void main() {
  setUp(AmbientMusicPreference.resetForTesting);
  tearDown(AmbientMusicPreference.resetForTesting);

  test('defaults to enabled when no preference has been stored', () async {
    final store = _MemoryAmbientMusicPreferenceStore();

    await AmbientMusicPreference.initialize(store: store);

    expect(AmbientMusicPreference.enabled, isTrue);
    expect(store.readCalls, 1);
  });

  test('loads a disabled preference before music initialization', () async {
    final store = _MemoryAmbientMusicPreferenceStore(storedValue: false);

    await AmbientMusicPreference.initialize(store: store);

    expect(AmbientMusicPreference.enabled, isFalse);
  });

  test('updates memory immediately and persists the selected value', () async {
    final store = _MemoryAmbientMusicPreferenceStore(storedValue: true)
      ..writeGate = Completer<void>();
    await AmbientMusicPreference.initialize(store: store);

    final persistence = AmbientMusicPreference.setEnabled(false);

    expect(AmbientMusicPreference.enabled, isFalse);
    expect(store.writeCalls, 1);
    store.writeGate!.complete();
    await persistence;
    expect(store.storedValue, isFalse);
  });

  test('restores the last selection after a simulated restart', () async {
    final store = _MemoryAmbientMusicPreferenceStore();
    await AmbientMusicPreference.initialize(store: store);
    await AmbientMusicPreference.setEnabled(false);

    AmbientMusicPreference.resetForTesting();
    await AmbientMusicPreference.initialize(store: store);

    expect(AmbientMusicPreference.enabled, isFalse);
  });

  test('serializes rapid changes so the latest selection is stored', () async {
    final store = _MemoryAmbientMusicPreferenceStore(storedValue: true)
      ..writeGate = Completer<void>();
    await AmbientMusicPreference.initialize(store: store);

    final disable = AmbientMusicPreference.setEnabled(false);
    final enable = AmbientMusicPreference.setEnabled(true);

    expect(AmbientMusicPreference.enabled, isTrue);
    expect(store.writeCalls, 1);
    store.writeGate!.complete();
    await Future.wait([disable, enable]);
    expect(store.writeCalls, 2);
    expect(store.storedValue, isTrue);
  });

  test('stores the preference in the local application file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'winner_spin_music_preference_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}music.pref');
    final store = LocalAmbientMusicPreferenceStore(preferenceFile: file);

    await store.writeEnabled(false);

    final restoredStore = LocalAmbientMusicPreferenceStore(
      preferenceFile: file,
    );
    expect(await restoredStore.readEnabled(), isFalse);
  });

  test('recovers a completed temporary preference write', () async {
    final directory = await Directory.systemTemp.createTemp(
      'winner_spin_music_preference_recovery_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}music.pref');
    await file.writeAsString('true', flush: true);
    await File('${file.path}.tmp').writeAsString('false', flush: true);

    final store = LocalAmbientMusicPreferenceStore(preferenceFile: file);

    expect(await store.readEnabled(), isFalse);
    expect(await File('${file.path}.tmp').exists(), isFalse);
  });
}

class _MemoryAmbientMusicPreferenceStore
    implements AmbientMusicPreferenceStore {
  _MemoryAmbientMusicPreferenceStore({this.storedValue});

  bool? storedValue;
  int readCalls = 0;
  int writeCalls = 0;
  Completer<void>? writeGate;

  @override
  Future<bool?> readEnabled() async {
    readCalls++;
    return storedValue;
  }

  @override
  Future<void> writeEnabled(bool enabled) async {
    writeCalls++;
    await writeGate?.future;
    storedValue = enabled;
  }
}
