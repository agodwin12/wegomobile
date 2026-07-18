import '../core/app_settings.dart';

/// Lightweight i18n: `tr('key')` returns the French (default) or English
/// string depending on AppSettings. Unknown keys fall back to the key itself
/// so a missing translation can never crash or blank a screen.
///
/// Screens are migrated to `tr()` progressively — hardcoded French strings
/// keep working untouched until they are keyed.
String tr(String key, [Map<String, String>? params]) {
  final en = AppSettings.instance.lang == 'en';
  final table = en ? _en : _fr;
  var s = table[key] ?? _fr[key] ?? key;
  if (params != null) {
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
  }
  return s;
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

  // ── Home service picker ──
  'home.ride': 'Course',
  'home.rental': 'Location',
  'home.delivery': 'Livraison',
  'home.services': 'Services',
  'home.rideNow': 'Commander une course',

  // ── Wallet / Payments ──
  'wallet.title': 'Portefeuille',
  'wallet.balance': 'Solde',
  'wallet.topUp': 'Recharger',
  'payment.cash': 'Espèces',
  'payment.title': 'Mode de paiement',

  // ── Roles ──
  'role.passenger': 'Passager',
  'role.driver': 'Chauffeur',
  'role.user': 'Utilisateur',

  // ── Auth / Login ──
  'auth.welcomeBack': 'Bon retour',
  'auth.enterCredentials': 'Veuillez saisir vos identifiants',
  'auth.email': 'Adresse e-mail',
  'auth.phone': 'Numéro de téléphone',
  'auth.password': 'Mot de passe',
  'auth.enterPassword': 'Saisissez votre mot de passe',
  'auth.forgotPassword': 'Mot de passe oublié ?',
  'auth.rememberMe': 'Se souvenir de moi',
  'auth.signIn': 'Se connecter',
  'auth.continueGoogle': 'Continuer avec Google',
  'auth.newHere': 'Nouveau ici ? ',
  'auth.usePhone': 'Utiliser le téléphone',
  'auth.useEmail': "Utiliser l'e-mail",
  'auth.selectCountry': 'Choisir le pays',
  'auth.yourRideYourWay': 'Votre course, à votre façon',
  'auth.bookRides': 'Réservez des courses et voyagez confortablement',
  'auth.driveEarn': "Conduisez, livrez et gagnez de l'argent",
  'auth.welcomeToast': 'Bon retour, {name} ! 👋',
  'auth.err.noInternet': 'Pas de connexion Internet',
  'auth.err.timeout': 'Délai dépassé. Vérifiez votre connexion.',
  'auth.err.server': 'Erreur du serveur. Veuillez réessayer.',
  'auth.err.loginFailed': 'Échec de la connexion. Veuillez réessayer.',
  'auth.err.invalidResponse': 'Réponse invalide du serveur.',
  'auth.err.invalidUserData': 'Données utilisateur invalides reçues du serveur',
  'auth.err.googleFailed': 'La connexion Google a échoué. Veuillez réessayer.',
  'auth.err.googlePassengersOnly': 'La connexion Google est réservée aux passagers.',

  // ── Home / dashboard ──
  'common.seeAll': 'Tout voir',
  'common.comingSoon': '{feature} bientôt disponible',
  'home.gettingLocation': 'Localisation…',
  'home.enterDestination': 'Saisissez votre destination',
  'home.go': 'Aller →',
  'home.savedPlaces': 'Lieux enregistrés',
  'home.offers': 'Offres',
  'home.claim': 'Réclamer',
  'home.recentTrips': 'Courses récentes',
  'home.safetyTitle': 'Votre sécurité compte',
  'home.safetySubtitle': 'Assistance 24/7 · Suivi en temps réel',
  'trip.status.completed': 'Terminé',
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

  // ── Home service picker ──
  'home.ride': 'Ride',
  'home.rental': 'Rental',
  'home.delivery': 'Delivery',
  'home.services': 'Services',
  'home.rideNow': 'Order a ride',

  // ── Wallet / Payments ──
  'wallet.title': 'Wallet',
  'wallet.balance': 'Balance',
  'wallet.topUp': 'Top up',
  'payment.cash': 'Cash',
  'payment.title': 'Payment method',

  // ── Roles ──
  'role.passenger': 'Passenger',
  'role.driver': 'Driver',
  'role.user': 'User',

  // ── Auth / Login ──
  'auth.welcomeBack': 'Welcome back',
  'auth.enterCredentials': 'Please enter your credentials',
  'auth.email': 'Email Address',
  'auth.phone': 'Phone Number',
  'auth.password': 'Password',
  'auth.enterPassword': 'Enter your password',
  'auth.forgotPassword': 'Forgot password?',
  'auth.rememberMe': 'Remember me',
  'auth.signIn': 'Sign In',
  'auth.continueGoogle': 'Continue with Google',
  'auth.newHere': 'New here? ',
  'auth.usePhone': 'Use phone instead',
  'auth.useEmail': 'Use email instead',
  'auth.selectCountry': 'Select Country',
  'auth.yourRideYourWay': 'Your ride, your way',
  'auth.bookRides': 'Book rides and travel comfortably',
  'auth.driveEarn': 'Drive, deliver and earn money',
  'auth.welcomeToast': 'Welcome back, {name}! 👋',
  'auth.err.noInternet': 'No internet connection',
  'auth.err.timeout': 'Request timeout. Check your connection.',
  'auth.err.server': 'Server error. Please try again.',
  'auth.err.loginFailed': 'Login failed. Please try again.',
  'auth.err.invalidResponse': 'Invalid response from server.',
  'auth.err.invalidUserData': 'Invalid user data received from server',
  'auth.err.googleFailed': 'Google sign-in failed. Please try again.',
  'auth.err.googlePassengersOnly': 'Google sign-in is available for passengers only.',

  // ── Home / dashboard ──
  'common.seeAll': 'See all',
  'common.comingSoon': '{feature} coming soon',
  'home.gettingLocation': 'Getting location…',
  'home.enterDestination': 'Enter your destination',
  'home.go': 'Go →',
  'home.savedPlaces': 'Saved places',
  'home.offers': 'Offers',
  'home.claim': 'Claim',
  'home.recentTrips': 'Recent trips',
  'home.safetyTitle': 'Your safety matters',
  'home.safetySubtitle': '24/7 support · Real-time tracking',
  'trip.status.completed': 'Completed',
};
