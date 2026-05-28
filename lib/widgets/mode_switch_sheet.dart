// lib/widgets/mode_switch_sheet.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/mode_service.dart';

// ── Accent colours for each mode tile ────────────────────────────────
const _kBlack     = Color(0xFF0A0A0A);
const _kGold      = Color(0xFFFFDC71);
const _kCard      = Color(0xFF181818);
const _kCard2     = Color(0xFF222222);
const _kWhite     = Colors.white;
const _kGrey      = Color(0xFFA9A9A9);
const _kGreen     = Color(0xFF4CAF50);
const _kOrange    = Color(0xFFFF6B35);
const _kBlue      = Color(0xFF3B82F6);

// Per-mode visual config
const _modeConfig = {
  'PASSENGER': {
    'color':    _kBlue,
    'bg':       Color(0xFF0A1020),
    'icon':     Icons.person_rounded,
  },
  'DRIVER': {
    'color':    _kGold,
    'bg':       Color(0xFF1A1500),
    'icon':     Icons.directions_car_rounded,
  },
  'DELIVERY_AGENT': {
    'color':    _kOrange,
    'bg':       Color(0xFF1A0A00),
    'icon':     Icons.local_shipping_rounded,
  },
};

// ═══════════════════════════════════════════════════════════════════════
// PUBLIC ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════

