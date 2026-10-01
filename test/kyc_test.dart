import 'package:flutter_test/flutter_test.dart';

import 'package:prottivo_transporter/data/models/auth_response_model.dart';
import 'package:prottivo_transporter/data/models/kyc_model.dart';
import 'package:prottivo_transporter/screens/kyc/kyc_screen.dart';

void main() {
  group('kycSubmitBlockReason', () {
    test('blocks missing PAN, Aadhaar, and images', () {
      expect(
        kycSubmitBlockReason(
          pan: '',
          aadhaar: '123456789012',
          hasPanImage: true,
          hasAadhaarImage: true,
          hasBank: true,
        ),
        'PAN number is required',
      );
      expect(
        kycSubmitBlockReason(
          pan: 'ABCDE1234F',
          aadhaar: '123',
          hasPanImage: true,
          hasAadhaarImage: true,
          hasBank: true,
        ),
        'Enter a 12-digit Aadhaar number',
      );
      expect(
        kycSubmitBlockReason(
          pan: 'ABCDE1234F',
          aadhaar: '123456789012',
          hasPanImage: false,
          hasAadhaarImage: true,
          hasBank: true,
        ),
        'PAN image is required',
      );
      expect(
        kycSubmitBlockReason(
          pan: 'ABCDE1234F',
          aadhaar: '123456789012',
          hasPanImage: true,
          hasAadhaarImage: false,
          hasBank: true,
        ),
        'Aadhaar image is required',
      );
    });

    test('does not block submit when bank details are missing', () {
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

    test('allows complete KYC payload without bank', () {
      expect(
        kycSubmitBlockReason(
          pan: 'ABCDE1234F',
          aadhaar: '1234 5678 9012',
          hasPanImage: true,
          hasAadhaarImage: true,
          hasBank: false,
        ),
        isNull,
      );
    });
  });

  group('TransporterKyc', () {
    test('parses GET payload and reports missing Aadhaar image', () {
      final kyc = TransporterKyc.fromJson({
        'status': 'pending',
        'isCompleted': false,
        'panNumber': 'ABCDE1234F',
        'panImage': 'https://api.example.com/uploads/kyc/pan.jpg',
        'aadhaarNumber': '123456789012',
        'bankDetails': {'isAdded': true, 'source': 'direct'},
        'networkAccessGranted': false,
      });
      expect(kyc.hasExistingPanImage, isTrue);
      expect(kyc.bankDetails.isAdded, isTrue);
      expect(kycMissingRequirement(kyc), 'Aadhaar image is missing');
    });

    test('completed KYC grants network access fields', () {
      final kyc = TransporterKyc.fromJson({
        'status': 'completed',
        'isCompleted': true,
        'panNumber': 'ABCDE1234F',
        'panImage': 'https://api.example.com/uploads/kyc/pan.jpg',
        'aadhaarNumber': '123456789012',
        'aadhaarImage': 'https://api.example.com/uploads/kyc/aadhaar.jpg',
        'networkAccessGranted': true,
      });
      expect(kycMissingRequirement(kyc), isNull);
      expect(kyc.networkAccessGranted, isTrue);
    });
  });

  group('UserModel KYC status', () {
    test('treats completed profile KYC as verified', () {
      final user = UserModel.fromJson({
        'id': 't1',
        'mobile': '9999999999',
        'userType': 'transporter',
        'status': 'active',
        'hasAccess': true,
        'kycStatus': 'completed',
        'isKycCompleted': true,
      });
      expect(user.isKycCompleted, isTrue);
      expect(user.isKycVerified, isTrue);
    });
  });

  group('maskKycNumber', () {
    test('masks all but the last four characters', () {
      expect(maskKycNumber('ABCDE1234F'), '******234F');
      expect(maskKycNumber('123456789012'), '********9012');
    });

    test('returns empty for missing values', () {
      expect(maskKycNumber(null), '');
      expect(maskKycNumber('  '), '');
    });
  });
}
