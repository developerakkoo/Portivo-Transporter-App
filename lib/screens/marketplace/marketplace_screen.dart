import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/user_feedback.dart';
import '../../utils/error_utils.dart';
import '../../data/models/marketplace_chat_models.dart';
import '../../data/models/vehicle_post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/marketplace_chat_provider.dart';
import '../../providers/navigation_state_provider.dart';
import '../../providers/vehicle_type_provider.dart';
import '../../widgets/main_shell_scope.dart';
import '../../services/socket_service.dart';
import '../../services/vehicle_post_service.dart';
import '../../utils/marketplace_chat_initials.dart';
import '../../widgets/searchable_vehicle_type_picker.dart';
import 'fleet_post_tab.dart';
import 'marketplace_booking_actions.dart';
import 'marketplace_chat_screen.dart';
import 'my_listings_tab.dart';
import 'post_inquiry_screen.dart';
import 'vehicle_post_detail_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int? _handledMarketplaceNonce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MarketplaceChatProvider>().loadConversations(silent: true);
      context.read<VehicleTypeProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inShell = MainShellScope.maybeOf(context) != null;
    return Consumer<NavigationStateProvider>(
      builder: (context, navState, _) {
        final nonce = navState.marketplaceSubTabNonce;
        final pending = navState.pendingMarketplaceSubTab;
        if (pending != null && nonce != _handledMarketplaceNonce) {
          _handledMarketplaceNonce = nonce;
          final target = pending.clamp(0, 3);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _tabController.animateTo(target);
            navState.clearPendingMarketplaceSubTab();
          });
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: !inShell,
            leading: inShell
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Home',
                    onPressed: () => context
                        .read<NavigationStateProvider>()
                        .requestOpenHomeTab(),
                  )
                : null,
            title: const Text('Network'),
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Incoming Inquiries',
                icon: const Icon(Icons.inbox_outlined),
                onPressed: () =>
                    Navigator.pushNamed(context, '/incoming-requirements'),
              ),
              IconButton(
                tooltip: 'My Inquiries',
                icon: const Icon(Icons.campaign_outlined),
                onPressed: () =>
                    Navigator.pushNamed(context, '/my-requirements'),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
          body: TabBarView(
            controller: _tabController,
            children: const [
              _MarketplaceSearchTab(),
              MarketplaceFleetPostTab(),
              MarketplaceMyListingsTab(),
              _MarketplaceChatsTab(),
            ],
          ),
        );
      },
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

  /// Whether a search has been submitted (collapses the form into a summary bar).
  bool _hasSearched = false;

  /// Snapshot of the parameters used for the last submitted search. These drive
  /// the green summary bar and the searched-route highlight so the UI reflects
  /// what was actually searched (not live edits made before tapping Search).
  String? _searchedOrigin;
  String? _searchedDestination;
  String? _searchedVehicleType;
  String _searchedDirection = 'ALL';
  DateTime? _searchedDate;
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

  /// Opens the Post Inquiry form prefilled from the last submitted search.
  Future<void> _openPostInquiry() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => PostInquiryScreen(
          origin: _searchedOrigin ?? _originCtrl.text.trim(),
          destination: _searchedDestination ?? _destCtrl.text.trim(),
          vehicleType: _searchedVehicleType ?? _vehicleType,
          date: _searchedDate ?? _filterDate,
        ),
      ),
    );
    if (created == true && mounted) {
      showUserSuccessSnackBar(
        context,
        'Inquiry posted. Matching transporters will be notified.',
      );
    }
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
          // Snapshot the submitted search so the summary bar + result cards
          // reflect exactly what was searched, and collapse the form.
          _searchedOrigin =
              _originCtrl.text.trim().isEmpty ? null : _originCtrl.text.trim();
          _searchedDestination =
              _destCtrl.text.trim().isEmpty ? null : _destCtrl.text.trim();
          _searchedVehicleType = _vehicleType;
          _searchedDirection = _rateDirection;
          _searchedDate = _filterDate;
          _hasSearched = true;
        }
      });
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

  /// Returns to the search form (pre-filled with the current field values) so
  /// the user can adjust and re-run the search.
  void _editSearch() {
    setState(() => _hasSearched = false);
  }

  bool _isOwnPost(VehiclePostModel p, AuthProvider auth) =>
      marketplaceIsOwnPost(p, auth);

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
            if (!_hasSearched)
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
            if (_hasSearched)
              SliverToBoxAdapter(
                child: _SearchSummaryBar(
                  origin: _searchedOrigin,
                  destination: _searchedDestination,
                  vehicleType: _searchedVehicleType,
                  direction: _searchedDirection,
                  date: _searchedDate,
                  onEdit: _editSearch,
                ),
              ),
            if (_hasSearched && visibleResults.isNotEmpty)
              SliverToBoxAdapter(
                key: _searchResultsKey,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(
                    '$_total result(s) found',
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _hasSearched
                              ? Icons.search_off
                              : Icons.travel_explore,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error != null
                              ? ''
                              : _hasSearched
                                  ? 'No vehicles found for this route.\nPost an inquiry and let transporters quote you.'
                                  : 'Run a search to see availability',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_hasSearched) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openPostInquiry,
                              icon: const Icon(Icons.campaign_outlined),
                              label: const Text('Post Inquiry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _hasSearched = false),
                              icon: const Icon(Icons.tune),
                              label: const Text('Modify Search'),
                            ),
                          ),
                        ],
                      ],
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
                      return _SearchResultCard(
                        post: p,
                        direction: _searchedDirection,
                        searchedOrigin: _searchedOrigin,
                        searchedDestination: _searchedDestination,
                        showActions: !own,
                        onOpenDetails: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (ctx) => VehiclePostDetailScreen(
                                postId: p.id,
                                initialPost: p,
                                searchedOrigin: _searchedOrigin,
                                searchedDestination: _searchedDestination,
                              ),
                            ),
                          );
                        },
                        onChat: () {
                          if (p.availableVehicles.isEmpty) {
                            _showListingNeedsVehiclesSnack(context, p);
                            return;
                          }
                          startMarketplaceChat(
                            context,
                            p,
                            rateDirection: _searchedDirection,
                          );
                        },
                        onOffer: () {
                          if (p.availableVehicles.isEmpty) {
                            _showListingNeedsVehiclesSnack(context, p);
                            return;
                          }
                          openMarketplaceNegotiate(
                            context,
                            p,
                            rateDirection: _searchedDirection,
                          );
                        },
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

