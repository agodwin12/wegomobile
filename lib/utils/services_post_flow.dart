import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/services.dart';

/// Smart "post an ad" entry point.
///
/// If the provider already has an ACTIVE subscription with remaining quota,
/// go straight to the post form — no need to pay/choose a plan again. Otherwise
/// send them to the plan screen first. (createListing is still gated by the
/// active plan on the backend, and activate-free is idempotent, so routing
/// straight to /services/post for an existing subscriber never re-charges.)
Future<void> startServicePostFlow(BuildContext context) async {
  final provider = context.read<ServicesProvider>();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(strokeWidth: 3),
    ),
  );

  Map<String, dynamic>? sub;
  try {
    sub = await provider.getMySubscription();
  } catch (_) {}

  if (context.mounted) Navigator.of(context).pop(); // dismiss loader
  if (!context.mounted) return;

  final active  = sub != null && sub['active'] == true;
  final canPost = sub != null && sub['can_post'] != false;

  await Navigator.pushNamed(
    context,
    (active && canPost) ? '/services/post' : '/services/listing-plan',
  );
}
