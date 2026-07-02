import '../core/app_settings.dart';

/// Lightweight i18n: `tr('key')` returns the French (default) or English
/// string depending on AppSettings. Unknown keys fall back to the key itself
/// so a missing translation can never crash or blank a screen.
///
/// Screens are migrated to `tr()` progressively — hardcoded French strings
/// keep working untouched until they are keyed.
String tr(String key) {
  final en = AppSettings.instance.lang == 'en';
  final table = en ? _en : _fr;
  return table[key] ?? _fr[key] ?? key;
}

const Map<String, String> _fr = {
  // ── Navigation ──
  'nav.home': 'Accueil',
  'nav.activity': 'Activité',
  'nav.account': 'Compte',

  // ── Common ──
  'common.ok': 'OK',
  'common.cancel': 'Annuler',
  'common.confirm': 'Confirmer',
  'common.save': 'Enregistrer',
  'common.retry': 'Réessayer',
  'common.close': 'Fermer',
  'common.yes': 'Oui',
  'common.no': 'Non',
  'common.loading': 'Chargement...',
  'common.error': 'Une erreur est survenue. Veuillez réessayer.',

  // ── Profile / Settings ──
  'profile.title': 'Profil',
  'profile.account': 'Compte',
  'profile.settings': 'Paramètres',
  'profile.editProfile': 'Modifier le profil',
  'profile.changePassword': 'Changer le mot de passe',
  'profile.notifications': 'Notifications',
  'profile.privacy': 'Confidentialité',
  'profile.language': 'Langue',
  'profile.language.fr': 'Français',
  'profile.language.en': 'English',
  'profile.darkMode': 'Mode sombre',
  'profile.darkMode.subtitle': 'Interface noire et or',
  'profile.help': 'Aide',
  'profile.support': 'Assistance',
  'profile.reportBug': 'Signaler un problème',
  'profile.logout': 'Déconnexion',
  'profile.logout.confirm': 'Voulez-vous vraiment vous déconnecter ?',
  'profile.deleteAccount': 'Supprimer le compte',
  'profile.switchMode': 'Changer de mode',
  'profile.applying': 'Application...',

  // ── Ride ──
  'ride.planTrip': 'Planifiez votre course',
  'ride.whereTo': 'Où allez-vous ?',
  'ride.pickup': 'Départ',
  'ride.destination': 'Destination',
  'ride.searchingDriver': 'Recherche d\'un chauffeur...',
  'ride.driverFound': 'Chauffeur trouvé !',
  'ride.driverArriving': 'Votre chauffeur arrive',
  'ride.driverArrived': 'Votre chauffeur est arrivé',
  'ride.tripInProgress': 'Course en cours',
  'ride.tripCompleted': 'Course terminée',
  'ride.cancelRide': 'Annuler la course',
  'ride.promoQuestion': 'Vous avez un code promo ?',
  'ride.promoApply': 'Appliquer',
  'ride.promoRemove': 'Retirer',
  'ride.orderRide': 'Commander',

  // ── Wallet / Payments ──
  'wallet.title': 'Portefeuille',
  'wallet.balance': 'Solde',
  'wallet.topUp': 'Recharger',
  'payment.cash': 'Espèces',
  'payment.title': 'Mode de paiement',
};

const Map<String, String> _en = {
  // ── Navigation ──
  'nav.home': 'Home',
  'nav.activity': 'Activity',
  'nav.account': 'Account',

  // ── Common ──
  'common.ok': 'OK',
  'common.cancel': 'Cancel',
  'common.confirm': 'Confirm',
  'common.save': 'Save',
  'common.retry': 'Retry',
  'common.close': 'Close',
  'common.yes': 'Yes',
  'common.no': 'No',
  'common.loading': 'Loading...',
  'common.error': 'Something went wrong. Please try again.',

  // ── Profile / Settings ──
  'profile.title': 'Profile',
  'profile.account': 'Account',
  'profile.settings': 'Settings',
  'profile.editProfile': 'Edit profile',
  'profile.changePassword': 'Change password',
  'profile.notifications': 'Notifications',
  'profile.privacy': 'Privacy',
  'profile.language': 'Language',
  'profile.language.fr': 'Français',
  'profile.language.en': 'English',
  'profile.darkMode': 'Dark mode',
  'profile.darkMode.subtitle': 'Black and gold interface',
  'profile.help': 'Help',
  'profile.support': 'Support',
  'profile.reportBug': 'Report a problem',
  'profile.logout': 'Log out',
  'profile.logout.confirm': 'Are you sure you want to log out?',
  'profile.deleteAccount': 'Delete account',
  'profile.switchMode': 'Switch mode',
  'profile.applying': 'Applying...',

  // ── Ride ──
  'ride.planTrip': 'Plan your trip',
  'ride.whereTo': 'Where to?',
  'ride.pickup': 'Pickup',
  'ride.destination': 'Destination',
  'ride.searchingDriver': 'Searching for a driver...',
  'ride.driverFound': 'Driver found!',
  'ride.driverArriving': 'Your driver is arriving',
  'ride.driverArrived': 'Your driver has arrived',
  'ride.tripInProgress': 'Trip in progress',
  'ride.tripCompleted': 'Trip completed',
  'ride.cancelRide': 'Cancel ride',
  'ride.promoQuestion': 'Have a promo code?',
  'ride.promoApply': 'Apply',
  'ride.promoRemove': 'Remove',
  'ride.orderRide': 'Order',

  // ── Wallet / Payments ──
  'wallet.title': 'Wallet',
  'wallet.balance': 'Balance',
  'wallet.topUp': 'Top up',
  'payment.cash': 'Cash',
  'payment.title': 'Payment method',
};
