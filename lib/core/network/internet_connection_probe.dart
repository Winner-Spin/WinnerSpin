import 'dart:async';
import 'dart:io';

const _authHost = 'identitytoolkit.googleapis.com';
const _authPort = 443;
const _connectionTimeout = Duration(seconds: 3);

Future<bool> hasInternetConnection() async {
  Socket? socket;

  try {
    socket = await Socket.connect(
      _authHost,
      _authPort,
      timeout: _connectionTimeout,
    );
    return true;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  } finally {
    socket?.destroy();
  }
}
