import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract interface class AmbientMusicPreferenceStore {
  Future<bool?> readEnabled();

  Future<void> writeEnabled(bool enabled);
}

class LocalAmbientMusicPreferenceStore implements AmbientMusicPreferenceStore {
  LocalAmbientMusicPreferenceStore({File? preferenceFile})
    : _preferenceFile = preferenceFile == null
          ? null
          : Future.value(preferenceFile);

  static const _fileName = 'winner_spin_ambient_music.preference';

  Future<File>? _preferenceFile;

  Future<File> get _file => _preferenceFile ??= _resolveFile();

  @override
  Future<bool?> readEnabled() async {
    final file = await _file;
    final temporaryFile = File('${file.path}.tmp');
    if (await temporaryFile.exists()) {
      final temporaryValue = await _readValue(temporaryFile);
      if (temporaryValue != null) {
        if (await file.exists()) await file.delete();
        await temporaryFile.rename(file.path);
        return temporaryValue;
      }
    }
    if (!await file.exists()) return null;

    return _readValue(file);
  }

  Future<bool?> _readValue(File file) async {
    return switch ((await file.readAsString()).trim()) {
      'true' => true,
      'false' => false,
      _ => null,
    };
  }

  @override
  Future<void> writeEnabled(bool enabled) async {
    final file = await _file;
    final temporaryFile = File('${file.path}.tmp');
    await temporaryFile.writeAsString(enabled.toString(), flush: true);
    if (await file.exists()) await file.delete();
    await temporaryFile.rename(file.path);
  }

  Future<File> _resolveFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }
}
