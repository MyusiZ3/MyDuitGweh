import 'dart:io';

void main() {
  final file = File(r'C:\Users\muham\Documents\Github\MyDuitGweh\lib\screens\admin\global_insights_screen.dart');
  final lines = file.readAsLinesSync();
  
  // Mencari baris 1873 (index 1872) yang berisi '}' tunggal
  if (lines.length > 1872 && lines[1872].trim() == '}') {
    lines.removeAt(1872);
    file.writeAsStringSync(lines.join('\n'));
    print('SUCCESS_REMOVED_LINE_1873');
  } else {
    // Cari secara dinamis jika nomor baris berubah
    int targetIndex = -1;
    for (int i = 0; i < lines.length - 2; i++) {
      if (lines[i].contains(');') && 
          lines[i+1].trim() == '}' && 
          lines[i+2].trim() == '}') {
        targetIndex = i + 2; 
        break;
      }
    }
    
    if (targetIndex != -1) {
      lines.removeAt(targetIndex);
      file.writeAsStringSync(lines.join('\n'));
      print('SUCCESS_DYNAMIC_REMOVAL');
    } else {
      print('BRACKET_NOT_FOUND');
    }
  }
}
