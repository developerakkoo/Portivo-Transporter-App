import 'package:flutter/foundation.dart';

/// Utility class for safe JSON parsing that handles populated objects,
/// nested structures, and inconsistent response formats from the API.
class JsonParser {
  /// Safely extract ID from a value that can be:
  /// - A string (direct ID)
  /// - A populated object with _id or id field
  /// - null
  /// Returns null if value is null or cannot be extracted
  static String? extractId(dynamic value) {
    if (value == null) return null;
    
    if (value is String) {
      return value.isEmpty ? null : value;
    }
    
    if (value is Map) {
      // Handle populated objects - try _id first, then id
      final id = value['_id'] ?? value['id'];
      if (id != null) {
        return id.toString();
      }
      // If no id field, return null
      return null;
    }
    
    // Handle ObjectId objects and other types
    try {
      return value.toString();
    } catch (e) {
      if (kDebugMode) {
        print('JsonParser: Error extracting ID from $value: $e');
      }
      return null;
    }
  }

  /// Safely extract a string value from dynamic input
  /// Returns defaultValue if value is null or cannot be converted
  static String extractString(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;
    
    if (value is String) {
      return value;
    }
    
    if (value is Map) {
      // If it's a Map, try to extract ID first (for populated objects)
      final id = value['_id'] ?? value['id'];
      if (id != null) {
        return id.toString();
      }
      // If no id, convert to string representation
      return value.toString();
    }
    
    try {
      return value.toString();
    } catch (e) {
      if (kDebugMode) {
        print('JsonParser: Error extracting string from $value: $e');
      }
      return defaultValue;
    }
  }

  /// Safely extract a list from dynamic input
  /// Returns empty list if value is null or not a list
  static List<T> extractList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (value == null) return [];
    
    if (value is List) {
      try {
        return value
            .where((item) => item != null && item is Map)
            .map((item) => parser(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        if (kDebugMode) {
          print('JsonParser: Error parsing list: $e');
        }
        return [];
      }
    }
    
    return [];
  }

  /// Extract URL from a document object that can be:
  /// - A string (direct URL)
  /// - An object with url field: {url: "...", expiryDate: "...", uploadedAt: "..."}
  /// - null
  static String? extractDocumentUrl(dynamic value) {
    if (value == null) return null;
    
    if (value is String) {
      return value.isEmpty ? null : value;
    }
    
    if (value is Map) {
      final url = value['url'];
      if (url != null) {
        return url.toString();
      }
      return null;
    }
    
    return null;
  }

  /// Extract document info (URL and expiry date) from a document object
  static DocumentInfo? extractDocumentInfo(dynamic value) {
    if (value == null) return null;
    
    if (value is String) {
      return DocumentInfo(url: value.isEmpty ? null : value);
    }
    
    if (value is Map) {
      String? url;
      DateTime? expiryDate;
      DateTime? uploadedAt;
      
      if (value['url'] != null) {
        url = value['url'].toString();
      }
      
      if (value['expiryDate'] != null) {
        try {
          expiryDate = DateTime.tryParse(value['expiryDate'].toString());
        } catch (e) {
          if (kDebugMode) {
            print('JsonParser: Error parsing expiryDate: $e');
          }
        }
      }
      
      if (value['uploadedAt'] != null) {
        try {
          uploadedAt = DateTime.tryParse(value['uploadedAt'].toString());
        } catch (e) {
          if (kDebugMode) {
            print('JsonParser: Error parsing uploadedAt: $e');
          }
        }
      }
      
      return DocumentInfo(
        url: url,
        expiryDate: expiryDate,
        uploadedAt: uploadedAt,
      );
    }
    
    return null;
  }

  /// Safely extract a double value from dynamic input
  static double extractDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    
    return defaultValue;
  }

  /// Safely extract an int value from dynamic input
  static int extractInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    
    return defaultValue;
  }

  /// Safely extract a boolean value from dynamic input
  static bool extractBool(dynamic value, bool defaultValue) {
    if (value == null) return defaultValue;
    
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    if (value is int) {
      return value != 0;
    }
    
    return defaultValue;
  }

  /// Safely extract a DateTime from dynamic input
  static DateTime? extractDateTime(dynamic value) {
    if (value == null) return null;
    
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        if (kDebugMode) {
          print('JsonParser: Error parsing DateTime from string: $e');
        }
        return null;
      }
    }
    
    return null;
  }

  /// Extract a list of IDs from a list that can contain strings or objects
  static List<String> extractIdList(dynamic value) {
    if (value == null) return [];
    
    if (value is List) {
      return value
          .map((item) => extractId(item))
          .where((id) => id != null)
          .cast<String>()
          .toList();
    }
    
    return [];
  }
}

/// Represents document information with URL and optional metadata
class DocumentInfo {
  final String? url;
  final DateTime? expiryDate;
  final DateTime? uploadedAt;

  DocumentInfo({
    this.url,
    this.expiryDate,
    this.uploadedAt,
  });

  bool get hasUrl => url != null && url!.isNotEmpty;
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }
}
