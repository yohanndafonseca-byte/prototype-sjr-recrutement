#!/usr/bin/env bash
# Corrige le libellé de la case agent/fonctionnaire.
# "...de la Ville de Saint-Jean-de-la-Ruelle" -> "...titulaire en collectivité"
# À lancer à la racine du projet.
set -e

f="app/components/ApplyForm.js"

sed -i 's#Je suis déjà agent / fonctionnaire de la Ville de Saint-Jean-de-la-Ruelle#Je suis déjà agent / fonctionnaire titulaire en collectivité#' "$f"

echo "=== Vérification ==="
grep -n "Je suis déjà" "$f"
echo ""
echo "=== OK. Lance ensuite : npm run build, puis git add/commit/push ==="