Future<void> showModeSwitchSheet(
    BuildContext context, {
      VoidCallback? onSwitched,
    }) {
  return showModalBottomSheet(
    context:             context,
    isScrollControlled:  true,
    backgroundColor:     Colors.transparent,
    barrierColor:        Colors.black.withOpacity(0.6),
    builder: (_) => _ModeSwitchSheet(onSwitched: onSwitched),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// SHEET WIDGET
// ═══════════════════════════════════════════════════════════════════════

class _ModeSwitchSheet extends StatefulWidget {
  final VoidCallback? onSwitched;
  const _ModeSwitchSheet({this.onSwitched});

  @override
  State<_ModeSwitchSheet> createState() => _ModeSwitchSheetState();
}

class _ModeSwitchSheetState extends State<_ModeSwitchSheet> {

  // ─── State ────────────────────────────────────────────────────
  String  _userType   = '';
  String  _activeMode = '';
  String  _firstName  = '';
  List<ModeTarget> _targets = [];
  bool    _loading    = false;
  String? _switchingTo;   // which mode is currently being switched to
  String? _error;
  bool    _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final userType   = prefs.getString('user_type')   ?? '';
    final activeMode = await ModeService.getCurrentMode();
    final firstName  = prefs.getString('first_name')  ?? '';

    final targets = ModeService.availableTargets(
      userType:   userType,
      activeMode: activeMode,
    );

    if (mounted) {
      setState(() {
        _userType    = userType;
        _activeMode  = activeMode;
        _firstName   = firstName;
        _targets     = targets;
        _initialized = true;
      });
    }
  }

  Future<void> _switchTo(String targetMode) async {
    if (_loading) return;

    setState(() {
      _loading     = true;
      _switchingTo = targetMode;
      _error       = null;
    });

    final result = await ModeService.switchTo(targetMode);

    if (!mounted) return;

    if (result.success) {
      // Close the sheet first, then navigate
      Navigator.of(context).pop();
      widget.onSwitched?.call();

      // Replace the entire navigation stack with the new dashboard
      Navigator.of(context).pushNamedAndRemoveUntil(
        result.route!,
            (route) => false,
      );
    } else {
      setState(() {
        _loading     = false;
        _switchingTo = null;
        _error       = result.errorMessage ?? 'Switch failed. Please try again.';
      });
    }
  }

  // ─── Current mode label ───────────────────────────────────────
  String get _currentModeLabel {
    switch (_activeMode) {
      case 'DRIVER':         return 'Driver Mode';
      case 'DELIVERY_AGENT': return 'Delivery Agent Mode';
      case 'PASSENGER':      return 'Regular User';
      default:               return _activeMode;
    }
  }

  String get _currentModeEmoji {
    switch (_activeMode) {
      case 'DRIVER':         return '🚗';
      case 'DELIVERY_AGENT': return '📦';
      case 'PASSENGER':      return '🧑';
      default:               return '👤';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color:        Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 32 + bottomPad),
      child: !_initialized
          ? const _LoadingBody()
          : _targets.isEmpty
          ? const _NoTargetsBody()
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Handle ─────────────────────────────────────────────
        Center(
          child: Container(
            margin:      const EdgeInsets.symmetric(vertical: 12),
            width: 40,   height: 4,
            decoration:  BoxDecoration(
              color:        Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // ── Header ─────────────────────────────────────────────
        Row(
          children: [
            Container(
              padding:     const EdgeInsets.all(10),
              decoration:  BoxDecoration(
                color:        Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: _kGold,
                size:  22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Switch Mode',
                    style: TextStyle(
                      fontFamily: 'LeagueSpartan',
                      fontSize:   20,
                      fontWeight: FontWeight.w700,
                      color:      _kWhite,
                    ),
                  ),
                  Text(
                    _firstName.isNotEmpty ? 'Hi $_firstName — choose how to continue' : 'Choose how to continue',
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize:   12,
                      color:      _kGrey,
                    ),
                  ),
                ],
              ),
            ),
            // Close button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close_rounded, color: _kGrey, size: 18),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Current mode chip ────────────────────────────────────
        Container(
          padding:     const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration:  BoxDecoration(
            color:        Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_currentModeEmoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'Currently in: $_currentModeLabel',
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize:   12,
                  color:      _kGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Section label ────────────────────────────────────────
        const Text(
          'SWITCH TO',
          style: TextStyle(
            fontFamily:    'Quicksand',
            fontSize:      11,
            color:         _kGrey,
            fontWeight:    FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),

        const SizedBox(height: 12),

        // ── Mode tiles ───────────────────────────────────────────
        ..._targets.map((target) => _buildModeTile(target)),

        // ── Error ────────────────────────────────────────────────
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding:     const EdgeInsets.all(14),
            decoration:  BoxDecoration(
              color:        const Color(0xFFEF5350).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: const Color(0xFFEF5350).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF5350), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize:   12,
                      color:      Color(0xFFEF5350),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),
      ],
    );
  }

  // ─── Mode tile ─────────────────────────────────────────────────

  Widget _buildModeTile(ModeTarget target) {
    final config  = _modeConfig[target.mode] ?? _modeConfig['PASSENGER']!;
    final color   = config['color'] as Color;
    final bgColor = config['bg']    as Color;
    final icon    = config['icon']  as IconData;
    final isSwitching = _switchingTo == target.mode && _loading;
    final isDisabled  = _loading && !isSwitching;

    return GestureDetector(
      onTap: isDisabled || isSwitching ? null : () => _switchTo(target.mode),
      child: AnimatedContainer(
        duration:    const Duration(milliseconds: 200),
        margin:      const EdgeInsets.only(bottom: 12),
        padding:     const EdgeInsets.all(18),
        decoration:  BoxDecoration(
          color:        isSwitching ? bgColor : _kCard,
          borderRadius: BorderRadius.circular(18),
          border:       Border.all(
            color: isSwitching
                ? color.withOpacity(0.5)
                : Colors.white.withOpacity(0.07),
            width: isSwitching ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [

            // Icon circle
            AnimatedContainer(
              duration:    const Duration(milliseconds: 200),
              width:  52, height: 52,
              decoration:  BoxDecoration(
                color:        isSwitching
                    ? color.withOpacity(0.2)
                    : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: isSwitching
                  ? Center(
                child: SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    color:       color,
                    strokeWidth: 2.5,
                  ),
                ),
              )
                  : Icon(icon, color: color, size: 26),
            ),

            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target.label,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize:   15,
                      fontWeight: FontWeight.w700,
                      color:      isDisabled ? _kGrey : _kWhite,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _sublabel(target.mode),
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize:   11,
                      color:      isDisabled ? _kGrey.withOpacity(0.5) : _kGrey,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow or spinner
            if (!isSwitching)
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isDisabled ? _kGrey.withOpacity(0.3) : color.withOpacity(0.7),
                size:  16,
              ),
          ],
        ),
      ),
    );
  }

  String _sublabel(String mode) {
    switch (mode) {
      case 'PASSENGER':      return 'Book rides and use all passenger features';
      case 'DRIVER':         return 'Go online and receive trip requests';
      case 'DELIVERY_AGENT': return 'Go online and receive delivery jobs';
      default:               return '';
    }
  }
}

// ─── Loading body ─────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: CircularProgressIndicator(color: _kGold, strokeWidth: 2),
      ),
    );
  }
}

// ─── No targets body (shown for PASSENGER — should never be reached
//     if the calling screen checks before showing the button) ──────────

class _NoTargetsBody extends StatelessWidget {
  const _NoTargetsBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin:      const EdgeInsets.symmetric(vertical: 12),
              width: 40,   height: 4,
              decoration:  BoxDecoration(
                color:        Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('🚫', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            'No modes available',
            style: TextStyle(
              fontFamily: 'LeagueSpartan',
              fontSize:   18,
              fontWeight: FontWeight.w700,
              color:      _kWhite,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your account type does not support mode switching.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize:   13,
              color:      _kGrey,
            ),
          ),
        ],
      ),
    );
  }
}