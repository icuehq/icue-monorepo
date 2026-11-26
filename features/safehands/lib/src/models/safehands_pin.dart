/// The pickup PIN of a student (`/CreateSafeHandsToken`, `/GetSafeHandsTokenByStudent`).
class SafeHandsPin {
  const SafeHandsPin({
    required this.pin,
    required this.heading,
    this.displayTime,
  });

  factory SafeHandsPin.fromJson(Map<String, dynamic> json) => SafeHandsPin(
    pin: (json['PIN'] as num).toInt(),
    heading: json['Heading'] as String? ?? '',
    displayTime: json['PINDisplayTime'] as String?,
  );

  final int pin;
  final String heading;
  final String? displayTime;
}
