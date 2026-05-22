// Conditional export to choose platform implementation
export 'platform_file_io.dart' if (dart.library.html) 'platform_file_web.dart';
