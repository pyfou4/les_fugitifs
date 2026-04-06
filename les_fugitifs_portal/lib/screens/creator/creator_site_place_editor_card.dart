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
  void didUpdateWidget(covariant CreatorSitePlaceEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newLat = _stringify(widget.latValue);
    final newLng = _stringify(widget.lngValue);

    if (_latCtrl.text != newLat) {
      _latCtrl.text = newLat;
    }
    if (_lngCtrl.text != newLng) {
      _lngCtrl.text = newLng;
    }
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

  InputDecoration _fieldDecoration({
    required String label,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFFAAB7C8),
        fontSize: 12,
      ),
      floatingLabelStyle: TextStyle(
        color: widget.color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      filled: true,
      fillColor:
      widget.isFrozen ? const Color(0xFF0F1726) : const Color(0xFF111D32),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF263854)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF263854)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A3443)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: widget.color, width: 1.6),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.70),
                  ),
                ),
                child: Text(
                  widget.placeId,
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latCtrl,
                  enabled: !widget.isFrozen,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: _fieldDecoration(label: 'Latitude'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lngCtrl,
                  enabled: !widget.isFrozen,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: _fieldDecoration(label: 'Longitude'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: (_isSaving || widget.isFrozen) ? null : _handleSave,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD65A00),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save_outlined, size: 14),
              label: Text(
                widget.isFrozen ? 'Gelé' : 'Sauver',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}