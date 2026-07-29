import '../../../../auth/domain/repositories/auth_repository.dart';
import '../../../domain/repositories/first_launch_disclaimer_repository.dart';

enum DisclaimerGateStatus { checking, needsAcceptance, accepted }

class DisclaimerGateController {
  DisclaimerGateController({
    required AuthRepository authRepository,
    required FirstLaunchDisclaimerRepository localRepository,
    required DisclaimerAcceptanceRepository acceptanceRepository,
    required String appVersion,
  }) : _authRepository = authRepository,
       _localRepository = localRepository,
       _acceptanceRepository = acceptanceRepository,
       _appVersion = appVersion;

  final AuthRepository _authRepository;
  final FirstLaunchDisclaimerRepository _localRepository;
  final DisclaimerAcceptanceRepository _acceptanceRepository;
  final String _appVersion;

  DisclaimerGateStatus _status = DisclaimerGateStatus.checking;
  DisclaimerGateStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isRecording = false;

  Future<void> resolve() async {
    final userId = _authRepository.currentUserId;
    if (userId == null) {
      _status = DisclaimerGateStatus.needsAcceptance;
      return;
    }

    try {
      if (await _localRepository.hasSeenDisclaimer(userId)) {
        _status = DisclaimerGateStatus.accepted;
        return;
      }
    } catch (_) {}

    try {
      final accepted = await _acceptanceRepository.hasAccepted(
        userId: userId,
        version: kDisclaimerVersion,
      );
      if (!accepted) {
        _status = DisclaimerGateStatus.needsAcceptance;
        return;
      }
      await _markLocalQuietly(userId);
      _status = DisclaimerGateStatus.accepted;
    } catch (_) {
      _status = DisclaimerGateStatus.needsAcceptance;
    }
  }

  Future<bool> accept() async {
    if (_isRecording) return false;
    final userId = _authRepository.currentUserId;
    if (userId == null) return false;

    _isRecording = true;
    _errorMessage = null;
    try {
      await _acceptanceRepository.recordAcceptance(
        userId: userId,
        version: kDisclaimerVersion,
        appVersion: _appVersion,
      );
      await _markLocalQuietly(userId);
      _status = DisclaimerGateStatus.accepted;
      return true;
    } catch (_) {
      if (await _recoverCommittedAcceptance(userId)) return true;
      _errorMessage = 'Acceptance could not be saved. Please try again.';
      _status = DisclaimerGateStatus.needsAcceptance;
      return false;
    } finally {
      _isRecording = false;
    }
  }

  Future<void> _markLocalQuietly(String userId) async {
    try {
      await _localRepository.markDisclaimerSeen(userId);
    } catch (_) {}
  }

  Future<bool> _recoverCommittedAcceptance(String userId) async {
    try {
      final accepted = await _acceptanceRepository.hasAccepted(
        userId: userId,
        version: kDisclaimerVersion,
      );
      if (!accepted) return false;
      await _markLocalQuietly(userId);
      _status = DisclaimerGateStatus.accepted;
      return true;
    } catch (_) {
      return false;
    }
  }
}
