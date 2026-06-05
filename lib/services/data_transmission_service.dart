class DataTransmissionService {
  static bool get isTransmitting => false;

  static Future<void> startTransmission() {
    throw UnsupportedError(
      'Remote data transmission has been removed. Use local export flows instead.',
    );
  }

  static Future<void> stopTransmission() async {}
}
