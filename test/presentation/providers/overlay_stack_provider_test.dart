import 'package:flutter_test/flutter_test.dart';
import 'package:the_wisdom_project/presentation/providers/overlay_stack_provider.dart';

void main() {
  test('remove with an id not on the stack changes nothing', () {
    final stack = OverlayStackNotifier();
    addTearDown(stack.dispose);
    stack.push(DismissibleOverlay(id: 'dictionary', dismiss: () {}));
    var notified = 0;
    stack.addListener((_) => notified++, fireImmediately: false);

    // The match button's dispose does this on every tab switch.
    stack.remove('match-options-menu');

    expect(notified, 0);
    expect([for (final o in stack.state) o.id], ['dictionary']);
  });
}
