import '../constants/app_copy.dart';

class Validators {
  static String? validateMobile(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mobile number is required';
    }
    if (value.length != 10) {
      return 'Mobile number must be 10 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Mobile number must contain only digits';
    }
    return null;
  }
  
  static String? validatePIN(String? value) {
    if (value == null || value.isEmpty) {
      return 'PIN is required';
    }
    if (value.length != 4) {
      return 'PIN must be 4 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'PIN must contain only digits';
    }
    return null;
  }
  
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
  
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }
  
  static String normalizeIndianVehicleRegistration(String? value) {
    if (value == null || value.isEmpty) return '';
    return value.replaceAll(RegExp(r'\s+'), '').trim().toUpperCase();
  }

  static String? validateVehicleNumber(String? value) {
    final normalized = normalizeIndianVehicleRegistration(value);
    if (normalized.isEmpty) {
      return 'Vehicle number is required';
    }
    if (normalized.length != 10) {
      return 'Vehicle number must be exactly 10 characters (e.g. MH12AB3434)';
    }
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z]{2}[0-9]{4}$').hasMatch(normalized)) {
      return 'Use format: state code, district (2 digits), series (2 letters), number (4 digits)';
    }
    return null;
  }

  static const double maxListingPricePerVehicle = 1e9;

  static String? validateOptionalListingPriceInr(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = num.tryParse(t.replaceAll(',', ''));
    if (n == null) return 'Enter a valid price';
    if (n <= 0) return 'Price must be greater than 0';
    if (n > maxListingPricePerVehicle) return 'Price is too large';
    return null;
  }

  static num? parseOptionalListingPriceInr(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return null;
    return num.tryParse(t.replaceAll(',', ''));
  }

  /// Container: 4 letters + 7 digits (e.g. ABCD1234567).
  static final RegExp _containerNumberRegex = RegExp(r'^[A-Z]{4}[0-9]{7}$');

  static String normalizeContainerNumber(String? value) {
    if (value == null || value.isEmpty) return '';
    return value.replaceAll(RegExp(r'\s+'), '').trim().toUpperCase();
  }

  static bool isValidContainerNumber(String? value) {
    final normalized = normalizeContainerNumber(value);
    if (normalized.isEmpty) return true;
    return _containerNumberRegex.hasMatch(normalized);
  }

  static ContainerNumberLiveFeedback containerNumberLiveFeedback(String? value) {
    final normalized = normalizeContainerNumber(value);

    if (normalized.isEmpty) {
      return const ContainerNumberLiveFeedback(
        status: ContainerNumberInputStatus.empty,
        message: AppCopy.containerFormatHint,
      );
    }

    if (_containerNumberRegex.hasMatch(normalized)) {
      return const ContainerNumberLiveFeedback(
        status: ContainerNumberInputStatus.valid,
        message: 'Valid container number',
      );
    }

    if (normalized.length > 11) {
      return const ContainerNumberLiveFeedback(
        status: ContainerNumberInputStatus.invalid,
        message: 'Too long — use exactly 11 characters (ABCD1234567)',
      );
    }

    for (var i = 0; i < normalized.length && i < 4; i++) {
      final ch = normalized[i];
      if (ch.compareTo('A') < 0 || ch.compareTo('Z') > 0) {
        return const ContainerNumberLiveFeedback(
          status: ContainerNumberInputStatus.invalid,
          message: 'First 4 characters must be letters (A–Z)',
        );
      }
    }

    if (normalized.length > 4) {
      for (var i = 4; i < normalized.length; i++) {
        final ch = normalized[i];
        if (ch.compareTo('0') < 0 || ch.compareTo('9') > 0) {
          return const ContainerNumberLiveFeedback(
            status: ContainerNumberInputStatus.invalid,
            message: 'Last 7 characters must be digits (0–9)',
          );
        }
      }
    }

    if (normalized.length < 4) {
      return ContainerNumberLiveFeedback(
        status: ContainerNumberInputStatus.typing,
        message: 'Letters ${normalized.length}/4, then 7 digits',
      );
    }

    if (normalized.length < 11) {
      return ContainerNumberLiveFeedback(
        status: ContainerNumberInputStatus.typing,
        message:
            'Digits ${normalized.length - 4}/7 (${11 - normalized.length} more to go)',
      );
    }

    return const ContainerNumberLiveFeedback(
      status: ContainerNumberInputStatus.invalid,
      message: 'Use 4 letters followed by 7 digits (e.g. abcd1234567)',
    );
  }

  static String? validateOptionalContainerNumber(String? value) {
    final normalized = normalizeContainerNumber(value);
    if (normalized.isEmpty) return null;
    if (!_containerNumberRegex.hasMatch(normalized)) {
      return containerNumberLiveFeedback(value).message;
    }
    return null;
  }

  static String? validateContainerNumber(String? value) {
    return validateOptionalContainerNumber(value);
  }
}

enum ContainerNumberInputStatus { empty, typing, valid, invalid }

class ContainerNumberLiveFeedback {
  final ContainerNumberInputStatus status;
  final String message;

  const ContainerNumberLiveFeedback({
    required this.status,
    required this.message,
  });

  bool get isValid => status == ContainerNumberInputStatus.valid;
  bool get isInvalid => status == ContainerNumberInputStatus.invalid;
}
