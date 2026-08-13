#!/bin/bash
# ==========================================================
#  Espace client — déploiement du PORTAIL (GitHub Pages)
#  Usage : ./deploy.sh ["message de commit optionnel"]
#
#  Publie tout le dépôt sur main, d'où GitHub Pages sert
#  https://clients.bginformatique.ca. 100 % non-interactif.
#
#  ATTENTION : ceci ne déploie QUE le site. Les règles et
#  index Firestore vont sur le projet websitemaestro-872c7
#  par une commande SÉPARÉE :
#      firebase deploy --only firestore
#  Firebase ne lit pas ce dépôt ; GitHub Pages ne lit pas
#  firestore.rules. Les deux mondes ne se croisent jamais.
# ==========================================================

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

# Domaine lu depuis CNAME
if [ -f "CNAME" ]; then
  DOMAIN=$(tr -d '[:space:]' < CNAME)
else
  DOMAIN="clients.bginformatique.ca"
fi

echo -e "${GREEN}─── Déploiement de l'espace client ───${NC}"

if [ ! -d ".git" ]; then
  echo -e "${RED}Erreur : ce dossier n'est pas un dépôt git.${NC}"
  exit 1
fi

if [ -z "$(git status --porcelain)" ]; then
  # Arbre propre — mais une publication précédente a pu laisser un commit
  # local jamais poussé. On vérifie avant de conclure « rien à faire ».
  if git rev-parse --verify -q origin/main >/dev/null 2>&1 \
     && [ -n "$(git rev-list origin/main..HEAD 2>/dev/null)" ]; then
    echo -e "${YELLOW}Un commit déjà enregistré attend d'être publié — reprise...${NC}"
  else
    echo -e "${YELLOW}Aucune modification à publier. Rien à faire.${NC}"
    exit 0
  fi
else
  echo -e "${BLUE}Fichiers modifiés :${NC}"
  git status --short

  # ── Anti-cache : forcer le navigateur à recharger css/js après un changement.
  #    Le portail sert le même chemin à chaque déploiement ; sans nouveau « ?v= »,
  #    un client peut garder l'ancienne feuille de style ou l'ancienne logique.
  #    On ne re-tamponne QUE s'il y a un vrai changement à publier (dans ce bloc).
  if [ -f "index.html" ]; then
    STAMP="$(date +%Y%m%d%H%M%S)"
    sed -i -E \
      -e "s#(css/style\.css\?v=)[0-9]+#\1${STAMP}#g" \
      -e "s#(js/app\.js\?v=)[0-9]+#\1${STAMP}#g" \
      index.html
    echo -e "${BLUE}Assets versionnés : v=${STAMP}${NC}"
  fi

  git add -A

  # ── Garde-fous : ce qui n'a jamais sa place dans un dépôt public ───────────
  #    Vérifié APRÈS « git add -A » : l'index dit exactement ce qui partirait.
  #    En cas de refus, « git reset » remet tout comme avant, rien n'est perdu.
  REFUS=0
  while IFS= read -r -d '' FICHIER; do
    BASE="$(basename "$FICHIER")"
    case "$BASE" in
      .env|.env.*|*.pem|*.key|*.p12|*.pfx|id_rsa|id_rsa.*|id_ed25519|id_ed25519.*|\
      cle-sa*.json|*service-account*.json|*credentials*.json)
        echo -e "${RED}  ✗ ${FICHIER} — clé ou secret : jamais dans ce dépôt public.${NC}"
        REFUS=1 ;;
    esac
    if [ -f "$FICHIER" ]; then
      TAILLE=$(stat -c%s "$FICHIER" 2>/dev/null || echo 0)
      if [ "$TAILLE" -gt 26214400 ]; then
        echo -e "${RED}  ✗ ${FICHIER} — $((TAILLE / 1048576)) Mo, trop lourd pour une page.${NC}"
        REFUS=1
      fi
    fi
  done < <(git diff --cached --name-only -z)

  # Dépôt git imbriqué : deviendrait un dossier vide en ligne.
  IMBRIQUES="$(git ls-files --stage | awk '$1 == "160000" {print $4}')"
  if [ -n "$IMBRIQUES" ]; then
    echo -e "${RED}  ✗ ${IMBRIQUES} — dépôt git imbriqué.${NC}"
    REFUS=1
  fi

  if [ "$REFUS" -eq 1 ]; then
    git reset >/dev/null
    echo
    echo -e "${RED}Publication annulée — rien n'a été envoyé. L'arbre est intact.${NC}"
    exit 1
  fi

  if [ $# -gt 0 ]; then
    COMMIT_MSG="$1"
  else
    COMMIT_MSG="Espace client - $(date +'%Y-%m-%d %H:%M:%S')"
  fi
  echo -e "${BLUE}Commit : ${COMMIT_MSG}${NC}"
  git commit -m "$COMMIT_MSG"
fi

# Publier sur main, peu importe la branche de travail.
echo -e "${BLUE}Publication sur main...${NC}"
if ! git push origin HEAD:main; then
  echo -e "${YELLOW}Publication refusée du premier coup — synchronisation...${NC}"
  if ! git fetch origin main; then
    echo -e "${RED}GitHub injoignable (réseau ?). Rien n'est perdu. Relancez plus tard.${NC}"
    exit 1
  fi
  if git -c rebase.autoStash=true rebase -X theirs origin/main; then
    git push origin HEAD:main
  else
    git rebase --abort >/dev/null 2>&1 || true
    echo -e "${RED}Synchronisation impossible automatiquement. Rien n'est perdu. Relancez plus tard.${NC}"
    exit 1
  fi
fi

echo -e "${GREEN}─── Succès ! ───${NC}"
echo -e "${GREEN}En ligne sur https://${DOMAIN} dans 1 à 2 minutes.${NC}"
