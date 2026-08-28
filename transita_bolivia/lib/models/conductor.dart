class Conductor {
  final int id;
  final String nombre;
  final String apellido;
  final String ci;
  final String licencia;
  final String? telefono;
  final String estado;

  Conductor({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.ci,
    required this.licencia,
    this.telefono,
    required this.estado,
  });

  factory Conductor.fromJson(Map<String, dynamic> json) {
    return Conductor(
      id: json['id'],
      nombre: json['nombre'],
      apellido: json['apellido'],
      ci: json['ci'],
      licencia: json['licencia'],
      telefono: json['telefono'],
      estado: json['estado'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'ci': ci,
      'licencia': licencia,
      'telefono': telefono,
      'estado': estado,
    };
  }
}
