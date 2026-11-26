import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/gaiji.dart';
import '../services/image_pipeline.dart';
import '../state/album_store.dart';
import '../theme/app_theme.dart';

/// 新規登録・編集の入力画面。
///
/// 字形はすでに切り取られている前提。ここでは「意味」を添える。
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.glyphPng,
    this.originalJpg,
    this.existing,
  });

  final Uint8List glyphPng;
  final Uint8List? originalJpg;

  /// 編集の場合の既存レコード
  final Gaiji? existing;

  bool get isEditing => existing != null;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _reading;
  late final TextEditingController _source;
  late final TextEditingController _memo;
  late GaijiCategory _category;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _reading = TextEditingController(text: e?.reading ?? '');
    _source = TextEditingController(text: e?.source ?? '');
    _memo = TextEditingController(text: e?.memo ?? '');
    _category = e?.category ?? GaijiCategory.itaiji;
  }

  @override
  void dispose() {
    _name.dispose();
    _reading.dispose();
    _source.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // 入力の不備は日本語でその場に示す（無反応にしない）
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = '名称を入力してください。');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    final store = context.read<AlbumStore>();
    try {
      if (widget.isEditing) {
        final base = widget.existing!;
        await store.update(
          base.copyWith(
            name: _name.text.trim(),
            reading: _reading.text.trim(),
            category: _category,
            source: _source.text.trim(),
            memo: _memo.text.trim(),
            glyphPng: widget.glyphPng,
            originalJpg: widget.originalJpg,
          ),
        );
      } else {
        await store.add(
          name: _name.text,
          reading: _reading.text,
          category: _category,
          source: _source.text,
          memo: _memo.text,
          glyphPng: widget.glyphPng,
          originalJpg: widget.originalJpg,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ImagePipelineException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('保存できませんでした。端末の空き容量を確認して、もう一度お試しください。');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Text(
          widget.isEditing ? '記録を編集' : '外字を登録',
          style: const TextStyle(
            fontFamily: AppText.serif,
            fontSize: 20,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _buildGlyphPreview(),
              const SizedBox(height: 26),
              _field(
                controller: _name,
                label: '名称',
                hint: '例：𠮷（つちよし）、金偏に…',
                required: true,
                maxLength: 60,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '名称を入力してください' : null,
              ),
              _field(
                controller: _reading,
                label: '読み（任意）',
                hint: '例：きち、うん、ばん',
                maxLength: 60,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 4),
              _buildCategoryPicker(),
              const SizedBox(height: 18),
              _field(
                controller: _source,
                label: '出典（任意）',
                hint: '例：『大正蔵』第12巻、〇〇寺 過去帳、版木',
                maxLength: 120,
                textInputAction: TextInputAction.next,
              ),
              _field(
                controller: _memo,
                label: 'メモ（任意）',
                hint: '用例、法話で使う場面など',
                maxLength: 600,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                _buildErrorBox(_error!),
              ],
              const SizedBox(height: 26),
              SizedBox(
                height: 60,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: AppColors.paper,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.paper,
                          ),
                        )
                      : Text(
                          widget.isEditing ? 'この内容で保存する' : 'この外字を記録する',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlyphPreview() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '切り取った字形',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.ink.withValues(alpha: 0.55),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              height: 168,
              width: 168,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                border: Border.all(color: AppColors.line),
              ),
              child: Image.memory(
                widget.glyphPng,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (c, e, s) => const Center(
                  child: Text(
                    '字形を表示できません',
                    style: TextStyle(fontSize: 14, color: AppColors.caution),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 2),
          child: Text(
            '分類',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.ink.withValues(alpha: 0.62),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: GaijiCategory.values.map((c) {
            final selected = _category == c;
            return InkWell(
              onTap: () => setState(() => _category = c),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.ink : Colors.white,
                  border: Border.all(
                    color: selected ? AppColors.ink : AppColors.line,
                    width: selected ? 1.4 : 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  c.label,
                  style: TextStyle(
                    fontSize: 16,
                    color: selected ? AppColors.paper : AppColors.ink,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_category.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2),
            child: Text(
              _category.description,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.ink.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    int maxLines = 1,
    int? maxLength,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.ink.withValues(alpha: 0.62),
                    letterSpacing: 1.2,
                  ),
                ),
                if (required)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Text(
                      '必須',
                      style: TextStyle(fontSize: 11.5, color: AppColors.caution),
                    ),
                  ),
              ],
            ),
          ),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            textInputAction: textInputAction,
            validator: validator,
            // iOS の自動拡大を防ぐため 18px（16px 以上）
            style: const TextStyle(
              fontSize: AppText.field,
              color: AppColors.ink,
              height: 1.5,
            ),
            cursorColor: AppColors.gold,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 15,
                color: AppColors.ink.withValues(alpha: 0.32),
              ),
              counterStyle: TextStyle(
                fontSize: 12,
                color: AppColors.ink.withValues(alpha: 0.35),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.caution),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.caution, width: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEDEA),
        border: Border.all(color: AppColors.caution.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.caution, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.caution,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
