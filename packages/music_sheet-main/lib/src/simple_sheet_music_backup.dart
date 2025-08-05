// This is a backup to hold the key changes needed for the width fix
// The main change needed is in _updateLayout() method:

// Change this line:
// widgetWidth: widget.width,

// To this:
// widgetWidth: MediaQuery.of(context).size.width,

// And in build method, change:
// Size(widget.width, currentLayout.totalContentHeight)

// To:
// Size(MediaQuery.of(context).size.width, currentLayout.totalContentHeight)

// And change:
// SizedBox(width: widget.width,

// To:
// SizedBox(width: MediaQuery.of(context).size.width,