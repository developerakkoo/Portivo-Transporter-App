import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prottivo_transporter/core/constants/app_copy.dart';
import 'package:prottivo_transporter/utils/error_utils.dart';

void main() {
  group('ErrorUtils.userMessage', () {
    test('maps 409 driver duplicate to friendly copy', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/drivers'),
        response: Response(
          requestOptions: RequestOptions(path: '/drivers'),
          statusCode: 409,
          data: {
            'success': false,
            'message': 'Driver with this mobile number already exists',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      expect(
        ErrorUtils.userMessage(error),
        AppCopy.errorDriverAlreadyRegistered,
      );
    });

    test('replaces raw DioException dump with generic fallback', () {
      const dump =
          'DioException [bad response]: This exception was thrown because the response has a status code of 409';

      expect(
        ErrorUtils.userMessage(dump),
        AppCopy.errorGeneric,
      );
      expect(ErrorUtils.userMessage(dump), isNot(contains('DioException')));
    });

    test('maps connection timeout to timeout copy', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/drivers'),
        type: DioExceptionType.connectionTimeout,
      );

      expect(ErrorUtils.userMessage(error), AppCopy.errorTimeout);
    });

    test('maps connection error to offline copy', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/drivers'),
        type: DioExceptionType.connectionError,
      );

      expect(ErrorUtils.userMessage(error), AppCopy.errorOffline);
    });

    test('passes through unknown 400 API message', () {
      const apiMessage = 'Vehicle number is required';
      final error = DioException(
        requestOptions: RequestOptions(path: '/vehicles'),
        response: Response(
          requestOptions: RequestOptions(path: '/vehicles'),
          statusCode: 400,
          data: {
            'success': false,
            'message': apiMessage,
          },
        ),
        type: DioExceptionType.badResponse,
      );

      expect(ErrorUtils.userMessage(error), apiMessage);
    });

    test('maps linked-to-other-transporter message', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/drivers'),
        response: Response(
          requestOptions: RequestOptions(path: '/drivers'),
          statusCode: 409,
          data: {
            'success': false,
            'message': 'This mobile is already linked to another transporter',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      expect(
        ErrorUtils.userMessage(error),
        AppCopy.errorDriverLinkedToOtherTransporter,
      );
    });
  });

  group('ErrorUtils.messageFromDio', () {
    test('extracts backend message from response data', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/drivers'),
        response: Response(
          requestOptions: RequestOptions(path: '/drivers'),
          statusCode: 409,
          data: {
            'message': 'Driver with this mobile number already exists',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      expect(
        ErrorUtils.messageFromDio(error),
        'Driver with this mobile number already exists',
      );
    });
  });
}
