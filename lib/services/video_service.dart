import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class VideoService {
  static Future<File> downloadVideo(String url, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');

    if (await file.exists()) {
      return file;
    }

    final response = await http.get(Uri.parse(url));
    await file.writeAsBytes(response.bodyBytes);

    return file;
  }
}