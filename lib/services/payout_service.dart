import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../data/models/beneficiary_model.dart';
import 'api_service.dart';

/// Builds POST /payouts/beneficiary body for Razorpay contact + fund account.
Map<String, dynamic> buildRazorpayBeneficiaryPayload({
  required String name,
  required String phone,
  required String bankAccount,
  required String ifsc,
  String? email,
}) {
  return <String, dynamic>{
    'name': name,
    'phone': phone,
    'bankAccount': bankAccount,
    'ifsc': ifsc,
    if (email != null && email.isNotEmpty) 'email': email,
  };
}

/// Manages the Razorpay payout beneficiary (bank account for receiving
/// payments). The backend registers a Razorpay contact + fund account.
class PayoutService {
  final ApiService _api = ApiService();

  /// Returns the registered beneficiary, or null when none exists yet.
  Future<BeneficiaryModel?> getBeneficiary() async {
    try {
      if (kDebugMode) {
        print('PayoutService: Fetching beneficiary');
      }

      final response = await _api.get(ApiConfig.payoutBeneficiary);

      if (response.data['success'] == true) {
        final beneficiaryJson = response.data['data']?['beneficiary'];
        if (beneficiaryJson is Map<String, dynamic>) {
          final beneficiary = BeneficiaryModel.fromJson(beneficiaryJson);
          return beneficiary.isActive ? beneficiary : null;
        }
      }
      return null;
    } on DioException catch (e) {
      // 404 means no beneficiary has been registered yet — not an error.
      if (e.response?.statusCode == 404) {
        return null;
      }
      final message =
          e.response?.data is Map ? '${e.response?.data['message'] ?? ''}' : '';
      if (message.toLowerCase().contains('not found')) {
        return null;
      }
      rethrow;
    }
  }

  Future<BeneficiaryModel> addBeneficiary({
    required String name,
    required String phone,
    required String bankAccount,
    required String ifsc,
    String? email,
  }) async {
    if (kDebugMode) {
      print('PayoutService: Adding beneficiary');
    }

    final response = await _api.post(
      ApiConfig.payoutBeneficiary,
      data: buildRazorpayBeneficiaryPayload(
        name: name,
        phone: phone,
        bankAccount: bankAccount,
        ifsc: ifsc,
        email: email,
      ),
    );

    if (response.data['success'] == true) {
      final beneficiaryJson = response.data['data']?['beneficiary'];
      if (beneficiaryJson is Map<String, dynamic>) {
        return BeneficiaryModel.fromJson(beneficiaryJson);
      }
    }

    throw Exception(
      response.data['message']?.toString() ?? 'Failed to add bank account',
    );
  }

  Future<bool> deleteBeneficiary() async {
    if (kDebugMode) {
      print('PayoutService: Deleting beneficiary');
    }

    final response = await _api.delete(ApiConfig.payoutBeneficiary);
    return response.data['success'] == true;
  }
}
