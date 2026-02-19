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

  late Dio _dio;
  final StorageService _storage = StorageService();

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
          
          // Handle 401 Unauthorized - try to refresh token
          if (error.response?.statusCode == 401) {
            if (kDebugMode) {
              print('ApiService: 401 Unauthorized, attempting token refresh');
            }
            try {
              final refreshed = await _refreshToken();
              if (refreshed) {
                if (kDebugMode) {
                  print('ApiService: Token refreshed, retrying request');
                }
                // Retry the original request
                final opts = error.requestOptions;
                final token = await _storage.getAccessToken();
                if (token != null) {
                  opts.headers['Authorization'] = 'Bearer $token';
                  final response = await _dio.request(
                    opts.path,
                    options: Options(
                      method: opts.method,
                      headers: opts.headers,
                    ),
                    data: opts.data,
                    queryParameters: opts.queryParameters,
                  );
                  return handler.resolve(response);
                } else {
                  if (kDebugMode) {
                    print('ApiService: Token refresh succeeded but no token retrieved');
                  }
                }
              } else {
                if (kDebugMode) {
                  print('ApiService: Token refresh failed');
                }
              }
            } catch (e) {
              if (kDebugMode) {
                print('ApiService: Error during token refresh: $e');
              }
              // Refresh failed, clear tokens
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
