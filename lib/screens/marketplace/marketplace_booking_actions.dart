import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/user_feedback.dart';
import '../../data/models/vehicle_post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/marketplace_chat_provider.dart';
import '../../services/vehicle_booking_service.dart';
import 'marketplace_chat_screen.dart';

/// Shared Chat / Offer (negotiate) booking actions and placeholder constants for
/// marketplace listings. Reused by the search result cards
/// ([_SearchResultCard]) and the listing details screen
/// ([VehiclePostDetailScreen]) so the booking flow stays in one place.

// ---------------------------------------------------------------------------
// Placeholder constants
//
// The marketplace mockup shows richer transporter fields (verified badge, star
// rating, years-with-Porttivo, fleet size, response time, base location) that
// are not yet returned by the backend. Until those exist, we render these
// static placeholder values. Swapping to real data later only requires wiring
// the model fields — the layouts already reference these constants.
// ---------------------------------------------------------------------------

const bool kMarketplacePlaceholderVerified = true;
const double kMarketplacePlaceholderRating = 3.8;
const int kMarketplacePlaceholderReviews = 128;
const String kMarketplacePlaceholderYears = '3 Years with Porttivo';
const int kMarketplacePlaceholderFleetSize = 25;
const String kMarketplacePlaceholderBaseLocation = 'Navi Mumbai, Maharashtra';
const String kMarketplacePlaceholderResponse = 'Usually responds in 15 min';

final NumberFormat _inrCompact = NumberFormat.decimalPattern('en_IN');

/// Formats a rate for display; `null` => "Negotiable".
String marketplaceRateText(num? rate) =>
    rate == null ? 'Negotiable' : '₹ ${_inrCompact.format(rate)}';

/// Whether the given post belongs to the signed-in transporter.
bool marketplaceIsOwnPost(VehiclePostModel p, AuthProvider auth) {
  final u = auth.user;
  if (u == null || p.transporterId == null) return false;
  final self = u.transporterId ?? u.id;
  return p.transporterId == self;
}

/// Buyer's choice of destination route + direction (Export/Import).
class MarketplaceRouteDirectionChoice {
  const MarketplaceRouteDirectionChoice({
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

/// Prompts the buyer to choose a destination route + direction (Export/Import).
/// Returns null if cancelled. For legacy posts without routes, resolves to a
/// default catch-all choice without showing UI. [rateDirection] is the search
/// filter ('ALL'/'EXPORT'/'IMPORT') and constrains the offered directions.
Future<MarketplaceRouteDirectionChoice?> marketplacePickRouteDirection(
  BuildContext context,
  VehiclePostModel p, {
  String rateDirection = 'ALL',
}) async {
  final hasRoutes = p.routes.isNotEmpty;
  if (!hasRoutes && !p.acceptsOtherDestinations) {
    return MarketplaceRouteDirectionChoice(
      routeIndex: -1,
      direction: 'EXPORT',
      rate: p.pricePerVehicle,
      destinationLabel: p.destination ?? 'Route',
    );
  }

  final textTheme = Theme.of(context).textTheme;
  // Honor the search direction filter: only offer the relevant direction(s).
  final showExport = rateDirection != 'IMPORT';
  final showImport = rateDirection != 'EXPORT';
  return showModalBottomSheet<MarketplaceRouteDirectionChoice>(
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
            direction == 'EXPORT' ? Icons.north_east : Icons.south_west,
            size: 20,
            color: AppColors.primary,
          ),
          title: Text('$direction · ${marketplaceRateText(rate)}'),
          onTap: () => Navigator.pop(
            ctx,
            MarketplaceRouteDirectionChoice(
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

/// Prompts the buyer to pick which fleet vehicle slot to book.
Future<VehiclePostAssignment?> marketplacePickAssignment(
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

/// Starts (or resumes) a booking chat with the listing's transporter.
Future<void> startMarketplaceChat(
  BuildContext context,
  VehiclePostModel p, {
  String rateDirection = 'ALL',
}) async {
  final auth = context.read<AuthProvider>();
  if (marketplaceIsOwnPost(p, auth)) return;
  final choice = await marketplacePickRouteDirection(
    context,
    p,
    rateDirection: rateDirection,
  );
  if (choice == null || !context.mounted) return;
  final assignment = await marketplacePickAssignment(context, p);
  if (assignment == null || !context.mounted) return;
  try {
    final bookingSvc = VehicleBookingService();
    final bookingMap = await bookingSvc.createOrGetBooking(
      postId: p.id,
      assignmentId: assignment.id,
      direction: choice.direction,
      routeIndex: choice.routeIndex,
    );
    final bookingId =
        bookingMap['id']?.toString() ?? bookingMap['_id']?.toString();
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

/// Opens the "send offer" flow (pick route/direction/vehicle, then propose a
/// price) for the listing's transporter.
Future<void> openMarketplaceNegotiate(
  BuildContext context,
  VehiclePostModel p, {
  String rateDirection = 'ALL',
}) async {
  final auth = context.read<AuthProvider>();
  if (marketplaceIsOwnPost(p, auth)) return;
  final choice = await marketplacePickRouteDirection(
    context,
    p,
    rateDirection: rateDirection,
  );
  if (choice == null || !context.mounted) return;
  final assignment = await marketplacePickAssignment(context, p);
  if (assignment == null || !context.mounted) return;
  final listed = choice.rate ?? assignment.price ?? p.pricePerVehicle;
  final result = await showDialog<MarketplaceNegotiateResult>(
    context: context,
    builder: (ctx) => MarketplaceNegotiateDialog(referencePrice: listed),
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
    final bookingId =
        bookingMap['id']?.toString() ?? bookingMap['_id']?.toString();
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

class MarketplaceNegotiateResult {
  const MarketplaceNegotiateResult({required this.price, this.message});
  final num price;
  final String? message;
}

class MarketplaceNegotiateDialog extends StatefulWidget {
  const MarketplaceNegotiateDialog({super.key, this.referencePrice});

  final num? referencePrice;

  @override
  State<MarketplaceNegotiateDialog> createState() =>
      _MarketplaceNegotiateDialogState();
}

class _MarketplaceNegotiateDialogState
    extends State<MarketplaceNegotiateDialog> {
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
      MarketplaceNegotiateResult(
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
