import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _dio = Dio(_baseOptions);
    _setupInterceptors();
  }

  /// Set on [RequestOptions.extra] after one token refresh + retry so a second
  /// 401 does not trigger another refresh (avoids infinite loops when the user
  /// is gone or the token is permanently invalid).
  static const String _kAuthRefreshRetriedKey = 'porttivo.auth_refresh_retried';

  late Dio _dio;
  final StorageService _storage = StorageService();

  static String? _lowercaseMessageFromBody(dynamic data) {
    if (data is Map && data['message'] != null) {
      return data['message'].toString().toLowerCase();
    }
    return null;
  }

  /// 401 responses where refreshing the session cannot help (user deleted, etc.).
  static bool _isNonRecoverable401(Response? response) {
    final msg = _lowercaseMessageFromBody(response?.data);
    if (msg == null) return false;
    if (msg.contains('user not found')) return true;
    if (msg.contains('transporter not found')) return true;
    if (msg.contains('account') && msg.contains('deleted')) return true;
    return false;
  }

  static bool _shouldSkip401RefreshRecovery(RequestOptions options) {
    final path = options.path;
    if (path == ApiConfig.refreshToken) return true;
    if (path == ApiConfig.sendOTP) return true;
    if (path == ApiConfig.pinLogin) return true;
    if (path == ApiConfig.companyUserLogin) return true;
    if (path == ApiConfig.register) return true;
    return false;
  }

  BaseOptions get _baseOptions => BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (kDebugMode) {
            print('ApiService: ${options.method} ${options.path}');
          }
          try {
            // Ensure storage is initialized
            if (!_storage.isInitialized) {
              await _storage.init();
            }
            
            // Add access token to headers
            final token = await _storage.getAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
              if (kDebugMode) {
                print('ApiService: Token added to request: ${options.path}');
              }
            } else {
              if (kDebugMode) {
                print('ApiService: WARNING - No token found for request: ${options.path}');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('ApiService: Error getting token: $e');
            }
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (kDebugMode) {
            print('ApiService: Error ${error.response?.statusCode} on ${error.requestOptions.path}');
            print('Error message: ${error.message}');
            print('Request URL: ${error.requestOptions.uri}');
            if (error.response?.data != null) {
              print('Error response: ${error.response?.data}');
            }
          }
          
          // Handle 400 Bad Request - extract user-friendly message
          if (error.response?.statusCode == 400) {
            if (kDebugMode) {
              print('ApiService: 400 Bad Request - Extracting user-friendly message');
              try {
                final errorData = error.response?.data;
                if (errorData is Map && errorData['message'] != null) {
                  final backendMessage = errorData['message'].toString();
                  print('ApiService: Backend error message: $backendMessage');
                  // The error message will be extracted by the provider's _extractErrorMessage method
                }
              } catch (e) {
                if (kDebugMode) {
                  print('ApiService: Error extracting 400 message: $e');
                }
              }
            }
          }
          
          // Handle 404 Not Found - log user-friendly message
          if (error.response?.statusCode == 404) {
            if (kDebugMode) {
              print('ApiService: 404 Not Found - Extracting user-friendly message');
              try {
                final errorData = error.response?.data;
                if (errorData is Map && errorData['message'] != null) {
                  final backendMessage = errorData['message'].toString();
                  print('ApiService: Backend error message: $backendMessage');
                  // The error message will be extracted by the provider's _extractErrorMessage method
                }
              } catch (e) {
                if (kDebugMode) {
                  print('ApiService: Error extracting 404 message: $e');
                }
              }
            }
          }
          
          // Handle 401 Unauthorized - try to refresh token once, then stop.
          if (error.response?.statusCode == 401) {
            final req = error.requestOptions;
            if (_shouldSkip401RefreshRecovery(req)) {
              return handler.next(error);
            }
            if (req.extra[_kAuthRefreshRetriedKey] == true) {
              if (kDebugMode) {
                print(
                  'ApiService: 401 after token refresh retry — clearing session',
                );
              }
              await _storage.clearTokens();
              return handler.next(error);
            }
            if (_isNonRecoverable401(error.response)) {
              if (kDebugMode) {
                print(
                  'ApiService: 401 non-recoverable (${_lowercaseMessageFromBody(error.response?.data)}), clearing session',
                );
              }
              await _storage.clearTokens();
              return handler.next(error);
            }
            if (kDebugMode) {
              print('ApiService: 401 Unauthorized, attempting token refresh');
            }
            try {
              final refreshed = await _refreshToken();
              final token = await _storage.getAccessToken();
              if (refreshed && token != null) {
                if (kDebugMode) {
                  print('ApiService: Token refreshed, retrying request');
                }
                req.headers['Authorization'] = 'Bearer $token';
                req.extra[_kAuthRefreshRetriedKey] = true;
                try {
                  final response = await _dio.fetch(req);
                  return handler.resolve(response);
                } on DioException catch (e) {
                  return handler.next(e);
                }
              } else {
                if (kDebugMode) {
                  print('ApiService: Token refresh failed or no access token');
                }
                await _storage.clearTokens();
              }
            } catch (e) {
              if (kDebugMode) {
                print('ApiService: Error during token refresh: $e');
              }
              await _storage.clearTokens();
            }
          }
          
          // Handle 403 Forbidden
          if (error.response?.statusCode == 403) {
            if (kDebugMode) {
              print('ApiService: 403 Forbidden - Access denied');
            }
          }
          
          // Handle network errors
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout) {
            if (kDebugMode) {
              print('ApiService: Network timeout error');
            }
          }
          
          if (error.type == DioExceptionType.connectionError) {
            if (kDebugMode) {
              print('ApiService: Connection error - Check network connectivity');
            }
          }
          
          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    try {
      if (kDebugMode) {
        print('ApiService: Attempting token refresh');
      }
      
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        if (kDebugMode) {
          print('ApiService: No refresh token available');
        }
        return false;
      }

      final response = await _dio.post(
        ApiConfig.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await _storage.saveAccessToken(data['accessToken']);
        if (data['refreshToken'] != null) {
          await _storage.saveRefreshToken(data['refreshToken']);
        }
        if (kDebugMode) {
          print('ApiService: Token refresh successful');
        }
        return true;
      }
      
      if (kDebugMode) {
        print('ApiService: Token refresh failed: ${response.data['message']}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('ApiService: Token refresh error: $e');
      }
      return false;
    }
  }

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  // PATCH request
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  // POST with file upload (multipart)
  Future<Response> postMultipart(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: formData,
        queryParameters: queryParameters,
        options: options ??
            Options(
              contentType: 'multipart/form-data',
            ),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Normalize and validate API response structure
  /// Ensures consistent response format across all endpoints
  Map<String, dynamic> normalizeResponse(Response response) {
    try {
      final data = response.data;
      
      // If response is not a Map, return error structure
      if (data is! Map) {
        if (kDebugMode) {
          print('ApiService: Response data is not a Map: ${data.runtimeType}');
        }
        return {
          'success': false,
          'message': 'Invalid response format',
          'data': null,
        };
      }
      
      final responseMap = data as Map<String, dynamic>;
      
      // Ensure success field exists
      if (!responseMap.containsKey('success')) {
        if (kDebugMode) {
          print('ApiService: Response missing success field');
        }
        responseMap['success'] = response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300;
      }
      
      // Ensure data field exists (can be null)
      if (!responseMap.containsKey('data')) {
        if (kDebugMode) {
          print('ApiService: Response missing data field');
        }
        responseMap['data'] = null;
      }
      
      return responseMap;
    } catch (e) {
      if (kDebugMode) {
        print('ApiService: Error normalizing response: $e');
      }
      return {
        'success': false,
        'message': 'Error processing response',
        'data': null,
      };
    }
  }

  /// Validate response has success = true
  bool isSuccessResponse(Response response) {
    try {
      final normalized = normalizeResponse(response);
      return normalized['success'] == true;
    } catch (e) {
      if (kDebugMode) {
        print('ApiService: Error validating success response: $e');
      }
      return false;
    }
  }

  /// Extract data from response safely
  dynamic extractResponseData(Response response) {
    try {
      final normalized = normalizeResponse(response);
      return normalized['data'];
    } catch (e) {
      if (kDebugMode) {
        print('ApiService: Error extracting response data: $e');
      }
      return null;
    }
  }

  /// Extract error message from response
  String extractErrorMessage(Response response) {
    try {
      final normalized = normalizeResponse(response);
      return normalized['message']?.toString() ?? 
             normalized['error']?.toString() ?? 
             'Unknown error occurred';
    } catch (e) {
      if (kDebugMode) {
        print('ApiService: Error extracting error message: $e');
      }
      return 'Error processing response';
    }
  }

  Dio get dio => _dio;
}
