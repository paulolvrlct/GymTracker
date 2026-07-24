# Politique de confidentialité : LiftRun

*Dernière mise à jour : 24 juillet 2026*

## En résumé

**LiftRun ne collecte aucune donnée.** Tout ce que tu enregistres dans l'application — séances de musculation, courses, tracés GPS, profil (prénom, taille, poids, sexe) — est stocké **uniquement sur ton appareil**. Aucun compte n'est requis, aucun serveur ne reçoit tes données, aucun traceur publicitaire n'est intégré.

La seule information qui sort de l'appareil est le **code-barres** que tu choisis de scanner, envoyé à Open Food Facts pour retrouver le produit (voir « Scan de code-barres » plus bas). Il n'est accompagné d'aucune donnée personnelle.

## Données traitées localement

| Donnée | Usage | Où elle est stockée |
|---|---|---|
| Séances, séries, poids soulevés | Historique et courbes de progression | Sur l'appareil (base locale) |
| Courses : distance, durée, tracé GPS | Historique, carte du parcours, allure | Sur l'appareil (base locale) |
| Profil : prénom, âge, taille, poids, sexe | Personnalisation, calcul des besoins caloriques | Sur l'appareil (préférences locales) |
| Journal alimentaire et objectif nutritionnel | Suivi calories et macros (fonction Premium) | Sur l'appareil (base locale) |
| Produits scannés (nom, valeurs nutritionnelles) | Éviter de réinterroger le réseau au prochain scan | Sur l'appareil (cache local) |

Ces données ne quittent jamais ton appareil, sauf si **toi-même** tu exportes une course au format GPX et la partages.

## Localisation

L'application demande l'accès à ta position **uniquement** pour le mode course : afficher ta position sur la carte, mesurer ta distance et ton allure, et tracer ton parcours — y compris écran verrouillé pendant une course active. La position n'est **jamais transmise** à quiconque ; le tracé est enregistré localement. Tu peux révoquer cet accès à tout moment dans Réglages → Confidentialité → Service de localisation.

## Connexions réseau

L'application fonctionne hors ligne pour l'essentiel. Les seules connexions sortantes sont :
- le **fond de carte Apple Plans** (mode course), régi par la [politique de confidentialité d'Apple](https://www.apple.com/legal/privacy/) ;
- le chargement à la demande des **photos d'exercices** depuis le dépôt public Free Exercise DB (GitHub) ;
- l'interrogation d'**Open Food Facts** lorsque tu scannes un code-barres (voir ci-dessous).

Aucune donnée personnelle n'accompagne ces requêtes : ni identifiant, ni profil, ni historique.

## Scan de code-barres

Quand tu scannes le code-barres d'un produit, LiftRun envoie **uniquement ce code-barres** à [Open Food Facts](https://world.openfoodfacts.org), base de données publique et collaborative, pour récupérer le nom du produit et ses valeurs nutritionnelles. Aucune information sur toi n'est transmise, et Open Food Facts ne reçoit aucun moyen de t'identifier.

Le résultat est ensuite **conservé localement** sur ton appareil afin qu'un produit déjà scanné puisse être retrouvé sans connexion. Les données d'Open Food Facts sont publiées sous licence ODbL et régies par leur [politique de confidentialité](https://world.openfoodfacts.org/privacy).

## Caméra

L'accès à la caméra sert **exclusivement** à lire un code-barres au moment où tu ouvres le scanner. Aucune photo ni vidéo n'est enregistrée, stockée ou transmise : l'image est analysée en direct sur l'appareil puis abandonnée. Tu peux refuser ou révoquer cet accès à tout moment dans Réglages → Confidentialité et sécurité → Appareil photo ; l'application reste utilisable, la saisie des aliments se faisant alors manuellement.

## Apple Santé

Avec ton autorisation explicite, LiftRun peut **écrire** dans Apple Santé : tes séances et courses (entraînements, calories, distance) et ton journal alimentaire (énergie, protéines, glucides, lipides). Supprimer une entrée dans LiftRun supprime aussi les données Santé associées.

LiftRun peut également **lire** une seule donnée, ton **poids**, et uniquement lorsque tu le demandes explicitement en touchant « Importer mon poids depuis Santé » dans ton profil. Cette valeur sert à pré-remplir ton profil et reste sur l'appareil.

Tu peux gérer ou révoquer ces accès à tout moment dans Réglages → Confidentialité et sécurité → Santé → LiftRun. Les données Santé sont gérées par Apple selon sa [politique de confidentialité](https://www.apple.com/legal/privacy/).

## Achats intégrés

L'éventuel achat « LiftRun Premium » est traité intégralement par Apple (App Store). L'application ne voit ni ne stocke aucune information de paiement.

## Notifications

Les notifications (fin du temps de repos) sont programmées **localement** sur l'appareil. Aucun push distant n'est utilisé.

## Suppression des données

Supprimer l'application supprime l'intégralité des données. Tu peux aussi supprimer individuellement séances et courses depuis l'application.

## Contact

Pour toute question : [pololivierlecourt@gmail.com](mailto:pololivierlecourt@gmail.com)
