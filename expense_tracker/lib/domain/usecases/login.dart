import '../repositories/auth_repository.dart';

class Login {
  final AuthRepository repository;

  Login(this.repository);

  Future<String> call(String email, String password) {
    return repository.login(email, password);
  }
}
