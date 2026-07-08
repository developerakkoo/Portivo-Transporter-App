import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/user_feedback.dart';
import '../../utils/error_utils.dart';
import '../../data/models/marketplace_chat_models.dart';
import '../../data/models/vehicle_model.dart';
import '../../data/models/vehicle_post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/marketplace_chat_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/vehicle_type_provider.dart';
import '../../services/socket_service.dart';
import '../../services/vehicle_booking_service.dart';
import '../../services/vehicle_post_service.dart';
import '../../utils/marketplace_chat_initials.dart';
import '../../widgets/searchable_vehicle_type_picker.dart';
import 'edit_vehicle_post_screen.dart';
import 'marketplace_chat_screen.dart';
import 'route_rate_editor.dart';
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
          title: const Text('Network'),
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

  /// Display-only rate direction filter for the results list: 'ALL' / 'EXPORT' / 'IMPORT'.
  String _rateDirection = 'ALL';

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  List<VehiclePostModel> _results = [];
  int _total = 0;
  int _page = 1;
  static const int _pageSize = 20;
  final ScrollController _searchScrollController = ScrollController();
  final GlobalKey _searchResultsKey = GlobalKey();
  final SocketService _socket = SocketService();
  late final void Function(Map<String, dynamic>) _vehiclePostListener;
  late final void Function(Map<String, dynamic>) _bookingConfirmedListener;

  @override
  void initState() {
    super.initState();
    _vehiclePostListener = _onVehiclePostSocket;
    _bookingConfirmedListener = _onBookingConfirmedSocket;
    _socket.addVehiclePostListener(_vehiclePostListener);
    _socket.addMarketplaceBookingLifecycleListener(_bookingConfirmedListener);
  }

  List<VehiclePostModel> _visibleResults(List<VehiclePostModel> results, AuthProvider auth) {
    return results
        .where((p) => _isOwnPost(p, auth) || p.availableVehicles.isNotEmpty)
        .toList();
  }

  void _removePostFromResults(String postId) {
    final before = _results.length;
    _results.removeWhere((p) => p.id == postId);
    if (_results.length < before && _total > 0) {
      _total -= 1;
    }
  }

  void _onVehiclePostSocket(Map<String, dynamic> payload) {
    if (!mounted) return;
    final post = payload['post'];
    if (post is! Map) return;
    final postId = post['id']?.toString() ?? post['_id']?.toString();
    if (postId == null || postId.isEmpty) return;

    final status = post['status']?.toString().toLowerCase();
    final slotsLeft = post['slotsLeft'];
    final inventoryCount = post['bookableInventoryCount'];
    final noInventory = status == 'fulfilled' ||
        (slotsLeft is num && slotsLeft <= 0) ||
        (inventoryCount is num && inventoryCount <= 0);

    if (!noInventory) return;

    setState(() {
      _removePostFromResults(postId);
    });
  }

  void _onBookingConfirmedSocket(Map<String, dynamic> payload) {
    if (!mounted) return;
    final booking = payload['booking'];
    if (booking is! Map) return;
    final postId = booking['postId']?.toString();
    if (postId == null || postId.isEmpty) return;

    setState(() {
      _removePostFromResults(postId);
    });
  }

  @override
  void dispose() {
    _socket.removeVehiclePostListener(_vehiclePostListener);
    _socket.removeMarketplaceBookingLifecycleListener(_bookingConfirmedListener);
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
        _error = ErrorUtils.userMessage(e);
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

  static final NumberFormat _inrCompact = NumberFormat.decimalPattern('en_IN');

  String _rateText(num? rate) =>
      rate == null ? 'Negotiable' : '₹ ${_inrCompact.format(rate)}';

  /// Per-route rate line for a result card, honoring the selected direction filter.
  String _routeRateLine(MarketplaceRouteRate r) {
    switch (_rateDirection) {
      case 'EXPORT':
        return '${r.destination} — Export: ${_rateText(r.exportRate)}';
      case 'IMPORT':
        return '${r.destination} — Import: ${_rateText(r.importRate)}';
      default:
        return '${r.destination} — Exp ${_rateText(r.exportRate)} · Imp ${_rateText(r.importRate)}';
    }
  }

  /// Prompts the buyer to choose a destination route + direction (Export/Import).
  /// Returns null if cancelled. For legacy posts without routes, resolves to a
  /// default catch-all choice without showing UI.
  Future<_RouteDirectionChoice?> _pickRouteDirection(
    BuildContext context,
    VehiclePostModel p,
  ) async {
    final hasRoutes = p.routes.isNotEmpty;
    if (!hasRoutes && !p.acceptsOtherDestinations) {
      return _RouteDirectionChoice(
        routeIndex: -1,
        direction: 'EXPORT',
        rate: p.pricePerVehicle,
        destinationLabel: p.destination ?? 'Route',
      );
    }

    final textTheme = Theme.of(context).textTheme;
    // Honor the search direction filter: only offer the relevant direction(s).
    final showExport = _rateDirection != 'IMPORT';
    final showImport = _rateDirection != 'EXPORT';
    return showModalBottomSheet<_RouteDirectionChoice>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        Widget dirTile(String dest, int routeIndex, String direction, num? rate) {
          return ListTile(
            dense: true,
            leading: Icon(
              direction == 'EXPORT'
                  ? Icons.north_east
                  : Icons.south_west,
              size: 20,
              color: AppColors.primary,
            ),
            title: Text('$direction · ${_rateText(rate)}'),
            onTap: () => Navigator.pop(
              ctx,
              _RouteDirectionChoice(
                routeIndex: routeIndex,
                direction: direction,
                rate: rate,
                destinationLabel: dest,
              ),
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose destination & direction',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(p.routes.length, (i) {
                    final r = p.routes[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            r.destination,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (showExport)
                          dirTile(r.destination, i, 'EXPORT', r.exportRate),
                        if (showImport)
                          dirTile(r.destination, i, 'IMPORT', r.importRate),
                        const Divider(height: 8),
                      ],
                    );
                  }),
                  if (p.acceptsOtherDestinations) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Any Other Destination',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (showExport)
                      dirTile('Any Other Destination', -1, 'EXPORT', null),
                    if (showImport)
                      dirTile('Any Other Destination', -1, 'IMPORT', null),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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
    final choice = await _pickRouteDirection(context, p);
    if (choice == null || !context.mounted) return;
    final assignment = await _pickAssignment(context, p);
    if (assignment == null || !context.mounted) return;
    try {
      final bookingSvc = VehicleBookingService();
      final bookingMap = await bookingSvc.createOrGetBooking(
        postId: p.id,
        assignmentId: assignment.id,
        direction: choice.direction,
        routeIndex: choice.routeIndex,
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
      showUserErrorSnackBar(context, e);
    }
  }

  Future<void> _openNegotiate(BuildContext context, VehiclePostModel p) async {
    final auth = context.read<AuthProvider>();
    if (_isOwnPost(p, auth)) return;
    final choice = await _pickRouteDirection(context, p);
    if (choice == null || !context.mounted) return;
    final assignment = await _pickAssignment(context, p);
    if (assignment == null || !context.mounted) return;
    final listed = choice.rate ?? assignment.price ?? p.pricePerVehicle;
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
        direction: choice.direction,
        routeIndex: choice.routeIndex,
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
      showUserErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateFmt = DateFormat.yMMMd();
    final auth = context.watch<AuthProvider>();
    final visibleResults = _visibleResults(_results, auth);

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
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ALL', label: Text('All')),
                  ButtonSegment(value: 'EXPORT', label: Text('Export')),
                  ButtonSegment(value: 'IMPORT', label: Text('Import')),
                ],
                selected: {_rateDirection},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => _rateDirection = selection.first);
                },
              ),
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
            if (visibleResults.isNotEmpty)
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
            if (_results.isEmpty && visibleResults.isEmpty && !_loading)
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
            if (visibleResults.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i == visibleResults.length) {
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
                      final p = visibleResults[i];
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
                                    if (p.routes.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: p.routes
                                              .take(3)
                                              .map(
                                                (r) => Text(
                                                  _routeRateLine(r),
                                                  style: textTheme.labelSmall
                                                      ?.copyWith(
                                                    color: AppColors
                                                        .textSecondary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    if (p.acceptsOtherDestinations)
                                      Text(
                                        'Any other destination · Negotiable',
                                        style: textTheme.labelSmall?.copyWith(
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
                        visibleResults.length + (_results.length < _total ? 1 : 0),
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
                      showUserErrorSnackBar(context, e);
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

/// Buyer's chosen destination route + direction for a booking.
class _RouteDirectionChoice {
  const _RouteDirectionChoice({
    required this.routeIndex,
    required this.direction,
    required this.rate,
    required this.destinationLabel,
  });

  final int routeIndex;
  final String direction;
  final num? rate;
  final String destinationLabel;
}

class _MarketplacePostTab extends StatefulWidget {
  const _MarketplacePostTab();

  @override
  State<_MarketplacePostTab> createState() => _MarketplacePostTabState();
}

class _MarketplacePostTabState extends State<_MarketplacePostTab> {
  static const int _kDefaultDurationDays = 30;

  final _formKey = GlobalKey<FormState>();
  final _originCtrl = TextEditingController();
  final _service = VehiclePostService();

  String? _vehicleType;
  DateTime _availableFrom = DateTime.now();
  int _availableVehicles = 1;
  final List<RouteDraft> _routes = [];
  bool _acceptsOtherDestinations = false;
  final Set<String> _selectedFleetVehicleIds = {};
  bool _submitting = false;

  static final NumberFormat _inrFmt = NumberFormat.decimalPattern('en_IN');

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

  String _rateLabel(num? rate) =>
      rate == null ? 'Negotiable' : '₹ ${_inrFmt.format(rate)}';

  Future<void> _addOrEditRoute({int? index}) async {
    final existing = index == null ? null : _routes[index];
    final result = await showRouteRateEditor(context, initial: existing);
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _routes.add(result);
      } else {
        _routes[index] = result;
      }
    });
  }

  void _removeRoute(int index) {
    setState(() => _routes.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_vehicleType == null || _vehicleType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle type')),
      );
      return;
    }
    if (_originCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your current location')),
      );
      return;
    }
    if (_availableVehicles < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Available vehicles must be at least 1')),
      );
      return;
    }
    if (_routes.isEmpty && !_acceptsOtherDestinations) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one route or enable "Any Other Destination"',
          ),
        ),
      );
      return;
    }
    final fleetCount = _selectedFleetVehicleIds.length;
    if (fleetCount > _availableVehicles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Available vehicles ($_availableVehicles) must be at least the fleet vehicles selected ($fleetCount).',
          ),
        ),
      );
      return;
    }

    final routes = _routes
        .map(
          (r) => MarketplaceRouteRate(
            destination: r.destination,
            exportRate: r.exportRate,
            importRate: r.importRate,
          ),
        )
        .toList();

    setState(() => _submitting = true);
    try {
      VehiclePostModel? created = await _service.create(
        vehicleType: _vehicleType!,
        originAddress: _originCtrl.text.trim(),
        availableFrom: _availableFrom,
        durationDays: _kDefaultDurationDays,
        quantity: _availableVehicles,
        routes: routes,
        acceptsOtherDestinations: _acceptsOtherDestinations,
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
                ? 'Availability saved. Attach a fleet vehicle to publish it to the marketplace.'
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
      setState(() {
        _availableFrom = DateTime.now();
        _availableVehicles = 1;
        _routes.clear();
        _acceptsOtherDestinations = false;
        _selectedFleetVehicleIds.clear();
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showUserErrorSnackBar(context, e, fallback: 'Failed to create listing');
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
            Text(
              'Post Availability',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'List your available vehicles and the routes you serve with your rates.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Vehicle type at the very top.
            SearchableVehicleTypePicker(
              value: _vehicleType,
              onChanged: (value) {
                setState(() {
                  _vehicleType = value;
                  _selectedFleetVehicleIds.clear();
                });
              },
            ),
            const SizedBox(height: 20),

            // 1. Basic Details
            _sectionCard(
              context,
              title: '1. Basic Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Vehicles', style: textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _availableVehiclesStepper(context),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _originCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Current Location *',
                      hintText: 'e.g. City, depot, or full address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.my_location_outlined),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your current location'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickFrom,
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(
                      'Available from: ${dateFmt.format(_availableFrom)}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Preferred Routes & Rates
            Row(
              children: [
                Expanded(
                  child: Text(
                    '2. Preferred Routes & Rates',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addOrEditRoute(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Route'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_routes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.dividerGrey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No routes yet. Tap "Add Route" to set a destination with Export / Import rates.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ...List.generate(_routes.length, (i) => _routeCard(context, i)),
            const SizedBox(height: 12),

            // Negotiable "Any Other Destination" catch-all.
            _otherDestinationRow(context),
            const SizedBox(height: 20),

            // Optional fleet vehicles (publishes the listing on the marketplace).
            _fleetSection(context),
            const SizedBox(height: 20),

            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Buyers pick a route and direction (Export/Import) when they contact you. Rates left as "Negotiable" are shown as Rate on Request.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                  : const Text('Post Availability'),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user_outlined,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Only verified transporters will see your post',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dividerGrey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _availableVehiclesStepper(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton.outlined(
          onPressed: _availableVehicles > 1
              ? () => setState(() => _availableVehicles--)
              : null,
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '$_availableVehicles',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton.outlined(
          onPressed: () => setState(() => _availableVehicles++),
          icon: const Icon(Icons.add),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'vehicles available in this pool',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _routeCard(BuildContext context, int index) {
    final textTheme = Theme.of(context).textTheme;
    final r = _routes[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dividerGrey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.destination,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _addOrEditRoute(index: index);
                  } else if (value == 'remove') {
                    _removeRoute(index);
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _rateChip(
                  context,
                  label: 'Export',
                  value: _rateLabel(r.exportRate),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _rateChip(
                  context,
                  label: 'Import',
                  value: _rateLabel(r.importRate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rateChip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _otherDestinationRow(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dividerGrey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        value: _acceptsOtherDestinations,
        onChanged: (v) => setState(() => _acceptsOtherDestinations = v),
        title: const Text('Any Other Destination'),
        subtitle: Text(
          'Rate on Request — accept inquiries for unlisted routes (Negotiable).',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// A vehicle can be attached when it matches the chosen listing type, or when
  /// it has no type set (untyped vehicles are assignable to any listing).
  bool _vehicleMatchesSelectedType(VehicleModel v, String? selectedType) {
    if (selectedType == null || selectedType.isEmpty) return true;
    final vt = v.vehicleType?.trim();
    if (vt == null || vt.isEmpty) return true;
    return vt == selectedType;
  }

  Widget _fleetSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedType = _vehicleType?.trim();
    return Consumer<VehicleProvider>(
      builder: (context, vp, _) {
        final vehicles = vp.vehicles
            .where(
              (v) =>
                  v.status.toLowerCase() == 'active' &&
                  v.ownerType == 'OWN' &&
                  _vehicleMatchesSelectedType(v, selectedType),
            )
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attach fleet vehicles (optional)',
              style: textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Attaching an active owned vehicle publishes this listing to the marketplace immediately.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            if (vehicles.isEmpty)
              Text(
                (selectedType == null || selectedType.isEmpty)
                    ? 'No active owned vehicles. Add fleets in Vehicles first.'
                    : 'No active owned "$selectedType" vehicles. Add one in Vehicles or change the vehicle type.',
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
        _error = ErrorUtils.userMessage(e);
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
