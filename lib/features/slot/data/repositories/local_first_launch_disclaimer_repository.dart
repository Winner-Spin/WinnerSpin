import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/first_launch_disclaimer_repository.dart';

class LocalFirstLaunchDisclaimerRepository
    implements FirstLaunchDisclaimerRepository {
  Future<File> _disclaimerFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/first_launch_disclaimer_seen.txt');
  }

  @override
  Future<bool> hasSeenDisclaimer() async {
    final file = await _disclaimerFile();
    return file.exists();
  }

  @override
  Future<void> markDisclaimerSeen() async {
    final file = await _disclaimerFile();
    await file.writeAsString('seen');
  }
}
