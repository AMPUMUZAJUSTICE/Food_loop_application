import 'package:flutter_test/flutter_test.dart';
import 'package:food_loop/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('emailValidator', () {
      test('should accept user@must.ac.ug', () {
        expect(Validators.emailValidator('user@must.ac.ug'), isNull);
        expect(Validators.emailValidator('student.123@must.ac.ug'), isNull);
      });

      test('should reject user@gmail.com', () {
        expect(Validators.emailValidator('user@gmail.com'), isNotNull);
      });

      test('should reject user@', () {
        expect(Validators.emailValidator('user@'), isNotNull);
      });

      test('should reject empty string', () {
        expect(Validators.emailValidator(''), isNotNull);
        expect(Validators.emailValidator(null), isNotNull);
      });
    });

    group('priceValidator', () {
      test('should accept "5000" and "0"', () {
        expect(Validators.priceValidator('5000'), isNull);
        expect(Validators.priceValidator('0'), isNull);
      });

      test('should reject "-100"', () {
        expect(Validators.priceValidator('-100'), isNotNull);
      });

      test('should reject "abc"', () {
        expect(Validators.priceValidator('abc'), isNotNull);
      });

      test('should reject empty for paid listings', () {
        expect(Validators.priceValidator('', isFree: false), isNotNull);
        expect(Validators.priceValidator(null, isFree: false), isNotNull);
      });

      test('should accept empty when isFree is true', () {
        expect(Validators.priceValidator('', isFree: true), isNull);
      });
    });

    group('titleValidator', () {
      test('should accept valid title', () {
        expect(Validators.titleValidator('Rice and Beans'), isNull);
      });

      test('should reject less than 3 chars', () {
        expect(Validators.titleValidator('Hi'), isNotNull);
      });

      test('should reject more than 60 chars', () {
        expect(Validators.titleValidator('A' * 61), isNotNull);
      });

      test('should reject empty or whitespace', () {
        expect(Validators.titleValidator(''), isNotNull);
        expect(Validators.titleValidator('   '), isNotNull);
        expect(Validators.titleValidator(null), isNotNull);
      });
    });
  });
}
