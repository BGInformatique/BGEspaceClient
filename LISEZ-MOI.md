# Espace client

**https://clients.bginformatique.ca** — dépôt public, `noindex, nofollow`,
absent de tout sitemap. Ce n'est pas une page cachée comme les outils internes :
les clients doivent pouvoir la retrouver. Elle est simplement privée derrière la
connexion Microsoft.

Le client se connecte avec le compte Microsoft auquel il a été **invité**, écrit
ses demandes de modification, et en suit l'avancement. BG Informatique les lit
dans un outil séparé et décide quand les lancer.

> **Ce dépôt ne contient QUE le portail.** Il a été détaché du dépôt du site
> (`bginformatique-site`) pour que la ligne « sites clients » soit indépendante
> des outils internes. Le seul lien restant sur `bginformatique.ca` est une page
> de redirection vers ce sous-domaine — voir « Le point commun » plus bas.

---

## Le chemin complet d'une demande

```
Client → clients.bginformatique.ca ────▶ projet Firebase CLIENTS
                                         demandes/<id>   statut « recue »
                                                  │
                             pont_clients.py (BG001, toutes les 5 min)
                                                  ▼
                              projet INTERNE  users/<uid>/clientsweb/state
                                                  │
                        outils/dw-6r2v8k/  ← Jérémie lit, décide, ⚡
                                                  ▼
                              users/<uid>/clientsweb/lancement-<…>
                                                  │
                                    lanceur.py (BG001)
                                                  ▼
                    claude -p  dans  SitesWebClient/<NomDuClient>/
                                                  │
                                    ./deploy.sh  →  site du client en ligne
                                                  │
                              pont ──▶ demandes/<id>  statut « en_ligne »
                                                  ▼
                                     Le client voit « En ligne »
```

**Rien ne part sur le site d'un client sans que quelqu'un ait lu la demande et
appuyé sur l'éclair.** C'est le point de la conception, pas une étape en trop :
une demande mal comprise appliquée pendant une absence casse un site que
personne ne surveille.

---

## Pourquoi deux projets Firebase

| | Projet | Qui s'y connecte |
|---|---|---|
| Outils internes | `bgtimecalculator` | Jérémie seulement |
| Espace client | `websitemaestro-872c7` | les clients invités |

Les comptes clients n'existent pas dans le projet qui porte la feuille de temps
et le tableau de bord marketing. Ce n'est pas une question de règles bien
écrites : c'est qu'il n'y a **rien à atteindre**.

Le prix de ce cloisonnement : BG001 a deux identités (deux comptes de service)
et un pont pour relier les deux mondes. C'est `pont_clients.py`.

Conséquence heureuse : la vue de Jérémie reste une lecture `users/<son-uid>/…`,
donc la même règle éprouvée que ses autres outils. **Aucune règle
inter-utilisateurs n'existe nulle part**, et le principe d'anti-verrouillage des
outils internes reste entier.

---

## État de l'installation

Le projet Firebase, l'app web, la connexion Microsoft et les règles sont **déjà
en place** (montés le 2026-08-13). Ce qui reste à activer est **côté
propriétaire seulement** :

- **Inviter un client** — Entra ID → Utilisateurs → Inviter un utilisateur
  externe. Récupérer ensuite son **UID Firebase** (Authentication → Users, après
  sa première connexion).
- **Le pont sur BG001** — remplir `~/.config/bg-lanceur/clients-web.json`
  (`projet_clients` = `websitemaestro-872c7`, une entrée UID → dossier par
  client), déposer la clé de compte de service en
  `~/.config/bg-lanceur/cle-sa-clients.json` (rôle `datastore.user`, `chmod 600`),
  puis installer `bg-pont-clients.service`. Essai à blanc d'abord :
  `python3 ~/"Bureau/BG Informatique/Claude_Lanceur/pont_clients.py" --essai`.
- **Le lanceur** connaît déjà `clientsweb` dans ses collections ; le redémarrer
  quand rien ne tourne : `systemctl --user restart bg-lanceur.service`.

