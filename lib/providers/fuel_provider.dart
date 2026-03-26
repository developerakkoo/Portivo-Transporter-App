import 'package:flutter/foundation.dart';
import '../data/models/fuel_card_model.dart';
import '../data/models/fuel_transaction_model.dart';
import '../services/fuel_card_service.dart';
import '../services/fuel_transaction_service.dart';
import '../utils/error_utils.dart';

class FuelProvider with ChangeNotifier {
  final FuelCardService _fuelCardService = FuelCardService();
  final FuelTransactionService _fuelTransactionService = FuelTransactionService();

  List<FuelCardModel> _fuelCards = [];
  List<FuelCardModel> _assignedCards = [];
  List<FuelTransactionModel> _transactions = [];
  FuelCardModel? _selectedCard;
  bool _isLoading = false;
  String? _error;

  List<FuelCardModel> get fuelCards => _fuelCards;
  List<FuelCardModel> get assignedCards => _assignedCards;
  List<FuelTransactionModel> get transactions => _transactions;
  FuelCardModel? get selectedCard => _selectedCard;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadFuelCards({
    String? status,
    bool? assigned,
    bool refresh = false,
  }) async {
    if (!refresh && _fuelCards.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cards = await _fuelCardService.getFuelCards(
        status: status,
        assigned: assigned,
      );

      if (refresh) {
        _fuelCards = cards;
      } else {
        _fuelCards = cards;
      }
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('FuelProvider: Error loading fuel cards: $_error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAssignedCards({bool refresh = false}) async {
    if (!refresh && _assignedCards.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cards = await _fuelCardService.getAssignedFuelCards();

      if (refresh) {
        _assignedCards = cards;
      } else {
        _assignedCards = cards;
      }
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('FuelProvider: Error loading assigned cards: $_error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTransactions({
    String? status,
    String? fuelCardId,
    String? driverId,
    String? startDate,
    String? endDate,
    bool refresh = false,
  }) async {
    if (!refresh && _transactions.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final transactions = await _fuelTransactionService.getTransactions(
        status: status,
        fuelCardId: fuelCardId,
        driverId: driverId,
        startDate: startDate,
        endDate: endDate,
      );

      if (refresh) {
        _transactions = transactions;
      } else {
        _transactions = transactions;
      }
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('FuelProvider: Error loading transactions: $_error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> generateQR({
    required String vehicleNumber,
    required double amount,
    required double latitude,
    required double longitude,
    double? accuracy,
    String? address,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _fuelTransactionService.generateQR(
        vehicleNumber: vehicleNumber,
        amount: amount,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        address: address,
      );
      return result;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('FuelProvider: Error generating QR: $_error');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> scanQR({
    required String qrCode,
    required double latitude,
    required double longitude,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _fuelTransactionService.scanQR(
        qrCode: qrCode,
        latitude: latitude,
        longitude: longitude,
      );
      return result;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('FuelProvider: Error scanning QR: $_error');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<FuelTransactionModel>> getFuelCardTransactions(String cardId) async {
    try {
      return await _fuelCardService.getFuelCardTransactions(cardId);
    } catch (e) {
      if (kDebugMode) {
        print('FuelProvider: Error getting card transactions: $e');
      }
      return [];
    }
  }

  void selectCard(FuelCardModel? card) {
    _selectedCard = card;
    notifyListeners();
  }

  Future<FuelCardModel?> createFuelCard({
    required String cardNumber,
    double? balance,
    DateTime? expiryDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final card = await _fuelCardService.createFuelCard(
        cardNumber: cardNumber,
        balance: balance,
        expiryDate: expiryDate,
      );

      if (card != null) {
        _fuelCards.insert(0, card);
        if (kDebugMode) {
          print('FuelProvider: Fuel card created successfully');
        }
      }
      return card;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('FuelProvider: Error creating fuel card: $_error');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<FuelCardModel?> assignFuelCard({
    required String cardId,
    required String driverId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final card = await _fuelCardService.assignFuelCard(
        cardId: cardId,
        driverId: driverId,
      );

      if (card != null) {
        final idx = _fuelCards.indexWhere((c) => c.id == cardId);
        if (idx >= 0) {
          _fuelCards[idx] = card;
        }
        if (kDebugMode) {
          print('FuelProvider: Fuel card assigned successfully');
        }
      }
      return card;
    } catch (e) {
      _error = ErrorUtils.extractErrorMessage(e);
      if (kDebugMode) {
        print('FuelProvider: Error assigning fuel card: $_error');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
