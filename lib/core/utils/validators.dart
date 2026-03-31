class Validators {
  static String? emailValidator(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!value.endsWith('@must.ac.ug')) return 'Must use a valid @must.ac.ug email address';
    final parts = value.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return 'Invalid email format';
    return null;
  }

  static String? priceValidator(String? value, {bool isFree = false}) {
    if (isFree) return null;
    if (value == null || value.isEmpty) return 'Price is required';
    final price = double.tryParse(value);
    if (price == null) return 'Must be a valid number';
    if (price < 0) return 'Price cannot be negative';
    return null;
  }

  static String? titleValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Title is required';
    if (value.trim().length < 3) return 'Must be at least 3 characters';
    if (value.trim().length > 60) return 'Must be 60 characters or less';
    return null;
  }
}
