import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/utils/json_parser.dart';
import '../data/models/transporter_customer_model.dart';
import 'api_service.dart';

class CustomerService {
  final ApiService _api = ApiService();

  Future<List<TransporterCustomerModel>> getCustomers({String? q}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (q != null && q.trim().isNotEmpty) {
        queryParams['q'] = q.trim();
      }

      final response = await _api.get(
        ApiConfig.transporterCustomers,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> results = [];
        if (data is Map && data['results'] is List) {
          results = data['results'] as List;
        } else if (data is List) {
          results = data;
        }
        if (results.isNotEmpty) {
          return JsonParser.extractList<TransporterCustomerModel>(
            results,
            (json) => TransporterCustomerModel.fromJson(json),
          );
        }
      }
      return [];
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('CustomerService: Error fetching customers: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }

  Future<TransporterCustomerModel?> createCustomer(String name) async {
    try {
      final response = await _api.post(
        ApiConfig.transporterCustomers,
        data: {'name': name.trim()},
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data is Map && data['customer'] != null) {
          final customer = data['customer'];
          if (customer is Map<String, dynamic>) {
            return TransporterCustomerModel.fromJson(customer);
          }
          if (customer is Map) {
            return TransporterCustomerModel.fromJson(
              Map<String, dynamic>.from(customer),
            );
          }
        }
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('CustomerService: Error creating customer: $e');
        print('Stack: $stackTrace');
      }
      rethrow;
    }
  }
}
