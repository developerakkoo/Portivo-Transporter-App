import 'package:dio/dio.dart';

import '../core/config/api_config.dart';
import '../data/models/kyc_model.dart';
import 'api_service.dart';

class KycService {
  KycService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  Future<TransporterKyc> getKyc() async {
    final response = await _api.get(ApiConfig.transporterKyc);
    final normalized = _api.normalizeResponse(response);
    if (normalized['success'] == true) {
      final data = normalized['data'];
      final kyc = data is Map ? data['kyc'] : null;
      return TransporterKyc.fromJson(
        kyc is Map ? Map<String, dynamic>.from(kyc) : null,
      );
    }
    throw Exception(normalized['message'] ?? 'Failed to load KYC');
  }

  Future<TransporterKyc> submitKyc({
    required String panNumber,
    required String aadhaarNumber,
    String? panImagePath,
    String? aadhaarImagePath,
    String? aadhaarBackImagePath,
    String? existingPanImageUrl,
    String? existingAadhaarImageUrl,
    String? existingAadhaarBackImageUrl,
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? bankName,
    bool isUpdate = false,
  }) async {
    final formMap = <String, dynamic>{
      'panNumber': panNumber,
      'aadhaarNumber': aadhaarNumber,
    };

    if (panImagePath != null && panImagePath.isNotEmpty) {
      formMap['panImage'] = await MultipartFile.fromFile(
        panImagePath,
        filename: _filename(panImagePath),
      );
    } else if (existingPanImageUrl != null && existingPanImageUrl.isNotEmpty) {
      formMap['panImage'] = existingPanImageUrl;
    }

    if (aadhaarImagePath != null && aadhaarImagePath.isNotEmpty) {
      formMap['aadhaarImage'] = await MultipartFile.fromFile(
        aadhaarImagePath,
        filename: _filename(aadhaarImagePath),
      );
    } else if (existingAadhaarImageUrl != null &&
        existingAadhaarImageUrl.isNotEmpty) {
      formMap['aadhaarImage'] = existingAadhaarImageUrl;
    }

    if (aadhaarBackImagePath != null && aadhaarBackImagePath.isNotEmpty) {
      formMap['aadhaarBackImage'] = await MultipartFile.fromFile(
        aadhaarBackImagePath,
        filename: _filename(aadhaarBackImagePath),
      );
    } else if (existingAadhaarBackImageUrl != null &&
        existingAadhaarBackImageUrl.isNotEmpty) {
      formMap['aadhaarBackImage'] = existingAadhaarBackImageUrl;
    }

    if (accountHolderName != null && accountHolderName.trim().isNotEmpty) {
      formMap['accountHolderName'] = accountHolderName.trim();
    }
    if (accountNumber != null && accountNumber.trim().isNotEmpty) {
      formMap['accountNumber'] = accountNumber.trim();
    }
    if (ifscCode != null && ifscCode.trim().isNotEmpty) {
      formMap['ifscCode'] = ifscCode.trim().toUpperCase();
    }
    if (bankName != null && bankName.trim().isNotEmpty) {
      formMap['bankName'] = bankName.trim();
    }

    final formData = FormData.fromMap(formMap);
    final response = isUpdate
        ? await _api.putMultipart(ApiConfig.transporterKyc, formData: formData)
        : await _api.postMultipart(ApiConfig.transporterKyc, formData: formData);

    final normalized = _api.normalizeResponse(response);
    if (normalized['success'] == true) {
      final data = normalized['data'];
      final kyc = data is Map ? data['kyc'] : null;
      return TransporterKyc.fromJson(
        kyc is Map ? Map<String, dynamic>.from(kyc) : null,
      );
    }
    throw Exception(normalized['message'] ?? 'Failed to submit KYC');
  }

  String _filename(String path) {
    final parts = path.split(RegExp(r'[\\/]+'));
    return parts.isEmpty ? 'document' : parts.last;
  }
}

bool isKycRequiredError(dynamic error) {
  if (error is! DioException) return false;
  if (error.response?.statusCode != 403) return false;
  final data = error.response?.data;
  return data is Map && data['code']?.toString() == 'KYC_REQUIRED';
}
