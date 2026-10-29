import '../../models/money.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config.dart';
import '../../models/financial_chat.dart';
import '../../services/financial_chat_service.dart';

class FinancialChatScreen extends StatefulWidget {
  const FinancialChatScreen({
    super.key,
    required this.owner,
    this.admin = false,
    this.adminId,
    this.adminName = '',
    this.service,
  });
  final ChatIdentity owner;
  final bool admin;
  final int? adminId;
  final String adminName;
  final FinancialChatService? service;
  @override
  State<FinancialChatScreen> createState() => _FinancialChatScreenState();
}

class _FinancialChatScreenState extends State<FinancialChatScreen> {
  final _message = TextEditingController();
  late final FinancialChatService _service;
  late Future<void> _ready;
  late final Stream<List<Map<String, dynamic>>> _messages;
  late final Stream<List<FinancialRequest>> _requests;
  Stream<WithdrawalBalance>? _balance;
  DateTime _withdrawalDay = DateTime.now();
  bool _busy = false;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FinancialChatService.instance;
    if (!AppConfig.useFirebase && widget.service == null) {
      _ready = Future.value();
      _messages = const Stream.empty();
      _requests = const Stream.empty();
      _balance = null;
    } else {
      _ready = _service.ensureChat(widget.owner);
      _messages = _service.messagesStream(widget.owner.chatId);
      _requests = _service.requestsStream(widget.owner.chatId);
      _balance = widget.owner.isDriver
          ? _service.withdrawalBalanceStream(
              widget.owner.id,
              day: _withdrawalDay,
            )
          : null;
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;
    final text = error is ChatFailure
        ? error.message
        : 'No se pudo completar la operación. Revisa tu conexión.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _send() async {
    if (_busy || _message.text.trim().isEmpty) return;
    final text = _message.text;
    setState(() => _busy = true);
    try {
      await _service.sendMessage(
        widget.owner,
        text,
        admin: widget.admin,
        adminId: widget.adminId,
        adminName: widget.adminName,
      );
      if (mounted && _message.text == text) _message.clear();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request() async {
    if (_busy) return;
    final amount = TextEditingController();
    final detail = TextEditingController();
    final form = GlobalKey<FormState>();
    final dialog = DialogRoute<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.owner.isDriver
              ? 'Solicitar retiro diario'
              : 'Solicitar recarga',
        ),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Monto en Bs',
                    helperText: 'Admite centavos, por ejemplo 3.50',
                  ),
                  validator: (value) {
                    final n = Money.tryParse(value ?? '');
                    return n == null || n <= 0 || n > 1000000
                        ? 'Introduce un monto válido'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: detail,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Detalle para el operador',
                    hintText: widget.owner.isDriver
                        ? 'Indica cómo deseas recibir tu retiro'
                        : 'Indica tu referencia de pago o consulta',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.owner.isDriver
                      ? 'El monto quedará reservado hasta que el operador confirme o rechace el retiro.'
                      : 'El saldo se acredita cuando el operador verifica y confirma la recarga.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('ENVIAR SOLICITUD'),
          ),
        ],
      ),
    );
    final confirmed = await Navigator.of(context).push(dialog);
    final value = Money.tryParse(amount.text);
    final text = detail.text;
    await dialog.completed;
    amount.dispose();
    detail.dispose();
    if (!mounted || confirmed != true || value == null) return;
    setState(() => _busy = true);
    try {
      await _service.request(
        widget.owner,
        value,
        text,
        day: widget.owner.isDriver ? _withdrawalDay : null,
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve(FinancialRequest request, bool approve) async {
    if (_resolving || widget.adminId == null) return;
    final note = TextEditingController();
    final dialog = DialogRoute<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          approve
              ? 'Confirmar ${request.isWithdrawal ? 'retiro' : 'recarga'}'
              : 'Rechazar solicitud',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                approve
                    ? (request.isWithdrawal
                          ? 'Confirma solo si entregaste Bs ${Money.format(request.monto)} al conductor.'
                          : 'Confirma solo si verificaste el pago de Bs ${Money.format(request.monto)} del pasajero.')
                    : 'La solicitud quedará rechazada. Un retiro rechazado libera el monto reservado.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: note,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observación para el cliente',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
    final confirmed = await Navigator.of(context).push(dialog);
    final text = note.text;
    await dialog.completed;
    note.dispose();
    if (!mounted || confirmed != true) return;
    setState(() => _resolving = true);
    try {
      await _service.resolve(
        request.id,
        approve: approve,
        adminId: widget.adminId!,
        adminName: widget.adminName,
        note: text,
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.admin
              ? widget.owner.nombre
              : widget.owner.isDriver
              ? 'Chat · Retiros'
              : 'Chat · Recargas',
        ),
      ),
      body: !AppConfig.useFirebase && widget.service == null
          ? const Center(child: Text('El chat necesita el servicio en línea.'))
          : FutureBuilder<void>(
              future: _ready,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 40),
                        const Text('No pudimos abrir el chat.'),
                        TextButton(
                          onPressed: () => setState(
                            () => _ready = _service.ensureChat(widget.owner),
                          ),
                          child: const Text('REINTENTAR'),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      if (MediaQuery.viewInsetsOf(context).bottom == 0)
                        _header(),
                      if (MediaQuery.viewInsetsOf(context).bottom == 0)
                        _requestList(),
                      Expanded(child: _messageList()),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _message,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 1000,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'Escribe un mensaje...',
                                  counterText: '',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Enviar mensaje',
                              onPressed: _busy ? null : _send,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _chooseWithdrawalDay() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _withdrawalDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Día de recaudación',
    );
    if (!mounted || date == null) return;
    setState(() {
      _withdrawalDay = date;
      _balance = _service.withdrawalBalanceStream(widget.owner.id, day: date);
    });
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              widget.owner.isDriver
                  ? Icons.payments_outlined
                  : Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.owner.isDriver
                    ? 'Retiros de tu recaudación diaria'
                    : 'Recarga con atención del operador',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        if (widget.owner.isDriver)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy ? null : _chooseWithdrawalDay,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                'Recaudación del ${_withdrawalDay.day}/${_withdrawalDay.month}/${_withdrawalDay.year}',
              ),
            ),
          ),
        if (_balance != null)
          StreamBuilder<WithdrawalBalance>(
            stream: _balance,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('No pudimos consultar el disponible.');
              }
              final b = snapshot.data;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  b == null
                      ? 'Consultando recaudación...'
                      : 'Disponible: Bs ${Money.format(b.disponible)} · Pendiente: Bs ${Money.format(b.reservado)}\nRetirado en el día: Bs ${Money.format(b.retirado)}',
                ),
              );
            },
          ),
        if (!widget.admin)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy ? null : _request,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(
                widget.owner.isDriver
                    ? 'SOLICITAR RETIRO'
                    : 'SOLICITAR RECARGA',
              ),
            ),
          ),
      ],
    ),
  );

  Widget _requestList() => StreamBuilder<List<FinancialRequest>>(
    stream: _requests,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('No pudimos cargar las solicitudes.');
      }
      final requests = snapshot.data ?? [];
      if (requests.isEmpty) return const SizedBox.shrink();
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 185),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          req.isWithdrawal
                              ? Icons.outbound_outlined
                              : Icons.add_card,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${req.isWithdrawal ? 'Retiro' : 'Recarga'} · Bs ${Money.format(req.monto)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          req.statusLabel,
                          style: TextStyle(
                            color: req.pending
                                ? Colors.orange.shade800
                                : req.estado == 'aprobada'
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                    if (req.detalle.isNotEmpty)
                      Text(
                        req.detalle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (req.isWithdrawal)
                      Text(
                        'Recaudación del ${req.dia}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    if (widget.admin && req.pending)
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: _resolving
                                ? null
                                : () => _resolve(req, true),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('CONFIRMAR'),
                          ),
                          TextButton(
                            onPressed: _resolving
                                ? null
                                : () => _resolve(req, false),
                            child: const Text('RECHAZAR'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );

  Widget _messageList() => StreamBuilder<List<Map<String, dynamic>>>(
    stream: _messages,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('No pudimos cargar los mensajes.'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final messages = snapshot.data!;
      if (messages.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Escribe al operador para coordinar tu solicitud.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return ListView.builder(
        reverse: true,
        padding: const EdgeInsets.all(12),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final m = messages[index];
          final system = m['autor'] == 'sistema';
          final mine = m['autor'] == (widget.admin ? 'admin' : 'cliente');
          final date = m['fecha'] is Timestamp
              ? (m['fecha'] as Timestamp).toDate()
              : null;
          return Align(
            alignment: system
                ? Alignment.center
                : mine
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.85,
              ),
              decoration: BoxDecoration(
                color: system
                    ? Colors.grey.shade200
                    : mine
                    ? Colors.blue.shade50
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine)
                    Text(
                      m['nombre'] as String? ?? 'Atención',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  Text(m['texto'] as String? ?? ''),
                  if (date != null)
                    Text(
                      '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
