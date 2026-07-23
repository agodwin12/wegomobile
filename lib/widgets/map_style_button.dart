import 'package:flutter/material.dart';
import '../utils/map_style.dart';

/// Floating layers button that opens a style picker bottom sheet.
/// Place it inside the map's Stack:
///
///   MapStyleButton(
///     current: _mapStyle,
///     onChanged: (s) => setState(() { _mapStyle = s; saveMapStylePref(s); }),
///   )
class MapStyleButton extends StatelessWidget {
  const MapStyleButton({
    super.key,
    required this.current,
    required this.onChanged,
    this.bottom = 120,
    this.right = 12,
  });

  final MapStyle current;
  final ValueChanged<MapStyle> onChanged;
  final double bottom;
  final double right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: bottom,
      right: right,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showPicker(context),
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.layers_outlined, size: 22, color: Color(0xFF1A1A2E)),
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StyleSheet(current: current, onChanged: (s) {
        onChanged(s);
        Navigator.of(context).pop();
      }),
    );
  }
}

class _StyleSheet extends StatelessWidget {
  const _StyleSheet({required this.current, required this.onChanged});

  final MapStyle current;
  final ValueChanged<MapStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle + title
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 2, 20, 14),
            child: Text(
              'Map Style',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
                fontFamily: 'LeagueSpartan',
              ),
            ),
          ),

          // Style grid
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: MapStyle.values.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (_, i) => _StyleTile(
                style: MapStyle.values[i],
                selected: MapStyle.values[i] == current,
                onTap: () => onChanged(MapStyle.values[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final MapStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // Color swatch card
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: style.swatch,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? const Color(0xFFF5A623) : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(style.icon, color: style.labelColor.withOpacity(0.85), size: 22),
                  ),
                  if (selected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5A623),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? const Color(0xFFF5A623) : const Color(0xFF555566),
              fontFamily: 'LeagueSpartan',
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
