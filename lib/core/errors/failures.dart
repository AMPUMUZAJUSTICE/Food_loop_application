import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class InvalidEmailFailure extends Failure { const InvalidEmailFailure(super.message); }
class UserNotFoundFailure extends Failure { const UserNotFoundFailure(super.message); }
class WrongPasswordFailure extends Failure { const WrongPasswordFailure(super.message); }
class EmailAlreadyInUseFailure extends Failure { const EmailAlreadyInUseFailure(super.message); }
class WeakPasswordFailure extends Failure { const WeakPasswordFailure(super.message); }
class NetworkFailure extends Failure { const NetworkFailure(super.message); }
class InvalidEmailDomainFailure extends Failure { const InvalidEmailDomainFailure(super.message); }
class ServerFailure extends Failure { const ServerFailure(super.message); }
