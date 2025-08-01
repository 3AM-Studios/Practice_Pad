// Defines the 12 keys in the Circle of Fifths order, starting from C.

const List<String> circleOfFifthsKeyNames = [
  'C',
  'G',
  'D',
  'A',
  'E',
  'B',
  'F#', // F-sharp / G-flat
  'C#', // C-sharp / D-flat
  'Ab',
  'Eb',
  'Bb',
  'F',
];

// Helper to get enharmonic equivalents for display if needed,
// or to resolve to a common name for logic if necessary.
String getDisplayKeyName(String key) {
  switch (key) {
    case 'F#':
      return 'F# / Gb';
    case 'C#':
      return 'C# / Db';
    // Add other enharmonics if you choose to represent them differently in the core list
    default:
      return key;
  }
}
