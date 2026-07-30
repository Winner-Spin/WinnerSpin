import 'package:flutter/material.dart';

import 'github_mark.dart';

/// A GitHub user's profile picture, fetched from `github.com/<login>.png`.
///
/// The avatar is decoration on a link that already reads as a name, so it is
/// never allowed to hold the row up: while it loads, and if it fails to load
/// at all, the chip falls back to the plain [GitHubMark]. That keeps the
/// footer identical in size and usable offline.
class GitHubAvatar extends StatelessWidget {
  const GitHubAvatar({super.key, required this.login, this.size = 16});

  /// GitHub username, e.g. `hakangunesdev`.
  final String login;
  final double size;

  @override
  Widget build(BuildContext context) {
    // GitHub serves avatars at whatever `size` is asked for, so request the
    // pixels actually needed instead of downloading a full-resolution image
    // to shrink it to 16pt.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    final fallback = GitHubMark(size: size);

    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: Image.network(
          'https://github.com/$login.png?size=$pixels',
          width: size,
          height: size,
          cacheWidth: pixels,
          cacheHeight: pixels,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          // No spinner: a 16pt progress indicator is noise. The mark stands in
          // until the picture arrives.
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}
