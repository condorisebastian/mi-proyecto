import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/financial_chat.dart';
import '../../services/admin_auth_service.dart';
import '../../services/financial_chat_service.dart';
import '../chat/financial_chat_screen.dart';

class AdminChatsTab extends StatelessWidget {
  const AdminChatsTab({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: FinancialChatService.instance.chatsStream(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('No pudimos cargar los chats.'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final chats = snapshot.data!;
      if (chats.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 56),
              SizedBox(height: 12),
              Text('Aún no hay conversaciones'),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: chats.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final chat = chats[index];
          final isDriver = chat['canal'] == 'conductor';
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  isDriver
                      ? Icons.directions_bus_outlined
                      : Icons.person_outline,
                ),
              ),
              title: Text(chat['nombre'] as String? ?? 'Cliente'),
              subtitle: Text(
                '${isDriver ? 'Retiros' : 'Recargas'} · ${chat['ultimo_mensaje'] ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final admin = context.read<AdminAuthService>().currentAdmin;
                if (admin == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FinancialChatScreen(
                      owner: ChatIdentity(
                        canal: chat['canal'] as String,
                        id: (chat['id_cliente'] as num).toInt(),
                        nombre: chat['nombre'] as String? ?? 'Cliente',
                      ),
                      admin: true,
                      adminId: admin.id,
                      adminName: '${admin.nombre} ${admin.apellido}',
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    },
  );
}
