import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/first_launch_disclaimer_repository.dart';

/// Records the acceptance on the device so the gate also works offline.
///
/// The file holds the accepted version rather than a bare marker: raising
/// [kDisclaimerVersion] has to bring the notice back, and a file that only says
/// "seen" cannot express that.
class LocalFirstLaunchDisclaimerRepository
    implements FirstLaunchDisclaimerRepository {
  Future<File> _disclaimerFile(String userId) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/first_launch_disclaimer_$userId.txt');
  }

  @override
  Future<bool> hasSeenDisclaimer(String userId) async {
    final file = await _disclaimerFile(userId);
    if (!await file.exists()) return false;
    return versionOf(await file.readAsString()) >= kDisclaimerVersion;
  }

  @override
  Future<void> markDisclaimerSeen(String userId) async {
    final file = await _disclaimerFile(userId);
    await file.writeAsString('$kDisclaimerVersion');
  }

  /// Builds before versioning wrote the literal `seen`, which counts as
  /// version 1 — those players did accept the text that shipped as version 1.
  static int versionOf(String contents) {
    final trimmed = contents.trim();
    if (trimmed == 'seen') return 1;
    return int.tryParse(trimmed) ?? 0;
  }
}
