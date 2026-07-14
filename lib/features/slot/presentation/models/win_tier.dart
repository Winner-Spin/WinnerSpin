enum WinTier {
  bigWin(
    threshold: 10,
    assetPath: 'lib/images/slot_main_screen/WIN_ARTICLES/BIGWIN.png',
  ),
  megaWin(
    threshold: 25,
    assetPath: 'lib/images/slot_main_screen/WIN_ARTICLES/MEGAWIN.png',
  ),
  superWin(
    threshold: 50,
    assetPath: 'lib/images/slot_main_screen/WIN_ARTICLES/SUPERWIN.png',
  ),
  epicWin(
    threshold: 100,
    assetPath: 'lib/images/slot_main_screen/WIN_ARTICLES/EPICWIN.png',
  ),
  sensationalWin(
    threshold: 250,
    assetPath: 'lib/images/slot_main_screen/WIN_ARTICLES/SENSATIONALWIN.png',
  ),
  maxWin(
    threshold: 500,
    assetPath: 'lib/images/slot_main_screen/WIN_ARTICLES/MAXWIN.png',
  );

  const WinTier({required this.threshold, required this.assetPath});

  final double threshold;

  final String assetPath;

  static WinTier? forMultiplier(double multiplier) {
    if (multiplier >= maxWin.threshold) return maxWin;
    if (multiplier >= sensationalWin.threshold) return sensationalWin;
    if (multiplier >= epicWin.threshold) return epicWin;
    if (multiplier >= superWin.threshold) return superWin;
    if (multiplier >= megaWin.threshold) return megaWin;
    if (multiplier >= bigWin.threshold) return bigWin;
    return null;
  }
}
