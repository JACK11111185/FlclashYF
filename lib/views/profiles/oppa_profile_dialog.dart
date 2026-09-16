import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

class OppaProfileDialog extends StatefulWidget {
  final OppaProxyConfig? initial;

  const OppaProfileDialog({super.key, this.initial});

  @override
  State<OppaProfileDialog> createState() => _OppaProfileDialogState();
}

class _OppaProfileDialogState extends State<OppaProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _server;
  late final TextEditingController _port;
  late final TextEditingController _password;
  late final TextEditingController _sni;
  late bool _skipCertVerify;
  late bool _udp;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? 'Oppa');
    _server = TextEditingController(text: initial?.server);
    _port = TextEditingController(text: (initial?.port ?? 443).toString());
    _password = TextEditingController(text: initial?.password);
    _sni = TextEditingController(text: initial?.sni);
    _skipCertVerify = initial?.skipCertVerify ?? false;
    _udp = initial?.udp ?? true;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      OppaProxyConfig(
        name: _name.text.trim(),
        server: _server.text.trim(),
        port: int.parse(_port.text),
        password: _password.text,
        sni: _sni.text.trim().isEmpty ? null : _sni.text.trim(),
        skipCertVerify: _skipCertVerify,
        udp: _udp,
      ),
    );
  }

  void _disposeControllers() {
    _name.dispose();
    _server.dispose();
    _port.dispose();
    _password.dispose();
    _sni.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? requiredValue(String? value) =>
        value?.trim().isEmpty != false ? 'Required' : null;
    return CommonDialog(
      title: 'Oppa profile',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
      child: SizedBox(
        width: 340,
        child: Form(
          key: _formKey,
          child: Wrap(
            runSpacing: 12,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: requiredValue,
              ),
              TextFormField(
                controller: _server,
                decoration: const InputDecoration(labelText: 'Server'),
                validator: requiredValue,
              ),
              TextFormField(
                controller: _port,
                decoration: const InputDecoration(labelText: 'Port'),
                validator: (value) {
                  final port = int.tryParse(value ?? '');
                  return port == null || port < 1 || port > 65535
                      ? '1-65535'
                      : null;
                },
              ),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: requiredValue,
              ),
              TextFormField(
                controller: _sni,
                decoration: const InputDecoration(labelText: 'SNI (optional)'),
              ),
              CheckboxListTile(
                title: const Text('UDP'),
                value: _udp,
                onChanged: (value) => setState(() => _udp = value ?? true),
              ),
              CheckboxListTile(
                title: const Text('Skip certificate verification'),
                value: _skipCertVerify,
                onChanged: (value) =>
                    setState(() => _skipCertVerify = value ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
