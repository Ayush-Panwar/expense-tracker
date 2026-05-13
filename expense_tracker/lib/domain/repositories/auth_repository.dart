abstract class AuthRepository {
  Future<String> login(String email, String password);
  Future<String> signup(String email, String password, String name);
  Future<void> logout();
  Future<bool> isAuthenticated();
}
