# Espace client — instructions Claude Code

Portail où les clients de BG Informatique déposent et suivent leurs demandes de
modification de site. Dépôt **public** (GitHub Pages), servi sur
**https://clients.bginformatique.ca**.

## Déploiement — deux voies SÉPARÉES

**Le site** (HTML, CSS, JS) :
```
./deploy.sh "message"
```
Commit + push sur `main`, d'où GitHub Pages publie. Ne jamais faire `git commit`
ni `git push` à la main — toujours passer par `./deploy.sh`.

**Les règles et index Firestore** (fichiers `firestore.rules`,
`firestore.indexes.json`), vers le projet `websitemaestro-872c7` :
```
firebase deploy --only firestore
```
Firebase ne lit pas ce dépôt et GitHub Pages ne lit pas `firestore.rules` : les
deux commandes sont indépendantes. Après toute modification des règles, publier
par la CLI, puis vérifier au simulateur (voir LISEZ-MOI.md).

## Ce qui ne doit JAMAIS entrer dans ce dépôt

- **Aucune clé de compte de service, aucun secret.** Le secret client Entra et
  les clés Firebase vivent dans le gestionnaire de mots de passe et
  `~/.config/bg-lanceur/` sur BG001 — jamais ici. `deploy.sh` et `.gitignore`
  refusent déjà les motifs connus, mais la vraie garde, c'est de ne pas les
  amener.
- `firebase-config.js` ne contient que les valeurs **publiques** de l'app web —
  c'est normal, elles partent dans chaque navigateur. Ce qui protège les
  données, ce sont les règles Firestore et l'authentification, pas ce fichier.

## Rappels de conception (ne pas défaire sans raison)

- **Deux projets Firebase, un pont.** Ce portail parle à `websitemaestro-872c7`
  (les clients). Les outils internes de Jérémie sont sur `bgtimecalculator`. Les
  comptes clients n'existent PAS dans le projet interne — c'est voulu. Le lien
  entre les deux est `pont_clients.py` sur BG001, pas une règle inter-utilisateurs.
- **Le verrou d'accès est dans Entra ID** (« locataire unique » + invitation),
  pas dans les règles Firestore. Ne pas chercher à le reproduire côté règles.
- **Chemins relatifs seulement.** Le portail tourne à la racine du sous-domaine ;
  ne pas introduire de chemin absolu commençant par `/`.
