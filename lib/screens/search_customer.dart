import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';

class SearchCustomerScreen extends StatefulWidget {
  const SearchCustomerScreen({super.key});

  @override
  State<SearchCustomerScreen> createState() => _SearchCustomerScreenState();
}

class _SearchCustomerScreenState extends State<SearchCustomerScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _filteredCustomers = [];

  // Placeholder customer data
  final List<Map<String, String>> _allCustomers = [
    {'id': '1', 'name': 'ABC LOGISTICS INC'},
    {'id': '2', 'name': 'XYZ TRANSPORT LTD'},
    {'id': '3', 'name': 'DEF SHIPPING CO'},
    {'id': '4', 'name': 'GHI FREIGHT SERVICES'},
    {'id': '5', 'name': 'JKL CARGO SOLUTIONS'},
    {'id': '6', 'name': 'MNO DISTRIBUTION'},
    {'id': '7', 'name': 'PQR SUPPLY CHAIN'},
    {'id': '8', 'name': 'STU WAREHOUSE GROUP'},
    {'id': '9', 'name': 'VWX LOGISTICS PARTNERS'},
    {'id': '10', 'name': 'YZA TRANSPORT NETWORK'},
  ];

  @override
  void initState() {
    super.initState();
    _filteredCustomers = _allCustomers;
    _searchController.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCustomers() {
    final query = _searchController.text.toUpperCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _allCustomers;
      } else {
        _filteredCustomers = _allCustomers
            .where((customer) =>
                customer['name']!.toUpperCase().contains(query))
            .toList();
      }
    });
  }

  void _selectCustomer(Map<String, String> customer) {
    Navigator.of(context).pop(customer);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Search Customer'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: TextField(
                controller: _searchController,
                inputFormatters: [
                  UpperCaseTextFormatter(),
                ],
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'SEARCH CUSTOMER',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
                textInputAction: TextInputAction.search,
                autocorrect: false,
              ),
            ),

            // Customer List
            Expanded(
              child: _filteredCustomers.isEmpty
                  ? Center(
                      child: Text(
                        'NO CUSTOMERS FOUND',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        return _buildCustomerItem(customer, textTheme);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerItem(Map<String, String> customer, TextTheme textTheme) {
    return InkWell(
      onTap: () => _selectCustomer(customer),
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: AppColors.dividerGrey,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Icon(
                Icons.business,
                color: AppColors.primary,
                size: 24.0,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Text(
                customer['name']!,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// Text formatter to convert input to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
