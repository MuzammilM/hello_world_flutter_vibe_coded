// This represents the state after adding back button functionality
class MyAppState extends ChangeNotifier {
  var current = WordPair.random();
  var history = <WordPair>[];

  void getNext() {
    history.add(current);
    current = WordPair.random();
    notifyListeners();
  }
  
  void getPrevious() {
    if (history.isNotEmpty) {
      current = history.removeLast();
      notifyListeners();
    }
  }
}