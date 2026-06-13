/// Server: [CLOSED_WITH_POD, CLOSED_WITHOUT_POD] — trip finished for marketplace badge.
const Set<String> kMarketplaceClosedTripStatuses = {
  'CLOSED_WITH_POD',
  'CLOSED_WITHOUT_POD',
};

/// Single attachment on a chat message (REST + socket).
class MarketplaceAttachment {
  MarketplaceAttachment({
    required this.url,
    this.mimeType,
    this.originalName,
    this.sizeBytes,
  });

  final String url;
  final String? mimeType;
  final String? originalName;
  final int? sizeBytes;

  bool get isImage {
    final m = mimeType?.toLowerCase() ?? '';
    if (m.startsWith('image/')) return true;
    final u = url.toLowerCase();
    return u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.png') ||
        u.endsWith('.webp');
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        if (mimeType != null) 'mimeType': mimeType,
        if (originalName != null) 'originalName': originalName,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
      };

  static MarketplaceAttachment? fromJson(dynamic item) {
    if (item is String && item.trim().isNotEmpty) {
      return MarketplaceAttachment(
        url: item.trim(),
        mimeType: 'application/octet-stream',
      );
    }
    if (item is Map) {
      final m = Map<String, dynamic>.from(
        item.map((k, v) => MapEntry(k.toString(), v)),
      );
      final u = m['url']?.toString();
      if (u == null || u.isEmpty) return null;
      return MarketplaceAttachment(
        url: u,
        mimeType: m['mimeType']?.toString(),
        originalName: m['originalName']?.toString(),
        sizeBytes: m['sizeBytes'] is int
            ? m['sizeBytes'] as int
            : int.tryParse('${m['sizeBytes']}'),
      );
    }
    return null;
  }

  Map<String, dynamic> toSendMap() => {
        'url': url,
        'mimeType': mimeType ?? 'application/octet-stream',
        if (originalName != null) 'originalName': originalName,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
      };
}

/// Message in a transporter-to-transporter booking thread.
class MarketplaceMessage {
  MarketplaceMessage({
    required this.id,
    required this.bookingId,
    required this.content,
    this.messageType,
    this.proposedPrice,
    this.status,
    this.readAt,
    this.createdAt,
    this.senderId,
    this.senderName,
    this.receiverId,
    this.attachments = const [],
  });

  final String id;
  final String bookingId;
  final String content;
  final String? messageType;
  final num? proposedPrice;
  final String? status;
  final DateTime? readAt;
  final DateTime? createdAt;
  final String? senderId;
  final String? senderName;
  /// Transporter id of the intended recipient (for server mark-read validation).
  final String? receiverId;
  final List<MarketplaceAttachment> attachments;

  bool get isRead => status?.toUpperCase() == 'READ';

  /// Subtitle text for chat list rows (matches server notification preview style).
  static String listPreview(MarketplaceMessage? m) {
    if (m == null) return 'No messages yet';
    final t = m.messageType?.toUpperCase();
    if (t == 'PRICE_PROPOSAL' && m.proposedPrice != null) {
      return 'Proposed ₹${m.proposedPrice}';
    }
    if (t == 'ATTACHMENT' || m.attachments.isNotEmpty) {
      final n = m.attachments.length;
      if (n > 1) return '$n attachments';
      return 'Attachment';
    }
    final c = m.content.trim();
    return c.isEmpty ? 'No messages yet' : c;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookingId': bookingId,
        'content': content,
        if (messageType != null) 'messageType': messageType,
        if (proposedPrice != null) 'proposedPrice': proposedPrice,
        if (status != null) 'status': status,
        if (readAt != null) 'readAt': readAt!.toUtc().toIso8601String(),
        if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
        if (senderId != null) 'senderId': senderId,
        if (senderName != null) 'senderName': senderName,
        if (receiverId != null) 'receiverId': receiverId,
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
      };

  static String? _idOf(dynamic v) {
    if (v == null) return null;
    if (v is Map) return v['id']?.toString() ?? v['_id']?.toString();
    return v.toString();
  }

  static List<MarketplaceAttachment> _attachmentsFromJson(dynamic raw) {
    if (raw is! List) return [];
    final out = <MarketplaceAttachment>[];
    for (final item in raw) {
      final a = MarketplaceAttachment.fromJson(item);
      if (a != null) out.add(a);
    }
    return out;
  }

  static MarketplaceMessage? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString() ?? json['_id']?.toString();
    if (id == null || id.isEmpty) return null;
    final bidRaw = json['bookingId'];
    final bid = bidRaw is Map
        ? bidRaw['_id']?.toString() ?? bidRaw['id']?.toString()
        : bidRaw?.toString();
    if (bid == null || bid.isEmpty) return null;
    Map<String, dynamic>? s;
    final sr = json['senderId'];
    if (sr is Map) s = Map<String, dynamic>.from(sr);
    final rr = json['receiverId'];
    return MarketplaceMessage(
      id: id,
      bookingId: bid,
      content: json['content']?.toString() ?? '',
      messageType: json['messageType']?.toString(),
      proposedPrice: json['proposedPrice'] is num
          ? json['proposedPrice'] as num
          : num.tryParse('${json['proposedPrice']}'),
      status: json['status']?.toString(),
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'].toString()) : null,
      createdAt:
          json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      senderId: _idOf(sr),
      senderName: s?['name']?.toString(),
      receiverId: _idOf(rr),
      attachments: _attachmentsFromJson(json['attachments']),
    );
  }
}

