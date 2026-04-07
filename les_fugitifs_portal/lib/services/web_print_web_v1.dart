import 'dart:html' as html;

Future<bool> triggerWebPrint() async {
  html.window.print();
  return true;
}
