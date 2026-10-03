/// Public clinic contact. May be overridden for another deployment.
class ClinicContactConfig {
  static const phone = String.fromEnvironment(
    'CLINIC_PHONE',
    defaultValue: '+919384609073',
  );
}
