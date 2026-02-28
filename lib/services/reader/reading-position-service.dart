class ReadingPositionService {
  double toPercent({required int offset, required int totalLength}) {
    if (totalLength <= 0) {
      return 0;
    }
    final clamped = offset.clamp(0, totalLength).toDouble();
    return clamped / totalLength;
  }

  int clampOffset({required int offset, required int totalLength}) {
    return offset.clamp(0, totalLength).toInt();
  }
}
