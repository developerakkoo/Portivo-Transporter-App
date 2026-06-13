import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/validators.dart';
import '../../data/models/marketplace_chat_models.dart';
import '../../data/models/vehicle_post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/marketplace_chat_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/vehicle_type_provider.dart';
import '../../services/vehicle_booking_service.dart';
import '../../services/vehicle_post_service.dart';
import '../../utils/marketplace_chat_initials.dart';
import '../../widgets/searchable_vehicle_type_picker.dart';
import 'edit_vehicle_post_screen.dart';
import 'marketplace_chat_screen.dart';
import 'vehicle_post_detail_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MarketplaceChatProvider>().loadConversations(silent: true);
      context.read<VehicleTypeProvider>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Marketplace'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(text: 'Search'),
              const Tab(text: 'Post vehicle'),
              const Tab(text: 'My listings'),
              Tab(
                child: Consumer<MarketplaceChatProvider>(
                  builder: (context, chat, _) {
                    final n = chat.totalUnread;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Chats'),
                        if (n > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              n > 99 ? '99+' : '$n',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MarketplaceSearchTab(),
            _MarketplacePostTab(),
            _MyListingsTab(),
            _MarketplaceChatsTab(),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceSearchTab extends StatefulWidget {
  const _MarketplaceSearchTab();

  @override
  State<_MarketplaceSearchTab> createState() => _MarketplaceSearchTabState();
}

class _MarketplaceSearchTabState extends State<_MarketplaceSearchTab> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _service = VehiclePostService();

  String? _vehicleType;
  DateTime _filterDate = DateTime.now();

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  List<VehiclePostModel> _results = [];
  int _total = 0;
  int _page = 1;
  static const int _pageSize = 20;
  final ScrollController _searchScrollController = ScrollController();
  final GlobalKey _searchResultsKey = GlobalKey();

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _searchScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
    }
  }

  void _clearSearchOrigin() {
    setState(() {
      _originCtrl.clear();
    });
  }

  void _clearSearchDestination() {
    setState(() {
      _destCtrl.clear();
    });
  }

  Future<void> _runSearch({bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMore || _results.length >= _total) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }

    final pageToFetch = loadMore ? _page + 1 : 1;

    try {
      final res = await _service.search(
        origin: _originCtrl.text.trim().isEmpty ? null : _originCtrl.text.trim(),
        destination:
            _destCtrl.text.trim().isEmpty ? null : _destCtrl.text.trim(),
        date: _filterDate,
        vehicleType: _vehicleType,
        page: pageToFetch,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _results = [..._results, ...res.results];
          _page = pageToFetch;
          _loadingMore = false;
          _total = res.total;
        } else {
          _results = res.results;
          _total = res.total;
          _page = 1;
          _loading = false;
        }
      });
      if (!loadMore && _results.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final ctx = _searchResultsKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              alignment: 0.05,
            );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _loadingMore = false;
        if (!loadMore) {
          _results = [];
          _total = 0;
        }
      });
    }
  }

  bool _isOwnPost(VehiclePostModel p, AuthProvider auth) {
    final u = auth.user;
    if (u == null || p.transporterId == null) return false;
    final self = u.transporterId ?? u.id;
    return p.transporterId == self;
  }

  void _showListingNeedsVehiclesSnack(
    BuildContext context,
    VehiclePostModel p,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'This listing has no fleet vehicles yet. Open details to contact the seller or choose another listing.',
        ),
        action: SnackBarAction(
          label: 'Details',
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (ctx) => VehiclePostDetailScreen(
                  postId: p.id,
                  initialPost: p,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<VehiclePostAssignment?> _pickAssignment(
    BuildContext context,
    VehiclePostModel p,
  ) async {
    final av = p.availableVehicles;
    if (av.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vehicle slots on this listing yet.')),
      );
      return null;
    }
    if (av.length == 1) return av.first;
    return showModalBottomSheet<VehiclePostAssignment>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Choose vehicle',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              ...av.map(
                (a) => ListTile(
                  title: Text(a.vehicleNumber ?? 'Vehicle'),
                  subtitle: a.price != null ? Text('Listed: ₹${a.price}') : null,
                  onTap: () => Navigator.pop(ctx, a),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startChat(BuildContext context, VehiclePostModel p) async {
    final auth = context.read<AuthProvider>();
    if (_isOwnPost(p, auth)) return;
    final assignment = await _pickAssignment(context, p);
    if (assignment == null || !context.mounted) return;
    try {
      final bookingSvc = VehicleBookingService();
      final bookingMap = await bookingSvc.createOrGetBooking(
        postId: p.id,
        assignmentId: assignment.id,
      );
      final bookingId = bookingMap['id']?.toString() ?? bookingMap['_id']?.toString();
      if (bookingId == null) throw Exception('Invalid booking');
      if (!context.mounted) return;
      final peerId = p.transporterId;
      final route = p.routeDisplayLine;
      final label = [
        if (p.transporterCompany != null) p.transporterCompany,
        if (p.transporterName != null) p.transporterName,
      ].whereType<String>().join(' · ');
      context.read<MarketplaceChatProvider>().loadConversations(silent: true);
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (ctx) => MarketplaceChatScreen(
            bookingId: bookingId,
            routeLabel: route,
            counterpartyLabel: label.isEmpty ? 'Transporter' : label,
            counterpartyTransporterId: peerId,
          ),
        ),
      );
      if (context.mounted) {
        context.read<MarketplaceChatProvider>().loadConversations(silent: true);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openNegotiate(BuildContext context, VehiclePostModel p) async {
    final auth = context.read<AuthProvider>();
    if (_isOwnPost(p, auth)) return;
    final assignment = await _pickAssignment(context, p);
    if (assignment == null || !context.mounted) return;
    final listed = assignment.price ?? p.pricePerVehicle;
    final result = await showDialog<_MarketplaceListNegotiateResult>(
      context: context,
      builder: (ctx) => _MarketplaceListNegotiateDialog(referencePrice: listed),
    );
    if (result == null || !context.mounted) return;
    try {
      final bookingSvc = VehicleBookingService();
      final bookingMap = await bookingSvc.createOrGetBooking(
        postId: p.id,
        assignmentId: assignment.id,
      );
      final bookingId = bookingMap['id']?.toString() ?? bookingMap['_id']?.toString();
      if (bookingId == null) throw Exception('Invalid booking');
      await bookingSvc.proposePrice(
        bookingId: bookingId,
        proposedPrice: result.price,
        message: result.message,
      );
      if (!context.mounted) return;
      context.read<MarketplaceChatProvider>().loadConversations(silent: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer sent. Check Chats for replies.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateFmt = DateFormat.yMMMd();
    final auth = context.watch<AuthProvider>();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await _runSearch(loadMore: false);
        },
        child: CustomScrollView(
          controller: _searchScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Type any part of an address (case-insensitive). Matches are checked against each listing’s origin, destination, and extra stops. Leave both fields empty to list all active posts for the selected date and vehicle type.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextFormField(
              controller: _originCtrl,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Origin (optional)',
                hintText: 'e.g. City, depot, or full address',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: _originCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearchOrigin,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextFormField(
              controller: _destCtrl,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Destination (optional)',
                hintText: 'Stop or delivery point',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: _destCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearchDestination,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SearchableVehicleTypePicker(
              value: _vehicleType,
              labelText: 'Vehicle type (optional)',
              mandatory: false,
              allowClear: true,
              onChanged: (value) => setState(() => _vehicleType = value),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text('Date: ${dateFmt.format(_filterDate)}'),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton(
              onPressed: _loading ? null : () => _runSearch(loadMore: false),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Search'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
              ),
            ),
                ],
              ),
            ),
            if (_results.isNotEmpty)
              SliverToBoxAdapter(
                key: _searchResultsKey,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    '$_total result(s)',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_results.isEmpty && !_loading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error == null
                          ? 'Run a search to see availability'
                          : '',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            if (_results.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i == _results.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          child: Center(
                            child: _loadingMore
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  )
                                : TextButton(
                                    onPressed: () =>
                                        _runSearch(loadMore: true),
                                    child: const Text('Load more'),
                                  ),
                          ),
                        );
                      }
                      final p = _results[i];
                      final own = _isOwnPost(p, auth);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => VehiclePostDetailScreen(
                                      postId: p.id,
                                      initialPost: p,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.routeDisplayLine,
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${p.vehicleType ?? '—'}'
                                      '${p.vehicleNumber != null ? ' · ${p.vehicleNumber}' : ''}',
                                      style: textTheme.bodyMedium,
                                    ),
                                    if (p.transporterCompany != null ||
                                        p.transporterName != null)
                                      Text(
                                        [
                                          if (p.transporterCompany != null)
                                            p.transporterCompany,
                                          if (p.transporterName != null)
                                            p.transporterName,
                                        ].join(' · '),
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    if (p.availableFrom != null ||
                                        p.availableTo != null)
                                      Text(
                                        '${p.availableFrom != null ? dateFmt.format(p.availableFrom!) : ''}'
                                        ' – '
                                        '${p.availableTo != null ? dateFmt.format(p.availableTo!) : ''}',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    if (p.pricePerVehicle != null)
                                      Text(
                                        'From ₹${p.pricePerVehicle}',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap for details',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!own)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          if (p.availableVehicles.isEmpty) {
                                            _showListingNeedsVehiclesSnack(
                                              context,
                                              p,
                                            );
                                            return;
                                          }
                                          _startChat(context, p);
                                        },
                                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                        label: const Text('Chat'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () {
                                          if (p.availableVehicles.isEmpty) {
                                            _showListingNeedsVehiclesSnack(
                                              context,
                                              p,
                                            );
                                            return;
                                          }
                                          _openNegotiate(context, p);
                                        },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.payments_outlined, size: 18),
                                        label: const Text('Negotiate'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                    childCount:
                        _results.length + (_results.length < _total ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceListNegotiateResult {
  const _MarketplaceListNegotiateResult({required this.price, this.message});
  final num price;
  final String? message;
}

class _MarketplaceListNegotiateDialog extends StatefulWidget {
  const _MarketplaceListNegotiateDialog({this.referencePrice});

  final num? referencePrice;

  @override
  State<_MarketplaceListNegotiateDialog> createState() => _MarketplaceListNegotiateDialogState();
}

class _MarketplaceListNegotiateDialogState extends State<_MarketplaceListNegotiateDialog> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _noteCtrl;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final p = num.tryParse(_priceCtrl.text.trim());
    if (p == null || p <= 0) {
      setState(() => _priceError = 'Enter a valid amount');
      return;
    }
    final note = _noteCtrl.text.trim();
    Navigator.pop(
      context,
      _MarketplaceListNegotiateResult(
        price: p,
        message: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listed = widget.referencePrice;
    return AlertDialog(
      title: const Text('Propose price'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (listed != null)
              Text(
                'Listed price: ₹$listed',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Your offer (₹)',
                border: const OutlineInputBorder(),
                errorText: _priceError,
              ),
              onChanged: (_) {
                if (_priceError != null) {
                  setState(() => _priceError = null);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Send offer'),
        ),
      ],
    );
  }
}

class _MarketplaceChatsTab extends StatefulWidget {
  const _MarketplaceChatsTab();

  @override
  State<_MarketplaceChatsTab> createState() => _MarketplaceChatsTabState();
}

class _MarketplaceChatsTabState extends State<_MarketplaceChatsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MarketplaceChatProvider>().loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Consumer<MarketplaceChatProvider>(
      builder: (context, chat, _) {
        if (chat.isLoading && chat.conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (chat.error != null && chat.conversations.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(chat.error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => chat.loadConversations(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (chat.conversations.isEmpty) {
          return Center(
            child: Text(
              'No conversations yet.\nStart from Search — Chat or Negotiate on a listing.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          );
        }
        final auth = context.watch<AuthProvider>().user;
        final self = auth?.transporterId ?? auth?.id ?? '';
        return RefreshIndicator(
          onRefresh: () => chat.loadConversations(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chat.conversations.length,
            itemBuilder: (context, i) {
              final c = chat.conversations[i];
              final peerId = c.counterpartyTransporterId(self);
              final title = [
                if (c.counterpartyCompany != null) c.counterpartyCompany,
                if (c.counterpartyName != null) c.counterpartyName,
              ].whereType<String>().join(' · ');
              final preview = MarketplaceMessage.listPreview(c.lastMessage);
              final route = () {
                final o = c.booking.origin;
                final d = c.booking.destination;
                if ((o == null || o.isEmpty) && (d == null || d.isEmpty)) {
                  return null;
                }
                return '${o ?? '—'} → ${d ?? '—'}';
              }();
              final listTime = c.lastMessage?.createdAt ?? c.lastActivityAt;
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final listDay = DateTime(
                listTime.year,
                listTime.month,
                listTime.day,
              );
              final timeStr = listDay == today
                  ? Helpers.formatTime(listTime)
                  : Helpers.formatDate(listTime);
              final initials = counterpartyChatInitials(
                name: c.counterpartyName,
                company: c.counterpartyCompany,
              );
              return Dismissible(
                key: ValueKey<String>('mchat-${c.booking.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remove from inbox?'),
                      content: const Text(
                        'This chat will disappear from your list. The booking is not cancelled; '
                        'the other party may still have the thread unless you resolve it elsewhere.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                  return ok == true;
                },
                onDismissed: (_) {
                  chat.hideConversation(c.booking.id, actorId: self).catchError((e, _) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                        ),
                      );
                    }
                  });
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Remove',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                child: Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                    foregroundColor: AppColors.primary,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  title: Text(
                    title.isEmpty ? 'Transporter' : title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  isThreeLine: false,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (c.booking.showTripCompleteIndicator) ...[
                        const SizedBox(height: 4),
                        Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 18),
                      ],
                      if (c.unreadCount > 0) ...[
                        const SizedBox(height: 6),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (ctx) => MarketplaceChatScreen(
                          bookingId: c.booking.id,
                          routeLabel: route,
                          counterpartyLabel:
                              title.isEmpty ? 'Transporter' : title,
                          counterpartyTransporterId: peerId,
                        ),
                      ),
                    );
                    if (context.mounted) {
                      chat.loadConversations(silent: true);
                    }
                  },
                ),
              ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MarketplacePostTab extends StatefulWidget {
  const _MarketplacePostTab();

  @override
  State<_MarketplacePostTab> createState() => _MarketplacePostTabState();
}

class _MarketplacePostTabState extends State<_MarketplacePostTab> {
  static const int _kMaxDestinations = 10;

  final _formKey = GlobalKey<FormState>();
  final _originCtrl = TextEditingController();
  final _durationDaysCtrl = TextEditingController(text: '7');
  final _quantityCtrl = TextEditingController(text: '1');
  final _pricePerVehicleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _service = VehiclePostService();

  final List<TextEditingController> _destControllers = [];
  final List<TextEditingController> _destQtyControllers = [];

  String? _vehicleType;
  DateTime _availableFrom = DateTime.now();
  DateTime? _availableTo;
  bool _useEndDate = false;
  final Set<String> _selectedFleetVehicleIds = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<VehicleProvider>().loadVehicles();
      final typeProvider = context.read<VehicleTypeProvider>();
      await typeProvider.ensureLoaded(refresh: true);
      if (!mounted) return;
      if (_vehicleType == null && typeProvider.typeNames.isNotEmpty) {
        setState(() => _vehicleType = typeProvider.typeNames.first);
      }
    });
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    for (final c in _destControllers) {
      c.dispose();
    }
    for (final c in _destQtyControllers) {
      c.dispose();
    }
    _destControllers.clear();
    _destQtyControllers.clear();
    _durationDaysCtrl.dispose();
    _quantityCtrl.dispose();
    _pricePerVehicleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableFrom,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _availableFrom = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableTo ?? _availableFrom.add(const Duration(days: 7)),
      firstDate: _availableFrom,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _availableTo = picked);
  }

  void _addDestField() {
    if (_destControllers.length >= _kMaxDestinations) return;
    setState(() {
      _destControllers.add(TextEditingController());
      _destQtyControllers.add(TextEditingController(text: '1'));
    });
  }

  void _removeDestField(int i) {
    if (i < 0 || i >= _destControllers.length) return;
    setState(() {
      _destControllers[i].dispose();
      _destQtyControllers[i].dispose();
      _destControllers.removeAt(i);
      _destQtyControllers.removeAt(i);
    });
  }

  List<String> _destinationAddresses() {
    return _destControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  int _destinationSlotsTotalPreview() {
    var t = 0;
    for (var i = 0; i < _destControllers.length; i++) {
      if (_destControllers[i].text.trim().isEmpty) continue;
      t += int.tryParse(_destQtyControllers[i].text.trim()) ?? 0;
    }
    return t;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    int? durationDays;
    DateTime? to = _availableTo;

    if (_useEndDate) {
      if (to == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an end date')),
        );
        return;
      }
    } else {
      durationDays = int.tryParse(_durationDaysCtrl.text.trim());
      if (durationDays == null || durationDays < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter duration in days (1 or more)')),
        );
        return;
      }
      to = null;
    }

    if (_originCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter origin')),
      );
      return;
    }
    final destLines = _destinationAddresses();
    if (destLines.length > _kMaxDestinations) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('At most $_kMaxDestinations destinations'),
        ),
      );
      return;
    }

    final fleetCount = _selectedFleetVehicleIds.length;

    late final List<int> destinationQuantities;
    if (destLines.isEmpty) {
      final base = int.tryParse(_quantityCtrl.text.trim());
      if (base == null || base < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter vehicle slots (1 or more)')),
        );
        return;
      }
      destinationQuantities = [math.max(fleetCount, base)];
    } else {
      destinationQuantities = [];
      for (var i = 0; i < _destControllers.length; i++) {
        if (_destControllers[i].text.trim().isEmpty) continue;
        final q = int.tryParse(_destQtyControllers[i].text.trim()) ?? 0;
        destinationQuantities.add(q);
      }
      if (destinationQuantities.length != destLines.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each destination needs a quantity')),
        );
        return;
      }
      if (destinationQuantities.any((q) => q < 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quantities must be non-negative integers'),
          ),
        );
        return;
      }
      final sumSlots = destinationQuantities.fold<int>(0, (a, b) => a + b);
      if (sumSlots < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('At least one destination must have quantity ≥ 1'),
          ),
        );
        return;
      }
      if (fleetCount > sumSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Total slots ($sumSlots) must be at least the number of fleet vehicles selected ($fleetCount).',
            ),
          ),
        );
        return;
      }
    }

    if (_vehicleType == null || _vehicleType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle type')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      VehiclePostModel? created = await _service.create(
        vehicleType: _vehicleType!,
        originAddress: _originCtrl.text.trim(),
        destinationAddresses: destLines,
        destinationQuantities: destinationQuantities,
        availableFrom: _availableFrom,
        availableTo: _useEndDate ? to : null,
        durationDays: _useEndDate ? null : durationDays,
        vehicleId: null,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        pricePerVehicle:
            Validators.parseOptionalListingPriceInr(_pricePerVehicleCtrl.text),
      );
      if (created != null && _selectedFleetVehicleIds.isNotEmpty) {
        final n = created.destinationStopCount;
        final allStops = List<int>.generate(n, (i) => i);
        await _service.addVehicles(
          created.id,
          vehicleIds: _selectedFleetVehicleIds.toList(),
          servedStopIndexes: allStops,
        );
        try {
          created = await _service.fetchById(created.id);
        } catch (_) {}
      }
      if (!mounted) return;
      final isDraftAfter = (created?.isDraftListing ?? false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDraftAfter
                ? 'Listing saved as draft. Add fleet vehicles to publish it to the marketplace.'
                : 'Availability posted.',
          ),
        ),
      );
      if (created != null) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (ctx) => VehiclePostDetailScreen(
              postId: created!.id,
              initialPost: created,
            ),
          ),
        );
      }
      _formKey.currentState!.reset();
      _originCtrl.clear();
      for (final c in _destControllers) {
        c.dispose();
      }
      for (final c in _destQtyControllers) {
        c.dispose();
      }
      _destControllers.clear();
      _destQtyControllers.clear();
      _noteCtrl.clear();
      _pricePerVehicleCtrl.clear();
      _quantityCtrl.text = '1';
      _durationDaysCtrl.text = '7';
      setState(() {
        _availableFrom = DateTime.now();
        _availableTo = null;
        _selectedFleetVehicleIds.clear();
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateFmt = DateFormat.yMMMd();

    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SearchableVehicleTypePicker(
              value: _vehicleType,
              onChanged: (value) {
                setState(() {
                  _vehicleType = value;
                  _selectedFleetVehicleIds.clear();
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _originCtrl,
              decoration: const InputDecoration(
                labelText: 'Origin *',
                hintText: 'e.g. City, depot, or full address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter origin' : null,
            ),
            const SizedBox(height: 16),
            ...List.generate(_destControllers.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _destControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Destination ${i + 1}',
                          hintText: 'Stop or delivery point',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: _destQtyControllers[i],
                        decoration: const InputDecoration(
                          labelText: 'Qty',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: () => _removeDestField(i),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _destControllers.length >= _kMaxDestinations
                    ? null
                    : _addDestField,
                icon: const Icon(Icons.add),
                label: const Text('Add destination'),
              ),
            ),
            if (_destControllers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Total vehicle slots (sum of quantities): ${_destinationSlotsTotalPreview()}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            Consumer<VehicleProvider>(
              builder: (context, vp, _) {
                final vehicles = vp.vehicles
                    .where(
                      (v) =>
                          v.status.toLowerCase() == 'active' &&
                          v.ownerType == 'OWN',
                    )
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fleet vehicles on this listing (optional)',
                      style: textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap one or more of your active owned vehicles. Total slots must be at least this count.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (vehicles.isEmpty)
                      Text(
                        'No active owned vehicles. Add fleets in Vehicles first.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: vehicles.map((v) {
                          final sel = _selectedFleetVehicleIds.contains(v.id);
                          return FilterChip(
                            label: Text(
                              '${v.vehicleNumber}${v.trailerType != null ? ' · ${v.trailerType}' : ''}',
                            ),
                            selected: sel,
                            onSelected: (_) {
                              setState(() {
                                if (sel) {
                                  _selectedFleetVehicleIds.remove(v.id);
                                } else {
                                  _selectedFleetVehicleIds.add(v.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickFrom,
              icon: const Icon(Icons.event, size: 18),
              label: Text('Available from: ${dateFmt.format(_availableFrom)}'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Use specific end date'),
              subtitle: const Text('Otherwise use duration in days'),
              value: _useEndDate,
              onChanged: (v) => setState(() {
                _useEndDate = v;
              }),
            ),
            if (_useEndDate)
              OutlinedButton.icon(
                onPressed: _pickTo,
                icon: const Icon(Icons.event, size: 18),
                label: Text(
                  _availableTo == null
                      ? 'Select end date *'
                      : 'Until: ${dateFmt.format(_availableTo!)}',
                ),
              )
            else
              TextFormField(
                controller: _durationDaysCtrl,
                decoration: const InputDecoration(
                  labelText: 'Duration (days) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            const SizedBox(height: 16),
            if (_destControllers.isEmpty)
              TextFormField(
                controller: _quantityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vehicle slots (total)',
                  helperText: 'Open route — single capacity bucket',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Per-destination Qty is the vehicle quota for that stop. They sum to the listing total.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pricePerVehicleCtrl,
              decoration: const InputDecoration(
                labelText: 'Asking price per vehicle (₹, optional)',
                hintText: 'e.g. 45000',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: Validators.validateOptionalListingPriceInr,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12, right: 12),
              child: Text(
                'You can still negotiate in chat.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Post availability'),
            ),
            const SizedBox(height: 24),
            Text(
              'Posts must match server rules: vehicle type from the list, origin required, and either end date or duration.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyListingsTab extends StatefulWidget {
  const _MyListingsTab();

  @override
  State<_MyListingsTab> createState() => _MyListingsTabState();
}

class _MyListingsTabState extends State<_MyListingsTab> {
  final _service = VehiclePostService();
  bool _loading = true;
  String? _error;
  List<VehiclePostModel> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      if (_items.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final list = await _service.fetchMine();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateFmt = DateFormat.yMMMd();

    if (_loading && _items.isEmpty) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: _items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  if (_error != null)
                    Text(
                      _error!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                      ),
                    )
                  else
                    Text(
                      'You have no listings yet. Use “Post vehicle” to add one.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final p = _items[i];
                  final canEdit = p.isEditableMarketplacePost;
                  final isDraft = p.isDraftListing;
                  final showTerminalStatusChip =
                      p.status != null && !p.isEditableMarketplacePost;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => VehiclePostDetailScreen(
                                  postId: p.id,
                                  initialPost: p,
                                ),
                              ),
                            ).then((_) => _load());
                          },
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.routeDisplayLine,
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (isDraft)
                                      Text(
                                        'DRAFT',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else if (showTerminalStatusChip)
                                      Text(
                                        (p.status ?? '').toUpperCase(),
                                        style: textTheme.labelSmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${p.vehicleType ?? '—'}'
                                  '${p.vehicleNumber != null ? ' · ${p.vehicleNumber}' : ''}',
                                  style: textTheme.bodyMedium,
                                ),
                                if (p.availableFrom != null ||
                                    p.availableTo != null)
                                  Text(
                                    '${p.availableFrom != null ? dateFmt.format(p.availableFrom!) : ''}'
                                    ' – '
                                    '${p.availableTo != null ? dateFmt.format(p.availableTo!) : ''}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap for details',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (canEdit)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Row(
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit listing'),
                                  onPressed: () async {
                                    await Navigator.push<VehiclePostModel>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (ctx) =>
                                            EditVehiclePostScreen(
                                          postId: p.id,
                                          initialPost: p,
                                        ),
                                      ),
                                    );
                                    _load();
                                  },
                                ),
                                TextButton.icon(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: AppColors.error,
                                  ),
                                  label: Text(
                                    'Remove',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Remove listing'),
                                        content: const Text(
                                          'This listing will be removed from the marketplace. '
                                          'Other transporters will no longer see or book it.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text(
                                              'Remove',
                                              style: TextStyle(
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok != true || !context.mounted) {
                                      return;
                                    }
                                    try {
                                      await _service.cancel(p.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Listing removed from marketplace',
                                            ),
                                          ),
                                        );
                                        _load();
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e
                                                  .toString()
                                                  .replaceFirst(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
