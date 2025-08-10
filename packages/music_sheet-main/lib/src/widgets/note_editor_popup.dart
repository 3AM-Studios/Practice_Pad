import 'package:flutter/material.dart';
import 'package:music_sheet/index.dart';

/// A class to hold the result from the note editor dialog.
class SymbolEditResult {
  final MusicalSymbol? musicalSymbol;
  final bool isDelete;

  SymbolEditResult({this.musicalSymbol, this.isDelete = false});
}

/// Displays the note editor dialog as a popup.
Future<SymbolEditResult?> showNoteEditorPopup(BuildContext context, Offset position, MusicalSymbol? initialNote) {
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

  return showMenu<SymbolEditResult>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(position, position),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem(
        enabled: false, // Make the item not selectable, just a container
        child: SymbolEditorDialog(initialNote: initialNote),
      ),
    ],
    elevation: 8.0,
  );
}

/// The main dialog widget for editing a note or rest.
class SymbolEditorDialog extends StatefulWidget {
  final MusicalSymbol? initialNote;

  const SymbolEditorDialog({super.key, this.initialNote});

  @override
  State<SymbolEditorDialog> createState() => _SymbolEditorDialogState();
}

class _SymbolEditorDialogState extends State<SymbolEditorDialog> {
  // State variables
  bool _isNote = true; // true for Note, false for Rest
  Accidental? _selectedAccidental;
  NoteDuration _selectedDuration = NoteDuration.quarter;
  RestType _selectedRestType = RestType.quarter;

  @override
  void initState() {
    super.initState();
    final note = widget.initialNote;
    if (note is Note) {
      _isNote = true;
      _selectedAccidental = note.accidental;
      _selectedDuration = note.noteDuration;
    } else if (note is Rest) {
      _isNote = false;
      _selectedRestType = note.restType;
    }
  }

  void _popWithResult(SymbolEditResult result) {
    Navigator.of(context).pop(result);
  }


  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280, // Constrain the width of the popup
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ToggleButtons(
            isSelected: [_isNote, !_isNote],
            onPressed: (index) {
              setState(() {
                _isNote = index == 0;
              });
            },
            children: const [Text('Note'), Text('Rest')],
          ),
          const Divider(),
          if (_isNote)
            _buildSymbolEditor()
          else
            _buildRestEditor(),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => _popWithResult(SymbolEditResult(isDelete: true)),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(), // Cancel
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolEditor() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Accidentals
        const Text('Accidental'),
        ToggleButtons(
          isSelected: [
            _selectedAccidental == Accidental.sharp,
            _selectedAccidental == Accidental.flat,
            _selectedAccidental == Accidental.natural,
          ],
          onPressed: (index) {
            setState(() {
              final newAccidental = [Accidental.sharp, Accidental.flat, Accidental.natural][index];
              _selectedAccidental = (_selectedAccidental == newAccidental) ? null : newAccidental;
            });
          },
          children: const [Text('♯'), Text('♭'), Text('♮')],
        ),
        const SizedBox(height: 8),
        // Rhythm
        const Text('Rhythm'),
        Wrap(
          spacing: 4.0,
          runSpacing: 4.0,
          alignment: WrapAlignment.center,
          children: NoteDuration.values.where((d) => [NoteDuration.whole, NoteDuration.half, NoteDuration.quarter, NoteDuration.eighth, NoteDuration.sixteenth].contains(d)).map((duration) {
            return ChoiceChip(
              label: Text(duration.name),
              selected: _selectedDuration == duration,
              onSelected: (selected) {
                if (selected) {
                  // Create the note immediately when duration is selected
                  MusicalSymbol newSymbol;
                  
                  // Get the pitch - use original note's pitch if available, or default to middle C
                  Pitch pitch;
                  if (widget.initialNote is Note) {
                    pitch = (widget.initialNote as Note).pitch;
                  } else {
                    // Default to middle C if converting from Rest to Note
                    pitch = Pitch.c4;
                  }
                  
                  newSymbol = Note(
                    pitch,
                    noteDuration: duration,
                    accidental: _selectedAccidental,
                  );
                  
                  _popWithResult(SymbolEditResult(musicalSymbol: newSymbol));
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRestEditor() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Rest Type'),
        Wrap(
          spacing: 4.0,
          runSpacing: 4.0,
          alignment: WrapAlignment.center,
          children: RestType.values.where((r) => [RestType.whole, RestType.half, RestType.quarter, RestType.eighth, RestType.sixteenth].contains(r)).map((restType) {
            return ChoiceChip(
              label: Text(restType.name),
              selected: _selectedRestType == restType,
              onSelected: (selected) {
                if (selected) {
                  _popWithResult(SymbolEditResult(musicalSymbol: Rest(restType)));
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
