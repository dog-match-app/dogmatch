/// Ação de swipe enviada em `POST /swipes`.
enum SwipeAction {
  like('LIKE'),
  pass('PASS');

  const SwipeAction(this.apiValue);

  /// Valor enviado à API.
  final String apiValue;
}
