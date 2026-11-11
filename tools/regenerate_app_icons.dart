import 'dart:io';

/// Regenera los iconos conservando los booleanos de Xcode. La versión 0.14.4
/// del generador puede confundir esta opción con el nombre del catálogo.
Future<void> main() async {
  final root = File.fromUri(Platform.script).parent.parent;
  final app = Directory('${root.path}/transita_bolivia');
  final project = File('${app.path}/ios/Runner.xcodeproj/project.pbxproj');
  final booleanSetting = RegExp(
    r'(^\s*ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS\s*=\s*)([^;]+);',
    multiLine: true,
  );
  final original = await project.readAsString();
  final values = booleanSetting
      .allMatches(original)
      .map((m) => m.group(2)!.trim())
      .toList();
  if (values.any((value) => !['YES', 'NO'].contains(value))) {
    throw StateError(
      'La configuración de símbolos de Xcode debe contener YES o NO.',
    );
  }

  var result = 1;
  try {
    final generator = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'flutter_launcher_icons'],
      workingDirectory: app.path,
      mode: ProcessStartMode.inheritStdio,
    );
    result = await generator.exitCode;
  } finally {
    final generated = await project.readAsString();
    if (booleanSetting.allMatches(generated).length != values.length) {
      throw StateError(
        'Cambió la estructura de la configuración de Xcode; revisa el proyecto.',
      );
    }
    var index = 0;
    final repaired = generated.replaceAllMapped(
      booleanSetting,
      (match) => '${match.group(1)}${values[index++]};',
    );
    if (repaired != generated) await project.writeAsString(repaired);
  }
  if (result != 0) {
    exitCode = result;
    return;
  }
  stdout.writeln(
    'Iconos actualizados; configuración booleana de Xcode conservada.',
  );
}
