/// Dummy LOGIN accounts for testing sessions without a real login screen.
///
/// These must also be created by hand in the Firebase console:
///   Authentication -> Users -> Add user  (same email + password as below)
///
/// FOR TESTING ONLY. This repository is public, so anyone can see these
/// passwords. Never use them for real accounts.
class TestAccount {
  final String label;
  final String email;
  final String password;

  const TestAccount(this.label, this.email, this.password);
}

const List<TestAccount> testAccounts = [
  TestAccount('Test User 1', 'testuser1@tigerden.dev', 'TigerDenTest1!'),
  TestAccount('Test User 2', 'testuser2@tigerden.dev', 'TigerDenTest2!'),
];
