void main() {
  final testFiles = [
    '01.-Garden Grove.flac',
    '01 - Speak To Me.flac',
  ];
  
  for (final fileName in testFiles) {
    // OLD WAY (WRONG)
    final oldWay = fileName.split('.').first;
    
    // NEW WAY (CORRECT)
    final newWay = fileName.substring(0, fileName.lastIndexOf('.'));
    
    print('File: $fileName');
    print('  Old way: "$oldWay" ❌');
    print('  New way: "$newWay" ✓');
    
    // Now test parsing
    final nameWithoutExt = newWay;
    int? trackNum;
    String trackTitle = nameWithoutExt;
    
    if (nameWithoutExt.contains(' - ')) {
      final parts = nameWithoutExt.split(' - ');
      trackNum = int.tryParse(parts[0].trim());
      trackTitle = parts.sublist(1).join(' - ').trim();
    } else if (nameWithoutExt.contains('.-')) {
      final parts = nameWithoutExt.split('.-');
      trackNum = int.tryParse(parts[0].trim());
      trackTitle = parts.sublist(1).join('.-').trim();
    }
    
    print('  → Track: $trackNum, Title: "$trackTitle"\n');
  }
}
