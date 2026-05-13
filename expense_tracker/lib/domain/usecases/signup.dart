import '../repositories/auth_repository.dart';

class Signup {
  final AuthRepository repository;

  Signup(this.repository);

  Future<String> call(String email, String password, String name) {
    return repository.signup(email, password, name);
  }
}
