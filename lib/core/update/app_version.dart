/// A dotted release version such as `1.0.0`, comparable part by part.
///
/// Plain string comparison is wrong for versions — `'1.10.0'` sorts before
/// `'1.9.0'` — so each segment is compared as a number instead.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.segments);

  /// Parses [raw], ignoring anything after a `+` (Flutter build numbers) or a
  /// `-` (pre-release suffixes). Returns null when no numeric segment is found.
  static AppVersion? tryParse(String? raw) {
    if (raw == null) return null;

    final trimmed = raw.trim().split('+').first.split('-').first.trim();
    if (trimmed.isEmpty) return null;

    final segments = <int>[];
    for (final part in trimmed.split('.')) {
      final value = int.tryParse(part.trim());
      if (value == null || value < 0) return null;
      segments.add(value);
    }
    if (segments.isEmpty) return null;
    return AppVersion(List.unmodifiable(segments));
  }

  final List<int> segments;

  /// Compares segment by segment, treating missing segments as zero so that
  /// `1.2` and `1.2.0` are equal.
  @override
  int compareTo(AppVersion other) {
    final length = segments.length > other.segments.length
        ? segments.length
        : other.segments.length;
    for (var i = 0; i < length; i++) {
      final mine = i < segments.length ? segments[i] : 0;
      final theirs = i < other.segments.length ? other.segments[i] : 0;
      if (mine != theirs) return mine.compareTo(theirs);
    }
    return 0;
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  bool operator <(AppVersion other) => compareTo(other) < 0;

  bool operator >=(AppVersion other) => compareTo(other) >= 0;

  bool operator <=(AppVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hashAll(_trimmed());

  List<int> _trimmed() {
    final trimmed = List<int>.of(segments);
    while (trimmed.length > 1 && trimmed.last == 0) {
      trimmed.removeLast();
    }
    return trimmed;
  }

  @override
  String toString() => segments.join('.');
}
