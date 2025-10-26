void main() {
  // Test filenames
  final testFiles = [
    '01.-Garden Grove',
    '01 - Speak To Me',
    '02.-What I Got',
    '05 - Breathe (Reprise)',
  ];
  
  for (final nameWithoutExt in testFiles) {
    int? trackNum;
    String trackTitle = nameWithoutExt;

    // Try " - " separator first
    if (nameWithoutExt.contains(' - ')) {
      final splitParts = nameWithoutExt.split(' - ');
      if (splitParts.length >= 2) {
        trackNum = int.tryParse(splitParts[0].trim());
        trackTitle = splitParts.sublist(1).join(' - ').trim();
      }
    }
    // Try ".-" separator
    else if (nameWithoutExt.contains('.-')) {
      final splitParts = nameWithoutExt.split('.-');
      if (splitParts.length >= 2) {
        trackNum = int.tryParse(splitParts[0].trim());
        trackTitle = splitParts.sublist(1).join('.-').trim();
      }
    }
    
    print('File: "$nameWithoutExt" -> Track: $trackNum, Title: "$trackTitle"');
  }
}
