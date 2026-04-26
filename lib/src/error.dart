class SpeconnError implements Exception {
  final String code;
  final String message;
  SpeconnError(this.code, this.message);
  @override
  String toString() => 'SpeconnError($code): $message';
}
