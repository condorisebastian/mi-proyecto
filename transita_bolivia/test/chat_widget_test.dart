import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transita_bolivia/models/financial_chat.dart';
import 'package:transita_bolivia/screens/chat/financial_chat_screen.dart';
import 'package:transita_bolivia/services/financial_chat_service.dart';

void main() {
  testWidgets('el chat envía mensajes y cancelar no crea una recarga', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    const owner = ChatIdentity(canal: 'pasajero', id: 1, nombre: 'Ana');
    final service = FinancialChatService(firestore: db);
    await tester.pumpWidget(
      MaterialApp(
        home: FinancialChatScreen(owner: owner, service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Deseo recargar mi saldo');
    await tester.tap(find.byTooltip('Enviar mensaje'));
    await tester.pumpAndSettle();
    expect(find.text('Deseo recargar mi saldo'), findsOneWidget);
    expect(
      (await service.messagesStream(owner.chatId).first).single['autor'],
      'cliente',
    );
    await tester.tap(find.text('SOLICITAR RECARGA'));
    await tester.pumpAndSettle();
    expect(find.text('Solicitar recarga'), findsOneWidget);
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    expect(
      (await db.collection('solicitudes_financieras').get()).docs,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('el chat cabe en pantalla estrecha con teclado visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    const owner = ChatIdentity(canal: 'pasajero', id: 1, nombre: 'Ana');
    final service = FinancialChatService(firestore: db);
    await tester.pumpWidget(
      MaterialApp(
        home: FinancialChatScreen(owner: owner, service: service),
      ),
    );
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Enviar mensaje'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
