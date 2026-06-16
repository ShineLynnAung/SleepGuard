class DetectionEvent {
  final DateTime timestamp;
  final int totalScore;
  final bool triggeredLock;

  const DetectionEvent({
    required this.timestamp,
    required this.totalScore,
    required this.triggeredLock,
  });
}
