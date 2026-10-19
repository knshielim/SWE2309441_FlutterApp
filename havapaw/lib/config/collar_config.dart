/// Settings shared between the app and the collar firmware setup.
class CollarConfig {
  CollarConfig._();

  /// HTTPS endpoint of the `ingestCollarData` Cloud Function.
  /// If you deploy the function to another region, change the region part here.
  /// (Deploy with: firebase deploy --only functions,firestore:rules)
  static const String ingestUrl =
      'https://us-central1-havapaw-11e23.cloudfunctions.net/ingestCollarData';
}
