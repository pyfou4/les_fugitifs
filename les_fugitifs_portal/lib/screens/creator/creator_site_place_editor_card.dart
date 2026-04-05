import 'package:flutter/material.dart';

class CreatorSitePlaceEditorCard extends StatefulWidget {
  final String placeId;
  final String title;
  final Color color;
  final dynamic latValue;
  final dynamic lngValue;
  final bool isFrozen;
  final Future<void> Function(String latText, String lngText) onSave;

  const CreatorSitePlaceEditorCard({
    super.key,
    required this.placeId,
    required this.title,
    required this.color,
    required this.latValue,
    required this.lngValue,
    required this.isFrozen,
    required this.onSave,
  });

  @override
  State<CreatorSitePlaceEditorCard> createState() =>
      _CreatorSitePlaceEditorCardState();
}

class _CreatorSitePlaceEditorCardState extends State<CreatorSitePlaceEditorCard> {
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _latCtrl = TextEditingController(text: _stringify(widget.latValue));
    _lngCtrl = TextEditingController(text: _stringify(widget.lngValue));
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  static String _stringify(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  Future<void> _handleSave() async {
    if (_isSaving || widget.isFrozen) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(_latCtrl.text, _lngCtrl.text);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D192C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isFrozen
              ? const Color(0xFF38465A)
              : const Color(0xFF1E2D45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: widget.color.withValues(alpha: 0.70)),
                ),
                child: Text(
                  widget.placeId,
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latCtrl,
                  enabled: !widget.isFrozen,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    labelStyle: const TextStyle(
                      color: Color(0xFFAAB7C8),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: widget.isFrozen
                        ? const Color(0xFF0F1726)
                        : const Color(0xFF111D32),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF263854)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF263854)),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2A3443)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: widget.color, width: 2),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _lngCtrl,
                  enabled: !widget.isFrozen,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    labelStyle: const TextStyle(
                      color: Color(0xFFAAB7C8),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: widget.isFrozen
                        ? const Color(0xFF0F1726)
                        : const Color(0xFF111D32),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF263854)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF263854)),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2A3443)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: widget.color, width: 2),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: (_isSaving || widget.isFrozen) ? null : _handleSave,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD65A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(widget.isFrozen ? 'Gelé' : 'Sauver'),
            ),
          ),
        ],
      ),
    );
  }
}
