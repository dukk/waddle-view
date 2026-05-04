/// Constant-time equality for UTF-16 strings (API keys).
bool constantTimeStringEquals(String a, String b) {
  if (a.length != b.length) {
    return false;
  }
  var acc = 0;
  for (var i = 0; i < a.length; i++) {
    acc |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return acc == 0;
}
