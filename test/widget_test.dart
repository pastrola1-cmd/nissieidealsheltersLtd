import 'package:flutter_test/flutter_test.dart';
import 'package:nissie_ideal_shelters/core/utils/validators.dart';

void main() {
  group('Validators tests', () {
    test('Email validator tests', () {
      expect(Validators.validateEmail(null), 'Email is required');
      expect(Validators.validateEmail(''), 'Email is required');
      expect(Validators.validateEmail('invalid-email'), 'Enter a valid email address');
      expect(Validators.validateEmail('test@gmail.com'), null);
    });

    test('Password validator tests', () {
      expect(Validators.validatePassword(null), 'Password is required');
      expect(Validators.validatePassword(''), 'Password is required');
      expect(Validators.validatePassword('12345'), 'Password must be at least 6 characters');
      expect(Validators.validatePassword('123456'), null);
    });

    test('Required validator tests', () {
      expect(Validators.validateRequired(null, 'Full Name'), 'Full Name is required');
      expect(Validators.validateRequired('', 'Full Name'), 'Full Name is required');
      expect(Validators.validateRequired('John Doe', 'Full Name'), null);
    });

    test('Price validator tests', () {
      expect(Validators.validatePrice(null), 'Price is required');
      expect(Validators.validatePrice(''), 'Price is required');
      expect(Validators.validatePrice('abc'), 'Enter a valid price');
      expect(Validators.validatePrice('-100'), 'Price must be greater than zero');
      expect(Validators.validatePrice('₦1,500,000'), null);
      expect(Validators.validatePrice('1500000'), null);
    });
  });
}