Le verrou d'accès tient dans Entra ID (« locataire unique » + invitation), pas
dans les règles Firestore : le paramètre `tenant` part vers Microsoft et n'entre
pas dans le jeton Firebase.

---

## Déployer

Deux voies indépendantes — Firebase ne lit pas ce dépôt, GitHub Pages ne lit pas
`firestore.rules`.

**Le portail** (site) :
```
./deploy.sh "message"
```
Commit + push sur `main`, GitHub Pages publie sur `clients.bginformatique.ca` en
1 à 2 minutes. Le script re-tamponne les `?v=` des assets, refuse toute clé ou
secret, tout fichier de plus de 25 Mo, tout dépôt imbriqué.

**Les règles et index Firestore**, vers `websitemaestro-872c7` :
```
firebase deploy --only firestore
```
Avant de publier une modification de règles, le **simulateur** — cinq essais :

| Opération | Chemin | Attendu |
|---|---|---|
| `create` comme uid A, avec `clientUid: A` et `statut: "recue"` | `demandes/x` | **autorisé** |
| `create` comme uid A avec `clientUid: B` | `demandes/x` | **refusé** |
| `create` comme uid A avec `statut: "en_ligne"` | `demandes/x` | **refusé** |
| `get` comme uid B sur un document de A | `demandes/x` | **refusé** |
| `get` non authentifié | `demandes/x` | **refusé** |

Si un essai « autorisé » échoue, ou si un « refusé » passe : ne pas publier. Le
retour arrière tient en une minute : console → Règles → historique des versions.

---

## Le point commun avec bginformatique.ca

Chaque `demande.html` déposé chez un client pointe vers
`bginformatique.ca/espace-client/`. Cette URL reste vivante : c'est une page de
**redirection** vers `clients.bginformatique.ca`. Ainsi le jour où le portail
redéménage, on change *une* page sur l'apex et tous les sites clients suivent —
aucun dépôt client à modifier. C'est le seul fil entre ce portail et le reste.

---

## Domaines autorisés (Firebase)

Un seul domaine doit pouvoir lancer la connexion : `clients.bginformatique.ca`
(console → Authentication → Settings → Domaines autorisés). Tout domaine inconnu
laissé dans la liste permettrait à un clone d'hameçonnage de déclencher la vraie
connexion. `localhost` et `websitemaestro-872c7.firebaseapp.com` y sont par
défaut ; retirer le reste.

---

## Données

Un document par demande, collection racine `demandes` :

```jsonc
{
  "clientUid": "…",        // qui — vérifié par les règles à la création
  "clientNom": "…",
  "clientCourriel": "…",
  "type": "…",             // catégorie choisie dans le menu
  "urgence": "…",
  "page": "…",             // facultatif
  "description": "…",      // le texte du client, ≤ 5000 caractères
  "statut": "recue",       // recue · analyse · en_cours · en_ligne · refusee · annulee
  "creeLe": <timestamp>,
  "reponse": "…"           // écrit par BG001 seulement
}
```

**Le client ne peut poser que les champs de la première moitié.** Le statut
d'avancement et la réponse appartiennent à BG001 : les règles refusent qu'un
navigateur les écrive, et une demande déjà prise en charge ne se modifie plus.

Collection racine plutôt que sous-collection de `users/` : le pont doit lire
toutes les demandes en une requête, sans parcourir les comptes un par un. Le
cloisonnement ne vient donc pas du chemin mais du champ `clientUid`, vérifié à
la création **et** à la lecture.

---

## Ce que cette page ne fait pas

- **Elle n'envoie aucun courriel.** Le suivi remplace l'accusé de réception : le
  client voit son état changer.
- **Elle ne montre jamais la sortie de Claude.** Un résultat de lancement peut
  contenir des chemins, des noms de dépôts, des notes de travail. Le pont
  traduit un statut en phrase fixe ; le seul texte libre qu'un client reçoit est
  celui que Jérémie écrit dans « Marquer à revoir ».
- **Elle ne connaît aucun dépôt.** La table qui relie un compte à un dossier vit
  sur BG001. Une page web ne désigne pas le dépôt sur lequel la machine travaille.
