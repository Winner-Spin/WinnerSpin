import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/pending_spin_recovery.dart';
import '../../domain/repositories/spin_recovery_repository.dart';
import 'local_user_data_coordinator.dart';

class LocalSpinRecoveryRepository implements SpinRecoveryRepository {
  LocalSpinRecoveryRepository({
    LocalUserDataCoordinator? coordinator,
    Future<Directory> Function()? directoryProvider,
  }) : _coordinator = coordinator ?? LocalUserDataCoordinator.shared,
       _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory;

  final LocalUserDataCoordinator _coordinator;
  final Future<Directory> Function() _directoryProvider;

  Future<File> _recoveryFile(String userId) async {
    final directory = await _directoryProvider();
    return File('${directory.path}/pending_spin_recovery_$userId.json');
  }

  @override
  Future<PendingSpinRecovery?> load(String userId) {
    return _coordinator.run(
      userId,
      () => _load(userId),
      whenBlocked: () => null,
    );
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
    return _coordinator.run(
      userId,
      () => _save(userId, recovery),
      whenBlocked: () {},
    );
  }

  Future<void> _save(String userId, PendingSpinRecovery recovery) async {
    final file = await _recoveryFile(userId);
    final temporaryFile = File('${file.path}.tmp');
    // Keep the atomic temp-file rename, but do not force a synchronous fsync
    // on the gameplay path. An app-process interruption still leaves the OS
    // buffered write available, while storage stalls cannot hold the reels.
    await temporaryFile.writeAsString(jsonEncode(recovery.toJson()));
    if (await file.exists()) await file.delete();
    await temporaryFile.rename(file.path);
  }

  @override
  Future<void> clear(String userId, String spinId) {
    return _coordinator.run(
      userId,
      () => _clear(userId, spinId),
      whenBlocked: () {},
    );
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
}
