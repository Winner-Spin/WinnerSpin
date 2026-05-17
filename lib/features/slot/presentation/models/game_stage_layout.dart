class GameStageLayout {
  const GameStageLayout._();

  static const double statusBandTopRatio = 0.5185;
  static const double statusBandHeight = 31;
  static const double statusBandGap = 31;

  static const double bottomInfoInset = 12;
  static const double bottomInfoPanelHeight = 40;
  static const double utilityButtonHeight = 42;

  static double normalStatusBandBottom(double screenH) {
    return screenH * statusBandTopRatio + statusBandHeight;
  }

  static double utilityButtonTop(double screenH) {
    return screenH -
        bottomInfoInset -
        bottomInfoPanelHeight -
        utilityButtonHeight;
  }
}
