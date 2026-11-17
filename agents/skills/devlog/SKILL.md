---
name: devlog
description: Use this skill when the user asks for /devlog or a daily dev journal entry. Analyses the git activity of the current project and writes a factual narrative into the Logseq journal of the day (second-brain), then syncs it with sb-sync.
---

# devlog : récit du jour dans le journal Logseq

Graphe : `/mnt/samsung4To/Dev/second-brain`. Journal : `journals/AAAA_MM_JJ.md`. Pages projet : `pages/<Projet>.md`.

## Interdits
- Ne jamais analyser ni écrire sur `Balise`, `SelfLlama`, `MyLittleAnsible`, `Velaluna`, `AirAlert`, `ETNAir`, `ancient-portfolio`.
- Ne jamais écrire de `DONE` dans un journal. L'historique vit dans `git log` et les releases.
- Ne jamais présenter une supposition comme un fait. Si un point n'est pas vérifiable dans le code ou `git`, l'écrire explicitement ("non vérifié").

## Étapes
1. Projet = dossier racine git courant. Date du jour : `date +%Y_%m_%d`.
2. Collecter : `git status -sb`, `git log --since=midnight --format='%h %ad %s' --date=iso`, `git diff --stat`. Sans commit du jour, regarder `git log -n 10` en le disant.
3. Rédiger le récit : état du dépôt, ce qui s'est réellement passé aujourd'hui (uniquement des commits/diffs datés du jour), décisions et leur raison.
4. Écrire dans le journal sous `- [[Projet]] #devlog` (créer le fichier ou compléter la section existante sans écraser le reste).
5. Les tâches à venir vont dans `pages/<Projet>.md` (section Feuille de route), **jamais** dans le journal : une seule source pour les TODO. Vérifier qu'un TODO n'existe pas déjà avant d'en ajouter.
6. Terminer par `sb-sync <Projet>`.

## Format Logseq
- Puces à tabulations uniquement (`\t- `), jamais d'espaces, jamais `- - `.
- Tâches natives : `- TODO ...`, `- DOING ...` (un seul `- ` en début de bloc).
- Propriétés : `cle:: valeur`. Liens `[[Projet]]`, tags `#devlog #architecture #bugfix #devops #securite`.
- Pas de paragraphe sans puce. Admonitions `#+BEGIN_WARNING` / `#+END_WARNING` pour les pièges avérés.