/// Green collapsed summary of the submitted search, shown in place of the form
/// after tapping Search. Tapping "Edit Search" reopens the form.
class _SearchSummaryBar extends StatelessWidget {
  const _SearchSummaryBar({
    required this.origin,
    required this.destination,
    required this.vehicleType,
    required this.direction,
    required this.date,
    required this.onEdit,
  });

  final String? origin;
  final String? destination;
  final String? vehicleType;
  final String direction;
  final DateTime? date;
  final VoidCallback onEdit;

  String get _movementLabel {
    switch (direction) {
      case 'EXPORT':
        return 'Export';
      case 'IMPORT':
        return 'Import';
      default:
        return 'Export/Import';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final routeLine = (origin == null && destination == null)
        ? 'All routes'
        : '${origin ?? 'Any origin'}  \u2192  ${destination ?? 'Any destination'}';
    final meta = <String>[
      if (vehicleType != null && vehicleType!.isNotEmpty) vehicleType!,
      _movementLabel,
      if (date != null) DateFormat.yMMMd().format(date!),
    ].join('  \u00b7  ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routeLine,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit Search'),
          ),
        ],
      ),
    );
  }
}

/// A single search result card. Tapping the transporter header opens the
/// listing details screen; Chat / Offer trigger the shared booking actions.
class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.post,
    required this.direction,
    required this.searchedOrigin,
    required this.searchedDestination,
    required this.showActions,
    required this.onOpenDetails,
    required this.onChat,
    required this.onOffer,
  });

  final VehiclePostModel post;
  final String direction;
  final String? searchedOrigin;
  final String? searchedDestination;
  final bool showActions;
  final VoidCallback onOpenDetails;
  final VoidCallback onChat;
  final VoidCallback onOffer;

  String get _displayName =>
      post.transporterCompany ?? post.transporterName ?? 'Transporter';

  String get _initials {
    final source = _displayName.trim();
    if (source.isEmpty) return '?';
    final parts =
        source.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Picks the route best matching the searched destination (falls back to the
  /// first route), then returns a (label, value) pair for [direction].
  ({String label, String value}) _rateFor() {
    MarketplaceRouteRate? route;
    if (post.routes.isNotEmpty) {
      if (searchedDestination != null &&
          searchedDestination!.trim().isNotEmpty) {
        final q = searchedDestination!.toLowerCase();
        route = post.routes.firstWhere(
          (r) => r.destination.toLowerCase().contains(q),
          orElse: () => post.routes.first,
        );
      } else {
        route = post.routes.first;
      }
    }

    final isImport = direction == 'IMPORT';
    final label = isImport ? 'Import Rate' : 'Export Rate';
    num? value;
    if (route != null) {
      value = isImport ? route.importRate : route.exportRate;
      // For the ALL filter, fall back to the other direction if missing.
      if (value == null && direction == 'ALL') {
        value = route.exportRate ?? route.importRate;
      }
    }
    value ??= post.pricePerVehicle;
    return (label: label, value: marketplaceRateText(value));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rate = _rateFor();
    final availableCount = post.availableVehicles.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpenDetails,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: Text(
                      _initials,
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _displayName,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (kMarketplacePlaceholderVerified) ...[
                              const SizedBox(width: 6),
                              const _VerifiedBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              '$kMarketplacePlaceholderRating '
                              '($kMarketplacePlaceholderReviews)',
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '\u00b7 $kMarketplacePlaceholderYears',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.local_shipping_outlined,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    post.vehicleType ?? '—',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(post.routeDisplayLine, style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: availableCount > 0
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Available: $availableCount '
                  '${availableCount == 1 ? 'Vehicle' : 'Vehicles'}',
                  style: textTheme.bodySmall?.copyWith(
                    color: availableCount > 0
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              rate.label,
              style: textTheme.labelSmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  rate.value,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Per Container',
                  style: textTheme.labelSmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            if (showActions) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onChat,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Chat'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onOffer,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Offer'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small green "Verified" pill (placeholder until backend provides the flag).
class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 12, color: AppColors.success),
          const SizedBox(width: 3),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
        ],
      ),
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
