import 'dart:io';
import 'package:image/image.dart' as img;

/// Exporta el logo horizontal a formato de launcher sin deformar la ilustración.
Future<void> main() async {
  final app = File.fromUri(Platform.script).parent.parent;
  final source = File('${app.path}/assets/images/logo_app_new.png');
  final image = img.decodeImage(await source.readAsBytes());
  if (image == null) throw StateError('El logotipo no se puede decodificar.');
  final icon = img.copyResizeCropSquare(image, size: 1024);
  final target = File('${app.path}/assets/branding/launcher_icon.png');
  await target.parent.create(recursive: true);
  await target.writeAsBytes(img.encodePng(icon));
  stdout.writeln('Logo exportado a formato cuadrado, sin estirar el dibujo.');
}
