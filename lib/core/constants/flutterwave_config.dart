class FlutterwaveConfig {
  static const String publicKey = 'FLWPUBK_TEST-1e7f88af43ea90c5bdac8276a8f979cd-X';
  static const String secretKey = 'FLWSECK_TEST-567548fac5474af72669d8fb026e8da6-X';
  static const String encryptionKey = 'FLWSECK_TEST1946b24a0290';
  static const String currency = 'UGX';
  static const String country = 'UG';
  static const double platformFeePercent = 0.05; // 5% platform fee

  static double calculatePlatformFee(double amount) {
    return double.parse((amount * platformFeePercent).toStringAsFixed(0));
  }
}
