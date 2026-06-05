class EmailService {
  static bool get isActive => false;
  static DateTime? get nextSendTime => null;

  static void startEmailService() {
    throw UnsupportedError(
      'Automatic email transmission has been removed. Use local export flows instead.',
    );
  }

  static void stopEmailService() {}

  static Future<bool> sendDataManually() async {
    throw UnsupportedError(
      'Manual email transmission has been removed. Use local export flows instead.',
    );
  }

  static Map<String, dynamic> getServiceInfo() {
    return {
      'is_active': false,
      'next_send_time': null,
      'send_interval_minutes': null,
    };
  }
}
