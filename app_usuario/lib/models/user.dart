class User {
  final int id;
  final String nombre;
  final String apellido;
  final String ci;
  final String email;
  final String tipo;
  final int puntos;
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
      ci: json['ci'],
      email: json['email'],
      tipo: json['tipo'],
      puntos: json['puntos'],
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
        return '🎓 Estudiante';
      case 'civil':
        return '👤 Civil';
      case 'adulto_mayor':
        return '👴 Adulto Mayor';
      default:
        return tipo;
    }
  }

  int get costoViaje {
    switch (tipo) {
      case 'estudiante':
        return 1;
      case 'civil':
        return 3;
      case 'adulto_mayor':
        return 1;
      default:
        return 1;
    }
  }
}
