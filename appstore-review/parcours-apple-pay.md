# Démonstration Apple Pay — App Store

Compte client déjà fourni à Apple : cherkinicolas2@gmail.com (mot de passe inchangé).
Prestataire utilisé avec accord : Nico.

1. Se connecter avec le compte client.
2. Ouvrir **Messages**, dans les conversations en cours.
3. Ouvrir la conversation avec **Nico**, intitulée **Démonstration Apple Pay — App Store**.
4. La demande de 1 € est déjà acceptée. Toucher **Payer 1,00 € · Démonstration Apple Pay — App Store**.
5. Le formulaire Stripe s’ouvre et propose Apple Pay selon la configuration de l’appareil.
6. Fermer le formulaire sans confirmer de paiement.

Ce parcours utilise le mode réel du build existant. Il sert à vérifier l’accès au formulaire : aucune confirmation Apple Pay, autorisation de carte ou capture de paiement n’a été effectuée lors de la préparation. Une confirmation par le testeur pourrait autoriser 1 €.

Vérifications effectuées : connexion du compte client, accès à la conversation sous ses propres permissions, statut de conversation `accepted`, demande `pending`, montant 100 centimes, message d’acceptation présent, création réussie du PaymentIntent par le backend de l’app.

La conversation n’est pas clôturée (`status != completed`).

## Réponse préparée pour Apple (à transmettre dans App Store Connect)

Bonjour,

Nous avons préparé le parcours pour le compte de démonstration déjà fourni : cherkinicolas2@gmail.com, avec le même mot de passe.

Après connexion, ouvrez Messages (conversations en cours), puis la conversation avec Nico intitulée « Démonstration Apple Pay — App Store ». Une demande de 1 € est déjà acceptée : il suffit de toucher « Payer 1,00 € » pour ouvrir le formulaire Stripe et consulter Apple Pay si disponible sur l’appareil. Aucune nouvelle demande ni acceptation n’est nécessaire.

Il s’agit du mode réel : pour cette démonstration, veuillez fermer le formulaire après avoir vérifié la présence d’Apple Pay, sans confirmer le paiement.

Cordialement.
