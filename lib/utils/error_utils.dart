import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_copy.dart';

/// Utility class for extracting user-friendly error messages from exceptions.
class ErrorUtils {
  static const _genericFallback = AppCopy.errorGeneric;
  static const _technicalPatterns = [
    'DioException',
    'RequestOptions',
    'validateStatus',
    'bad response',
  ];

  /// Primary API for user-facing error text in UI and providers.
  static String userMessage(dynamic error, {String? fallback}) {
    final raw = extractErrorMessage(error);
    final statusCode = error is DioException ? error.response?.statusCode : null;
    final mapped = _mapBackendMessage(raw, statusCode: statusCode);
    if (_looksTechnical(mapped)) {
      return fallback ?? _genericFallback;
    }
    return mapped;
  }

  /// Extract backend/API message from a [DioException], if present.
  static String? messageFromDio(DioException error) {
    return extractBackendMessage(error);
  }

  /// Extract user-friendly error message from exception.
  /// Handles DioException and extracts backend error messages.
  static String extractErrorMessage(dynamic error) {
    try {
      if (error is DioException) {
        if (error.response?.data != null) {
          final responseData = error.response!.data;
          if (responseData is Map<String, dynamic>) {
            final message = responseData['message'];
            if (message != null && message.toString().isNotEmpty) {
              return message.toString();
            }
          }
        }

        final statusCode = error.response?.statusCode;
        if (statusCode == 400) {
          return AppCopy.errorInvalidRequest;
        }
        if (statusCode == 401) {
          return AppCopy.errorAuthenticationFailed;
        }
        if (statusCode == 403) {
          return AppCopy.errorPermissionDenied;
        }
        if (statusCode == 404) {
          return AppCopy.errorNotFound;
        }
        if (statusCode == 409) {
          return AppCopy.errorAlreadyExists;
        }
        if (statusCode == 422) {
          return AppCopy.errorInvalidRequest;
        }
        if (statusCode == 500) {
          return AppCopy.errorServer;
        }

        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          return AppCopy.errorTimeout;
        }

        if (error.type == DioExceptionType.connectionError) {
          return AppCopy.errorOffline;
        }

        if (error.message != null && error.message!.isNotEmpty) {
          return error.message!;
        }
      }

      if (error is String) {
        return _normalizeMessage(error);
      }

      final errorString = _normalizeMessage(error.toString());

      if (errorString.contains('Transporter not registered')) {
        return 'Your account is not registered. Please contact admin for registration.';
      }
      if (errorString.contains('Transporter not found')) {
        return 'Account not found. Please check your mobile number.';
      }
      if (errorString.contains('Invalid PIN')) {
        return 'Invalid PIN. Please try again.';
      }
      if (errorString.contains('All') &&
          errorString.contains('milestones') &&
          errorString.contains('completed')) {
        final match =
            RegExp(r'All (\d+) milestones must be completed').firstMatch(errorString);
        if (match != null) {
          return 'All ${match.group(1)} milestones must be completed before completing the trip.';
        }
        return 'All milestones must be completed before completing the trip.';
      }
      if (errorString.contains('Only') &&
          errorString.contains('trips can be cancelled')) {
        final match =
            RegExp(r'Only (\w+) trips can be cancelled').firstMatch(errorString);
        if (match != null) {
          return 'Only ${match.group(1)} trips can be cancelled.';
        }
        return 'This trip cannot be cancelled in its current state.';
      }
      if (errorString.contains('timeout')) {
        return AppCopy.errorTimeout;
      }
      if (errorString.contains('Connection error') ||
          errorString.contains('connectionError')) {
        return AppCopy.errorOffline;
      }

      if (errorString.length <= 150 && !_looksTechnical(errorString)) {
        return errorString;
      }

      return _genericFallback;
    } catch (e) {
      if (kDebugMode) {
        print('ErrorUtils: Error extracting error message: $e');
      }
      return _genericFallback;
    }
  }

  static String? extractBackendMessage(DioException error) {
    try {
      if (error.response?.data != null) {
        final responseData = error.response!.data;
        if (responseData is Map<String, dynamic>) {
          return responseData['message']?.toString();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ErrorUtils: Error extracting backend message: $e');
      }
    }
    return null;
  }

  static String _normalizeMessage(String message) {
    var normalized = message.trim();
    if (normalized.startsWith('Exception: ')) {
      normalized = normalized.substring('Exception: '.length).trim();
    }
    return normalized;
  }

  static bool _looksTechnical(String message) {
    final lower = message.toLowerCase();
    for (final pattern in _technicalPatterns) {
      if (lower.contains(pattern.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  static String _mapBackendMessage(String message, {int? statusCode}) {
    final normalized = _normalizeMessage(message);
    final lower = normalized.toLowerCase();

    if (lower.contains('driver with this mobile number already exists') ||
        (lower.contains('driver') &&
            lower.contains('already') &&
            statusCode == 409)) {
      return AppCopy.errorDriverAlreadyRegistered;
    }
    if (lower.contains('already linked to another transporter')) {
      return AppCopy.errorDriverLinkedToOtherTransporter;
    }
    if (lower.contains('transporter with mobile number already exists')) {
      return AppCopy.errorTransporterAlreadyRegistered;
    }
    if (statusCode == 409 &&
        (lower.contains('already exists') || lower.contains('duplicate'))) {
      return AppCopy.errorAlreadyExists;
    }
    if (statusCode == 403) {
      return AppCopy.errorPermissionDenied;
    }
    if (statusCode == 500) {
      return AppCopy.errorServer;
    }

    return normalized;
  }
}
