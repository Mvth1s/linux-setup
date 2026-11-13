---
description: Analyse l'activité Git du jour sur le projet courant et consigne le compte-rendu dans le journal quotidien Logseq
---

Tu es chargé d'analyser l'activité de développement sur le projet courant et d'enregistrer un compte-rendu structuré dans le journal quotidien Logseq du second cerveau.

Exécute les étapes suivantes avec rigueur :

### 1. Contexte & Informations initiales
- Détermine le nom du projet courant (à partir du dossier racine Git ou du `package.json`).
- Récupère la date du jour au format `AAAA_MM_JJ` (ex. `2026_11_13`).
- Chemin du graphe Logseq : `/mnt/samsung4To/Dev/second-brain`.
- Chemin du journal cible : `/mnt/samsung4To/Dev/second-brain/journals/<AAAA_MM_JJ>.md`.

### 2. Analyse Git
Exécute et analyse les commandes Git suivantes sur le dépôt :
- `git status` : branche active, statut vis-à-vis de l'upstream, fichiers modifiés, indexés ou non suivis.
- `git diff` et `git diff --staged` : analyse des modifications en cours (non commitées).
- `git log` :
  - Examine les commits de la journée : `git log --since="midnight" --date=iso --format="%h %cd %s"`.
  - Si aucun commit n'a été fait aujourd'hui, inspecte les derniers commits récents (`git log -n 10 --date=iso --format="%h %cd %s"`) pour comprendre la dernière session de travail.

### 3. Synthèse structurée
Construis une synthèse concise contenant :
- **État du dépôt** : branche active, propreté de l'arbre de travail (`clean` ou modifications en cours), synchronisation avec l'origine.
- **Travaux récents / Travaux du jour** : commits, PRs mergées, fonctionnalités créées, bugs corrigés, refactoring, documentation ou dépendances.
- **Décisions & Arbitrages** : choix d'architecture, raisons d'un compromis technique, sécurité, ou choix de versions.
- **Prochaines étapes (#todo)** : tâches immédiates à poursuivre, tests à compléter ou prochaines fonctionnalités prévues.

### 4. Formatage et écriture dans Logseq
Applique impérativement les règles du **Second Cerveau (Logseq)** :
- **Hiérarchie stricte** : Chaque niveau doit être une liste à puces indentée avec des tabulations (`\t`) et des tirets (`- `).
  - Niveau 0 : `- [[NomDuProjet]] #devlog`
  - Niveau 1 : `\t- **Section** :: Description`
  - Niveau 2 : `\t\t- Détail ou sous-élément`
- **Liens et tags** :
  - Lien bidirectionnel sur le projet : `[[NomDuProjet]]`.
  - Tags appropriés selon le contenu : `#devlog`, `#architecture`, `#bugfix`, `#todo`, `#securite`.
  - Tâches au format todo Logseq : `- [ ] Description de la tâche`.
- **Aucun paragraphe libre** : Tout doit figurer dans une puce.
- **Mise à jour du journal** :
  - Lis le journal `/mnt/samsung4To/Dev/second-brain/journals/<AAAA_MM_JJ>.md` s'il existe déjà.
  - S'il existe et contient déjà `- [[NomDuProjet]] #devlog`, mets à jour ou complète cette section sans écraser le reste du journal.
  - S'il existe sans cette section, ajoute-la à la suite.
  - Si le fichier n'existe pas, crée-le avec l'entrée formatée.

### 5. Restitution à l'utilisateur
Affiche un retour synthétique en Markdown indiquant :
- L'état Git résumé.
- Les points clés enregistrés.
- Un lien markdown cliquable vers le journal Logseq : `[journals/AAAA_MM_JJ.md](file:///mnt/samsung4To/Dev/second-brain/journals/AAAA_MM_JJ.md)`.
