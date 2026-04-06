import 'dart:io';

void main() {
  final f = File('lib/screens/admin/global_insights_screen.dart');
  var content = f.readAsStringSync();
  
  // Menangani CRLF (Windows)
  content = content.replaceFirst('    );\r\n  }\r\n}\r\n\r\n  // -- User Voice', '    );\r\n  }\r\n\r\n  // -- User Voice');
  // Menangani LF (Unix/Mac)
  content = content.replaceFirst('    );\n  }\n}\n\n  // -- User Voice', '    );\n  }\n\n  // -- User Voice');
  
  f.writeAsStringSync(content);
  print('Perbaikan selesai.');
}
