import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:voter_app/change_password_screen.dart';
import 'package:voter_app/login_screen.dart';

void main() {
  testWidgets('Login screen renders required controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('Login to Continue'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('Register as a member'), findsOneWidget);
  });

  testWidgets('First-login password screen blocks navigation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChangePasswordScreen()),
    );
    expect(find.text('Change Temporary Password'), findsOneWidget);
    expect(find.text('Set New Password'), findsOneWidget);
  });
}
