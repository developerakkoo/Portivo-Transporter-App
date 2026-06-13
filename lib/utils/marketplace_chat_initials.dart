/// One or two initials for marketplace chat list avatars (counterparty name / company).
String counterpartyChatInitials({String? name, String? company}) {
  final segments = <String>[];
  for (final raw in [company, name]) {
    if (raw == null || raw.trim().isEmpty) continue;
    for (final w in raw.trim().split(RegExp(r'\s+'))) {
      if (w.isEmpty) continue;
      segments.add(w);
      if (segments.length >= 2) break;
    }
    if (segments.length >= 2) break;
  }
  if (segments.isEmpty) return 'T';
  if (segments.length == 1) {
    final s = segments[0];
    if (s.length >= 2) {
      return '${s[0]}${s[1]}'.toUpperCase();
    }
    return s[0].toUpperCase();
  }
  return '${segments[0][0]}${segments[1][0]}'.toUpperCase();
}
