import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

Future<void> downloadFileFromUrl(String url, String filename) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$filename';
  await Dio().download(url, path);
  // On native, file is saved to temp dir — caller can open it
}
