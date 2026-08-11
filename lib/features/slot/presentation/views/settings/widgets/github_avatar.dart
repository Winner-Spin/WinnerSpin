import 'package:flutter/material.dart';

import 'github_mark.dart';

/// A bundled GitHub user's profile picture.
///
/// The avatar is decoration on a link that already reads as a name, so a
/// missing asset or an unsupported login falls back to the plain [GitHubMark].
/// This keeps the footer usable offline and avoids network requests from UI.
class GitHubAvatar extends StatelessWidget {
  const GitHubAvatar({super.key, required this.login, this.size = 16});

  /// GitHub username with a bundled avatar, e.g. `hakangunesdev`.
  final String login;
  final double size;

  static const _assetByLogin = <String, String>{
    'hakangunesdev': 'assets/avatars/hakangunesdev.jpg',
    'eneseken95': 'assets/avatars/eneseken95.jpg',
  };

  @override
  Widget build(BuildContext context) {
    final fallback = GitHubMark(size: size);
    final assetPath = _assetByLogin[login];

    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: assetPath == null
            ? fallback
            : Image.asset(
                assetPath,
                width: size,
                height: size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}
