import 'dart:developer' as developer;

void logApp(String message, {String level = 'INFO'}) {
  final msg = '[MYAPP_LOG] $message';
  developer.log(msg, name: 'intenebrisuno', level: level == 'ERROR' ? 1000 : 800);
}