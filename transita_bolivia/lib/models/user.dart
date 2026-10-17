import 'trip_qr.dart';
import 'money.dart';

class User {
  final int id;
  final String nombre;
  final String apellido;
  final String ci;
  final String email;
  final String tipo;
  final num puntos;
  final String estado;

  User({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.ci,
    required this.email,
    required this.tipo,
    required this.puntos,
    required this.estado,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      nombre: json['nombre'],
      apellido: json['apellido'],
      ci: json['ci'] ?? '',
      email: json['email'] ?? '',
      tipo: json['tipo'],
      puntos: Money.read(json['puntos']),
      estado: json['estado'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'ci': ci,
      'email': email,
      'tipo': tipo,
      'puntos': puntos,
      'estado': estado,
    };
  }

  String get tipoDisplay {
    switch (tipo) {
      case 'estudiante':
        return 'Estudiante';
      case 'civil':
        return 'Civil';
      case 'adulto_mayor':
        return 'Adulto Mayor';
      case 'discapacitado':
        return 'Persona con discapacidad';
      default:
        return tipo;
    }
  }

  num get costoViaje => TripQr.fares[tipo] ?? 1;
}
