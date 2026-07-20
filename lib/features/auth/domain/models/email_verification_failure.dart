enum EmailVerificationFailureCode { tooManyRequests, unavailable, unknown }

class EmailVerificationException implements Exception {
  const EmailVerificationException(this.code, {this.rawMessage});

  final EmailVerificationFailureCode code;
  final String? rawMessage;

  @override
  String toString() => 'EmailVerificationException($code, $rawMessage)';
}
