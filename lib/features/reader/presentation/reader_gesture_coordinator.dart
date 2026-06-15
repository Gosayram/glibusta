class ReaderGestureCoordinator {
  bool _selectionActive = false;
  bool _bottomSheetOpen = false;
  bool _searchOpen = false;

  void onSelectionStarted() {
    _selectionActive = true;
  }

  void onSelectionCleared() {
    _selectionActive = false;
  }

  void onBottomSheetOpened() {
    _bottomSheetOpen = true;
  }

  void onBottomSheetClosed() {
    _bottomSheetOpen = false;
  }

  void onSearchOpened() {
    _searchOpen = true;
  }

  void onSearchClosed() {
    _searchOpen = false;
  }

  bool get shouldHandleTap => !_selectionActive && !_bottomSheetOpen && !_searchOpen;

  bool get shouldHandleDoubleTap => !_selectionActive && !_bottomSheetOpen && !_searchOpen;

  bool get shouldHandleLongPress => !_selectionActive && !_bottomSheetOpen && !_searchOpen;

  bool get shouldHandleVerticalDrag => !_selectionActive && !_bottomSheetOpen && !_searchOpen;
}
