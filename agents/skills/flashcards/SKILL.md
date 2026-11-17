---
name: flashcards
description: Use this skill only when the user explicitly asks for /flashcards or flashcards. Creates 3 to 5 Logseq #card flashcards about the current project, each backed by proof (file:line or official doc), then syncs with sb-sync.
---

# flashcards : cartes mémoire Logseq vérifiées

À la demande uniquement. Ne jamais en générer de façon proactive.

## Interdits
- Ne jamais traiter `Balise`, `SelfLlama`, `MyLittleAnsible`, `Velaluna`, `AirAlert`, `ETNAir`, `ancient-portfolio`.
- Aucune carte sans preuve. Si tu ne peux pas citer `fichier:ligne` (relu dans le dépôt) ou une doc officielle consultée, n'écris pas la carte.
- Ne pas expliquer une cause que tu n'as pas vérifiée (écris "cause non vérifiée").
- Vérifier avec `grep -rn` que la carte n'existe pas déjà dans `second-brain`.

## Étapes
1. Choisir 3 à 5 notions du projet courant (commande, choix d'architecture, piège de sécurité/DevOps).
2. Pour chacune, ouvrir le code et noter la preuve.
3. Ajouter dans `pages/<Projet>.md`, section `Cartes mémoire`, ou dans le journal du jour :
   ```
   - Question courte #card #tag-technique
   \t- Réponse précise
   \t- Preuve : `fichier:ligne`
   ```
4. Terminer par `sb-sync <Projet>`.

## Format
- Tabulations uniquement, un seul `- ` par bloc, la réponse en bloc enfant.
