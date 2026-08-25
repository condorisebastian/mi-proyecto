import 'package:flutter/material.dart';

class UserTypeScreen extends StatelessWidget {
  const UserTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E88E5),
              Color(0xFF1565C0),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.directions_bus,
                  size: 100,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Transporte Santa Cruz',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '¿Quién eres?',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                _buildUserTypeButton(
                  context,
                  icon: Icons.school,
                  title: 'Estudiante',
                  subtitle: 'Costo: 1 punto por viaje',
                  onPressed: () {
                    Navigator.pushNamed(context, '/login',
                        arguments: {'tipo': 'estudiante'});
                  },
                ),
                const SizedBox(height: 16),
                _buildUserTypeButton(
                  context,
                  icon: Icons.person,
                  title: 'Civil',
                  subtitle: 'Costo: 3 puntos por viaje',
                  onPressed: () {
                    Navigator.pushNamed(context, '/login',
                        arguments: {'tipo': 'civil'});
                  },
                ),
                const SizedBox(height: 16),
                _buildUserTypeButton(
                  context,
                  icon: Icons.elderly,
                  title: 'Adulto Mayor',
                  subtitle: 'Costo: 1 punto por viaje',
                  onPressed: () {
                    Navigator.pushNamed(context, '/login',
                        arguments: {'tipo': 'adulto_mayor'});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        height: 80,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E88E5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
          child: Row(
            children: [
              const SizedBox(width: 20),
              Icon(icon, size: 40),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}
