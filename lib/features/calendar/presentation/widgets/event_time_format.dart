/// Strips seconds from a "HH:mm:ss" time string, returning "HH:mm".
/// Passes through strings that are already "HH:mm".
///
/// Shared across calendar tiles so the dashboard card and the kalender views
/// render the same time format without duplicating the split.
String formatEventTime(String time) {
  final parts = time.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return time;
}
