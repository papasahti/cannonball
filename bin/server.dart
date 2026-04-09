import 'dart:io';

import 'package:cannonball/app.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  final app = await buildApplication();
  final ip = InternetAddress.anyIPv4;
  final port = app.config.port;
  final server = await shelf_io.serve(app.handler, ip, port);

  Future<void> shutdown() async {
    await server.close(force: false);
    await app.close();
  }

  ProcessSignal.sigterm.watch().listen((_) async {
    await shutdown();
    exit(0);
  });
  ProcessSignal.sigint.watch().listen((_) async {
    await shutdown();
    exit(0);
  });
}
