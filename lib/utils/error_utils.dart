import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Utility class for extracting user-friendly error messages from exceptions
class ErrorUtils {
  /// Extract user-friendly error message from exception
  /// Handles DioException and extracts backend error messages
  static String extractErrorMessage(dynamic error) {
    try {
      // Handle DioException
      if (error is DioException) {
        // Try to extract message from response data first
        if (error.response?.data != null) {
          final responseData = error.response!.data;
          if (responseData is Map<String, dynamic>) {
            final message = responseData['message'];
            if (message != null && message.toString().isNotEmpty) {
              return message.toString();
            }
          }
        }
        
        // Handle specific status codes
        final statusCode = error.response?.statusCode;
        if (statusCode == 400) {
          return 'Invalid request. Please check your input and try again.';
        }
        if (statusCode == 401) {
          return 'Authentication failed. Please login again.';
        }
        if (statusCode == 403) {
          return 'Access denied. You do not have permission to perform this action.';
        }
        if (statusCode == 404) {
          return 'Resource not found. Please check your request.';
        }
        if (statusCode == 500) {
          return 'Server error. Please try again later.';
        }
        
        // Handle network errors
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          return 'Request timed out. Please check your connection and try again.';
        }
        
        if (error.type == DioExceptionType.connectionError) {
          return 'Unable to connect to server. Please check your internet connection.';
        }
        
        // Use DioException's message if available
        if (error.message != null && error.message!.isNotEmpty) {
          return error.message!;
        }
      }
      
      // Handle string errors
      if (error is String) {
        return error;
      }
      
      // Try to extract from error string
      final errorString = error.toString();
      
      // Check for common error patterns in string representation
      if (errorString.contains('Transporter not registered')) {
        return 'Your account is not registered. Please contact admin for registration.';
      }
      if (errorString.contains('Transporter not found')) {
        return 'Account not found. Please check your mobile number.';
      }
      if (errorString.contains('Invalid PIN')) {
        return 'Invalid PIN. Please try again.';
      }
      if (errorString.contains('All') && errorString.contains('milestones') && errorString.contains('completed')) {
        // Extract the specific milestone message if available
        final match = RegExp(r'All (\d+) milestones must be completed').firstMatch(errorString);
        if (match != null) {
          return 'All ${match.group(1)} milestones must be completed before completing the trip.';
        }
        return 'All milestones must be completed before completing the trip.';
      }
      if (errorString.contains('Only') && errorString.contains('trips can be cancelled')) {
        // Extract the status requirement
        final match = RegExp(r'Only (\w+) trips can be cancelled').firstMatch(errorString);
        if (match != null) {
          return 'Only ${match.group(1)} trips can be cancelled.';
        }
        return 'This trip cannot be cancelled in its current state.';
      }
      if (errorString.contains('timeout')) {
        return 'Request timed out. Please try again.';
      }
      if (errorString.contains('Connection error') || errorString.contains('connectionError')) {
        return 'Unable to connect to server. Please check your internet connection.';
      }
      
      // Fallback: return error string if it's reasonable length
      if (errorString.length <= 150) {
        return errorString;
      }
      
      return 'An error occurred. Please try again.';
    } catch (e) {
      if (kDebugMode) {
        print('ErrorUtils: Error extracting error message: $e');
      }
      return 'An unexpected error occurred. Please try again.';
    }
  }
  
  /// Extract error message from DioException response data
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
}