/// Lean booking for chat context (from API).
class MarketplaceBooking {
  MarketplaceBooking({
    required this.id,
    this.status,
    this.buyerId,
    this.sellerId,
    this.estimatedPrice,
    this.agreedPrice,
    this.origin,
    this.destination,
    this.vehicleNumber,
    this.vehicleType,
    this.linkedTrip,
  });

  final String id;
  final String? status;
  final String? buyerId;
  final String? sellerId;
  final num? estimatedPrice;
  final num? agreedPrice;
  final String? origin;
  final String? destination;
  final String? vehicleNumber;
  final String? vehicleType;
  /// Populated `tripId` from API (`status`, `closedAt`, …).
  final Map<String, dynamic>? linkedTrip;

  /// Trip finished for UI (booking row COMPLETED or linked trip in a closed terminal status).
  bool get showTripCompleteIndicator {
    final bs = status?.toUpperCase() ?? '';
    if (bs == 'COMPLETED') return true;
    final ts = linkedTrip?['status']?.toString().toUpperCase() ?? '';
    return kMarketplaceClosedTripStatuses.contains(ts);
  }

  static String? _locationLabel(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? null : s;
    }
    if (v is Map) {
      final fa = v['formattedAddress']?.toString().trim();
      if (fa != null && fa.isNotEmpty) return fa;
      final addr = v['address']?.toString().trim();
      if (addr != null && addr.isNotEmpty) return addr;
      final desc = v['description']?.toString().trim();
      if (desc != null && desc.isNotEmpty) return desc;
      final coords = v['coordinates'];
      if (coords is List && coords.length >= 2) {
        final lng = coords[0];
        final lat = coords[1];
        return '$lat, $lng';
      }
    }
    return null;
  }

  static MarketplaceBooking? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString() ?? json['_id']?.toString();
    if (id == null || id.isEmpty) return null;
    String? buyer;
    final b = json['buyerId'];
    if (b is Map) {
      buyer = b['_id']?.toString() ?? b['id']?.toString();
    } else {
      buyer = b?.toString();
    }
    String? seller;
    final se = json['sellerId'];
    if (se is Map) {
      seller = se['_id']?.toString() ?? se['id']?.toString();
    } else {
      seller = se?.toString();
    }
    String? vnum;
    String? vtype;
    final v = json['vehicleId'];
    if (v is Map) {
      vnum = v['vehicleNumber']?.toString();
      vtype = v['vehicleType']?.toString();
    }
    String? origin;
    String? dest;
    final p = json['postId'];
    if (p is Map) {
      origin = _locationLabel(p['origin']) ?? p['originLabel']?.toString();
      dest = _locationLabel(p['destination']) ??
          p['destinationLabel']?.toString();
    }

    Map<String, dynamic>? linked;
    final t = json['tripId'];
    if (t is Map) {
      linked = Map<String, dynamic>.from(
        t.map((k, v) => MapEntry(k.toString(), v)),
      );
    }

    return MarketplaceBooking(
      id: id,
      status: json['status']?.toString(),
      buyerId: buyer,
      sellerId: seller,
      estimatedPrice: json['estimatedPrice'] is num
          ? json['estimatedPrice'] as num
          : num.tryParse('${json['estimatedPrice']}'),
      agreedPrice: json['agreedPrice'] is num
          ? json['agreedPrice'] as num
          : num.tryParse('${json['agreedPrice']}'),
      origin: origin,
      destination: dest,
      vehicleNumber: vnum,
      vehicleType: vtype,
      linkedTrip: linked,
    );
  }
}

/// One row in the marketplace Chats list.
class MarketplaceConversation {
  MarketplaceConversation({
    required this.booking,
    this.lastMessage,
    this.unreadCount = 0,
    this.counterpartyName,
    this.counterpartyCompany,
    required this.lastActivityAt,
  });

  final MarketplaceBooking booking;
  final MarketplaceMessage? lastMessage;
  final int unreadCount;
  final String? counterpartyName;
  final String? counterpartyCompany;
  final DateTime lastActivityAt;

  /// Other transporter in this thread (requires [selfId] = transporter or company scope id).
  String? counterpartyTransporterId(String selfId) {
    if (booking.buyerId == selfId) return booking.sellerId;
    if (booking.sellerId == selfId) return booking.buyerId;
    return null;
  }

  static MarketplaceConversation? fromJson(Map<String, dynamic> json) {
    final b = json['booking'];
    if (b is! Map) return null;
    final booking = MarketplaceBooking.fromJson(Map<String, dynamic>.from(b));
    if (booking == null) return null;
    MarketplaceMessage? lm;
    final l = json['lastMessage'];
    if (l is Map) lm = MarketplaceMessage.fromJson(Map<String, dynamic>.from(l));
    final cp = json['counterparty'];
    String? cpName;
    String? cpCompany;
    if (cp is Map) {
      cpName = cp['name']?.toString();
      cpCompany = cp['company']?.toString();
    }
    final la = json['lastActivityAt'];
    final lastActivityAt = la != null
        ? DateTime.tryParse(la.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.fromMillisecondsSinceEpoch(0);
    final ur = json['unreadCount'];
    final unread = ur is num ? ur.toInt() : int.tryParse('$ur') ?? 0;
    return MarketplaceConversation(
      booking: booking,
      lastMessage: lm,
      unreadCount: unread,
      counterpartyName: cpName,
      counterpartyCompany: cpCompany,
      lastActivityAt: lastActivityAt,
    );
  }
}
