import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/pending_spin_recovery.dart';
import '../../domain/repositories/spin_recovery_repository.dart';

class LocalSpinRecoveryRepository implements SpinRecoveryRepository {
  Future<void> _operations = Future<void>.value();

  Future<File> _recoveryFile(String userId) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/pending_spin_recovery_$userId.json');
  }

  @override
  Future<PendingSpinRecovery?> load(String userId) {
    return _synchronized(() => _load(userId));
  }

  Future<PendingSpinRecovery?> _load(String userId) async {
    final file = await _recoveryFile(userId);
    final temporaryFile = File('${file.path}.tmp');
    if (await temporaryFile.exists()) {
      try {
        final recovery = await _read(temporaryFile);
        if (await file.exists()) await file.delete();
        await temporaryFile.rename(file.path);
        return recovery;
      } catch (_) {
        if (!await file.exists()) rethrow;
      }
    }
    if (!await file.exists()) return null;
    return _read(file);
  }

  @override
  Future<void> save(String userId, PendingSpinRecovery recovery) {
    return _synchronized(() => _save(userId, recovery));
  }

  Future<void> _save(String userId, PendingSpinRecovery recovery) async {
    final file = await _recoveryFile(userId);
    final temporaryFile = File('${file.path}.tmp');
    await temporaryFile.writeAsString(
      jsonEncode(recovery.toJson()),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporaryFile.rename(file.path);
  }

  @override
  Future<void> clear(String userId, String spinId) {
    return _synchronized(() => _clear(userId, spinId));
  }

  Future<void> _clear(String userId, String spinId) async {
    final recovery = await _load(userId);
    if (recovery == null || recovery.spinId != spinId) return;

    final file = await _recoveryFile(userId);
    final temporaryFile = File('${file.path}.tmp');
    if (await file.exists()) await file.delete();
    if (await temporaryFile.exists()) await temporaryFile.delete();
  }

  Future<PendingSpinRecovery> _read(File file) async {
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return PendingSpinRecovery.fromJson(json);
  }

  Future<T> _synchronized<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}
