class SlotReelController {
  Object? _owner;
  void Function(int spinRevision)? _quickStop;

  void quickStop(int spinRevision) => _quickStop?.call(spinRevision);

  void attach(Object owner, void Function(int spinRevision) quickStop) {
    _owner = owner;
    _quickStop = quickStop;
  }

  void detach(Object owner) {
    if (_owner == owner) {
      _owner = null;
      _quickStop = null;
    }
  }
}
