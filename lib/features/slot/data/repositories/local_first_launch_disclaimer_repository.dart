import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/first_launch_disclaimer_repository.dart';
import 'local_user_data_coordinator.dart';

/// Records the acceptance on the device so the gate also works offline.
///
/// The file holds the accepted version rather than a bare marker: raising
/// [kDisclaimerVersion] has to bring the notice back, and a file that only says
/// "seen" cannot express that.
class LocalFirstLaunchDisclaimerRepository
    implements FirstLaunchDisclaimerRepository {
  LocalFirstLaunchDisclaimerRepository({
    LocalUserDataCoordinator? coordinator,
    Future<Directory> Function()? directoryProvider,
  }) : _coordinator = coordinator ?? LocalUserDataCoordinator.shared,
       _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory;

  final LocalUserDataCoordinator _coordinator;
  final Future<Directory> Function() _directoryProvider;

  Future<File> _disclaimerFile(String userId) async {
    final directory = await _directoryProvider();
    return File('${directory.path}/first_launch_disclaimer_$userId.txt');
  }

  @override
  Future<bool> hasSeenDisclaimer(String userId) {
    return _coordinator.run(userId, () async {
      final file = await _disclaimerFile(userId);
      if (!await file.exists()) return false;
      return versionOf(await file.readAsString()) >= kDisclaimerVersion;
    }, whenBlocked: () => false);
  }

  @override
  Future<void> markDisclaimerSeen(String userId) {
    return _coordinator.run(userId, () async {
      final file = await _disclaimerFile(userId);
      await file.writeAsString('$kDisclaimerVersion');
    }, whenBlocked: () {});
  }

  /// Builds before versioning wrote the literal `seen`, which counts as
  /// version 1 — those players did accept the text that shipped as version 1.
  static int versionOf(String contents) {
    final trimmed = contents.trim();
    if (trimmed == 'seen') return 1;
    return int.tryParse(trimmed) ?? 0;
  }
}
