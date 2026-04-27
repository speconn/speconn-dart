class SpeconnError implements Exception {
  static const canceled = 'canceled';
  static const unknown = 'unknown';
  static const invalidArgument = 'invalid_argument';
  static const deadlineExceeded = 'deadline_exceeded';
  static const notFound = 'not_found';
  static const alreadyExists = 'already_exists';
  static const permissionDenied = 'permission_denied';
  static const resourceExhausted = 'resource_exhausted';
  static const failedPrecondition = 'failed_precondition';
  static const aborted = 'aborted';
  static const outOfRange = 'out_of_range';
  static const unimplemented = 'unimplemented';
  static const internal = 'internal';
  static const unavailable = 'unavailable';
  static const dataLoss = 'data_loss';
  static const unauthenticated = 'unauthenticated';

  static const _codeToHttpStatus = <String, int>{
    canceled: 499,
    unknown: 500,
    invalidArgument: 400,
    deadlineExceeded: 504,
    notFound: 404,
    alreadyExists: 409,
    permissionDenied: 403,
    resourceExhausted: 429,
    failedPrecondition: 400,
    aborted: 409,
    outOfRange: 400,
    unimplemented: 501,
    internal: 500,
    unavailable: 503,
    dataLoss: 500,
    unauthenticated: 401,
  };

  final String code;
  final String message;

  SpeconnError(this.code, this.message);

  static int httpStatus(String code) => _codeToHttpStatus[code] ?? 500;

  static String fromHttpStatus(int status) => switch (status) {
        400 => internal,
        401 => unauthenticated,
        403 => permissionDenied,
        404 => unimplemented,
        429 => unavailable,
        502 || 503 || 504 => unavailable,
        _ => unknown,
      };

  @override
  String toString() => 'SpeconnError($code): $message';
}
