import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RequirementsScreen extends StatelessWidget {
  const RequirementsScreen({super.key});

  static const String _segipUrl = 'https://maps.app.goo.gl/JLEuULttsHockzt5A';

  Future<void> _openSegip(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      Uri.parse(_segipUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el mapa. Busca "SEGIP" en Google Maps.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final role = args?['role'] as String?;
    final tipo = args?['tipo'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Requisitos para el registro'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar:
          role == null ? null : _buildContinueBar(context, role, tipo),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNotice(),
          const SizedBox(height: 16),
          _buildLocation(context),
          const SizedBox(height: 16),
          _buildSection(
            icon: Icons.badge,
            title: 'Todos los pasajeros',
            items: const [
              'Fotocopia simple del Carnet de Identidad (anverso y reverso).',
              'Elegir y recordar tu PIN de 4 dígitos para entrar a la app.',
            ],
          ),
          _buildSection(
            icon: Icons.school,
            title: 'Estudiante (colegio)',
            items: const [
              'Fotocopia de la libreta del último año cursado (ej. 1ro de secundaria).',
              'Fotocopia del Carnet de Identidad del estudiante.',
              'Si es menor de edad, ver la sección "Menores de edad".',
            ],
          ),
          _buildSection(
            icon: Icons.account_balance,
            title: 'Estudiante (universidad)',
            items: const [
              'Fotocopia de matrícula o boleta de inscripción del año en curso.',
              'Fotocopia del carnet universitario vigente (si lo tienes).',
              'Si aún no cuentas con libreta, la matrícula reemplaza ese requisito.',
              'Fotocopia del Carnet de Identidad.',
            ],
          ),
          _buildSection(
            icon: Icons.person,
            title: 'Civil',
            items: const [
              'Fotocopia del Carnet de Identidad (anverso y reverso).',
              'No requiere libreta ni matrícula.',
            ],
          ),
          _buildSection(
            icon: Icons.elderly,
            title: 'Adulto mayor',
            items: const [
              'Fotocopia del Carnet de Identidad (se verifica la edad).',
              'No requiere libreta ni matrícula.',
            ],
          ),
          _buildSection(
            icon: Icons.accessible,
            title: 'Persona con discapacidad',
            items: const [
              'Fotocopia del carnet de discapacidad vigente.',
              'Fotocopia del Carnet de Identidad.',
              'Si es menor de edad, ver la sección "Menores de edad".',
            ],
          ),
          _buildSection(
            icon: Icons.family_restroom,
            title: 'Menores de edad',
            items: const [
              'Debe venir acompañado de su tutor legal o un responsable.',
              'El tutor o responsable debe presentar su Carnet de Identidad original y fotocopia.',
              'Fotocopia de la libreta del menor (último año cursado).',
              'No se acepta al menor solo ni con una carta sin tutor presente.',
            ],
          ),
          _buildSection(
            icon: Icons.directions_car,
            title: 'Conductor',
            items: const [
              'Fotocopia del Carnet de Identidad (anverso y reverso).',
              'Fotocopia de la licencia de conducir vigente (categoría correspondiente).',
              'Fotocopia de la libreta de último año cursado (si es estudiante).',
              'Registrar un PIN de 4 dígitos distinto al de tu cuenta de pasajero.',
            ],
          ),
          _buildSection(
            icon: Icons.checklist,
            title: 'No olvides',
            items: const [
              'Traer todas las fotocopias impresas (no se aceptan fotos del celular).',
              'Llevar los documentos originales para su verificación.',
              'Recomendado: 2 fotos tamaño carnet recientes.',
              'Acudir en el horario de atención de la oficina (lunes a viernes).',
              'El trámite y la verificación de documentos son presenciales.',
              'Anotar tu PIN de 4 dígitos antes de venir.',
            ],
          ),
          _buildSection(
            icon: Icons.info_outline,
            title: 'Importante',
            items: const [
              'El registro en la app se completa después de presentar los documentos en la oficina.',
              'Los requisitos pueden variar; confirma en ventanilla antes de tu trámite.',
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildContinueBar(
    BuildContext context,
    String role,
    String? tipo,
  ) {
    final isDriver = role == 'driver';
    final route = isDriver ? '/driver/register' : '/passenger/register';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacementNamed(
                context,
                route,
                arguments: isDriver ? null : {'tipo': tipo},
              );
            },
            icon: const Icon(Icons.app_registration),
            label: const Text(
              'Ya tengo los requisitos, registrar',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.assignment_ind, color: Color(0xFF1565C0)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'El registro es presencial. Debes presentar los siguientes '
              'requisitos en la oficina de SEGIP para habilitar tu cuenta.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocation(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Ubicación',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'SEGIP',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _segipUrl,
              style: const TextStyle(fontSize: 13, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openSegip(context),
                icon: const Icon(Icons.map),
                label: const Text('Abrir ubicación en Google Maps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
