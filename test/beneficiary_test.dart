import 'package:flutter_test/flutter_test.dart';
import 'package:prottivo_transporter/data/models/beneficiary_model.dart';
import 'package:prottivo_transporter/screens/kyc/kyc_screen.dart';
import 'package:prottivo_transporter/services/payout_service.dart';

void main() {
  group('buildRazorpayBeneficiaryPayload', () {
    test('posts Razorpay fields only', () {
      final payload = buildRazorpayBeneficiaryPayload(
        name: 'Alpha Logistics',
        phone: '9999999999',
        bankAccount: '123456789012',
        ifsc: 'HDFC0001234',
        email: 'alpha@example.com',
      );

      expect(payload.keys.toSet(), {
        'name',
        'phone',
        'bankAccount',
        'ifsc',
        'email',
      });
      expect(payload.containsKey('address1'), isFalse);
      expect(payload.containsKey('city'), isFalse);
      expect(payload.containsKey('state'), isFalse);
      expect(payload.containsKey('pincode'), isFalse);
      expect(payload.containsKey('country'), isFalse);
    });

    test('omits empty email', () {
      final payload = buildRazorpayBeneficiaryPayload(
        name: 'Alpha Logistics',
        phone: '9999999999',
        bankAccount: '123456789012',
        ifsc: 'HDFC0001234',
        email: '',
      );
      expect(payload.containsKey('email'), isFalse);
    });
  });

  group('BeneficiaryModel.isActive', () {
    test('is false without a Razorpay fund account id', () {
      final cashfreeOnly = BeneficiaryModel.fromJson({
        'name': 'Legacy',
        'maskedAccountNumber': '****7890',
        'ifsc': 'HDFC0001234',
        'verificationStatus': 'ACTIVE',
      });
      expect(cashfreeOnly.isActive, isFalse);
    });

    test('is false when Razorpay status is DELETED', () {
      final deleted = BeneficiaryModel.fromJson({
        'razorpayFundAccountId': 'fa_1',
        'razorpayFundAccountStatus': 'DELETED',
      });
      expect(deleted.isActive, isFalse);
    });

    test('is true when a Razorpay fund account id is present', () {
      final razorpay = BeneficiaryModel.fromJson({
        'name': 'Alpha Logistics',
        'razorpayFundAccountId': 'fa_1',
        'razorpayFundAccountStatus': 'ACTIVE',
      });
      expect(razorpay.isActive, isTrue);
    });
  });

  group('KYC bank gate', () {
    test('does not block submit when Razorpay bank is missing', () {
      expect(
        kycSubmitBlockReason(
          pan: 'ABCDE1234F',
          aadhaar: '123456789012',
          hasPanImage: true,
          hasAadhaarImage: true,
          hasBank: false,
        ),
        isNull,
      );
    });
  });
}
