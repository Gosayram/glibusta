class ReaderGestureCoordinator {
  bool _bottomSheetOpen = false;
  bool _searchOpen = false;

  void onBottomSheetOpened() => _bottomSheetOpen = true;
  void onBottomSheetClosed() => _bottomSheetOpen = false;
  void onSearchOpened() => _searchOpen = true;
  void onSearchClosed() => _searchOpen = false;

  bool get canInteract => !_bottomSheetOpen && !_searchOpen;
}
