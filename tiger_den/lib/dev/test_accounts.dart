/// Dummy LOGIN accounts for testing sessions without a real login screen.
///
/// These must also be created by hand in the Firebase console:
///   Authentication -> Users -> Add user  (same email + password as below)
///
/// Each one also needs a profile document at users/{their user ID}. The
/// session test page (lib/dev/session_test_main.dart) has a
/// "Create test profile" button that makes it using the info below.
///
/// FOR TESTING ONLY. This repository is public, so anyone can see these
/// passwords. Never use them for real accounts.
class TestAccount {
  final String label;
  final String email;
  final String password;
  final String username;

  const TestAccount(this.label, this.email, this.password, this.username);
}

const List<TestAccount> testAccounts = [
  TestAccount(
      'Test User 1', 'testuser1@tigerden.dev', 'TigerDenTest1!', 'test_user_1'),
  TestAccount(
      'Test User 2', 'testuser2@tigerden.dev', 'TigerDenTest2!', 'test_user_2'),
];
