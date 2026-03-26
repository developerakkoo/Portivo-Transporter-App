/// Resolves stored upload paths (e.g. `/uploads/milestones/...`) for [Image.network].
/// Strips trailing `/api` from [apiUrl] to get the static file origin.
/// Already-absolute http(s) URLs are returned unchanged.
String resolveUploadUrl(String apiUrl, String? path) {
  if (path == null || path.isEmpty) return '';
  final trimmed = path.trim();
  if (trimmed.isEmpty) return '';
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return trimmed;
  }
  var base = apiUrl.replaceFirst(RegExp(r'/api/?$'), '');
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  final segment = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  return '$base$segment';
}
