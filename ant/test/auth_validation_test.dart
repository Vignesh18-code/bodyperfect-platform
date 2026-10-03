import 'package:flutter_test/flutter_test.dart';
import 'package:ant/core/validation/auth_validation.dart';

void main() {
  test('Email rejects missing, repeated @ and whitespace', () {
    for (final value in [
      '',
      'a@@b.com',
      'a b@example.com',
      'a@example',
      '@example.com',
    ]) {
      expect(AuthValidation.email(value), isNotNull, reason: value);
    }
    expect(AuthValidation.email(' patient+test@example.test '), isNull);
  });
  test('Name enforces API boundaries', () {
    expect(AuthValidation.name(' '), isNotNull);
    expect(AuthValidation.name('A'), isNotNull);
    expect(AuthValidation.name('Ab'), isNull);
    expect(AuthValidation.name('A' * 100), isNull);
    expect(AuthValidation.name('A' * 101), isNotNull);
  });
  test('Phone requires exactly nine digits', () {
    for (final value in ['', '12345678', '1234567890', '12345678a']) {
      expect(AuthValidation.phone(value), isNotNull);
    }
    expect(AuthValidation.phone('501234567'), isNull);
  });
  test('New password matches API length, character set and complexity', () {
    for (final value in [
      '',
      'Ab1!abc',
      'abcdefgh',
      'ABCDEFGH',
      'Abcdefgh',
      'Abcdefg1',
      'Abcdef1! ',
      'Abcdef1!é',
      'Abcdef1!#',
      'Abcdef1!${'a' * 65}',
    ]) {
      expect(
        AuthValidation.newPassword(value),
        isNotNull,
        reason: 'Invalid password accepted',
      );
    }
    expect(AuthValidation.newPassword('Abcdef1!'), isNull);
    expect(AuthValidation.newPassword('Abcdef1!${'a' * 64}'), isNull);
  });
}
