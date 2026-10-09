import 'package:favor_ledger/application/providers.dart';
import 'package:favor_ledger/presentation/widgets/app_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PersonFormPage extends ConsumerStatefulWidget {
  const PersonFormPage({super.key, this.personId});

  final String? personId;

  @override
  ConsumerState<PersonFormPage> createState() => _PersonFormPageState();
}

class _PersonFormPageState extends ConsumerState<PersonFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _note = TextEditingController();
  var _loading = false;
  var _initialized = false;

  bool get _isEdit => widget.personId != null;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadIfNeeded() async {
    if (_initialized || widget.personId == null) {
      _initialized = true;
      return;
    }
    final person = await ref.read(databaseProvider).getPerson(widget.personId!);
    if (person != null && mounted) {
      _name.text = person.name;
      _note.text = person.note;
    }
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    return AppBackdrop(
      child: FutureBuilder(
        future: _loadIfNeeded(),
        builder: (context, snapshot) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: Text(_isEdit ? '编辑亲友' : '添加亲友')),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  SoftPanel(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: '姓名'),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return '请输入姓名';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _note,
                          decoration: const InputDecoration(
                            labelText: '备注（可选）',
                            hintText: '关系、怎么认识等',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _save,
                    child: Text(_loading ? '保存中…' : '保存'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final actions = ref.read(ledgerActionsProvider);
    try {
      if (_isEdit) {
        await actions.updatePerson(
          id: widget.personId!,
          name: _name.text,
          note: _note.text,
        );
        if (mounted) context.pop();
      } else {
        final person = await actions.createPerson(
          name: _name.text,
          note: _note.text,
        );
        if (mounted) {
          context.pop();
          context.push('/person/${person.id}');
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
