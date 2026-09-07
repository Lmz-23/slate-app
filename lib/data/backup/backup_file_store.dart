import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../data/backup/backup_codec.dart';

/// Responsable de leer/escribir el archivo portable de backup en el
/// almacenamiento del dispositivo.
///
/// En producción resuelve el directorio con `path_provider`; en tests se
/// inyecta un [Directory] base temporal para mantener los tests herméticos.
class BackupFileStore {
  BackupFileStore({Directory? baseDirectory}) : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;

  Future<Directory> _resolveDirectory() async {
    if (_baseDirectory != null) return _baseDirectory;
    // Documents de la aplicación: en iOS es accesible desde la app Archivos
    // si la app habilita el file sharing; en Android es el directorio privado
    // de la app (el usuario recibe el archivo vía el share sheet al exportar).
    return getApplicationDocumentsDirectory();
  }

  /// Escribe el contenido en un archivo `slate_backup_<fecha>.json` y
  /// devuelve la ruta absoluta del archivo creado.
  Future<String> writeExport(String content, {DateTime? timestamp}) async {
    final dir = await _resolveDirectory();
    final stamp = _timestamp(timestamp ?? DateTime.now());
    final file = File('${dir.path}${Platform.pathSeparator}slate_backup_$stamp.json');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  /// Lee el contenido de un archivo. Lanza [BackupException] si no existe.
  Future<String> readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const BackupException('El archivo seleccionado no existe.');
    }
    return file.readAsString();
  }

  /// Marca temporal legible y ordenable: `20260809_103000`.
  String _timestamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}