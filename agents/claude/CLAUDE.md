# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

# Second Cerveau (Logseq)

- Mon graphe Logseq se situe dans : `/mnt/samsung4To/Dev/second-brain`
- Les journaux quotidiens sont dans `journals/AAAA_MM_JJ.md` (ex: `2026_11_13.md`).
- Les pages de projets sont dans `pages/`.
- **Formatage obligatoire Logseq :**
  - Chaque entrée doit être une liste à puces indentée avec des tabulations (`\t`) et des tirets (`- `).
  - Utilise des liens bidirectionnels `[[NomDuProjet]]` et des tags comme `#devlog`, `#architecture`, `#bugfix`, `#devops`, `#securite`.
  - Ne jamais écrire de longs paragraphes sans puces.
- **Fonctionnalités avancées Logseq à exploiter :**
  - **Propriétés :** Utilise la syntaxe `cle:: valeur` en tête de page ou sous un bloc (ex: `type::`, `stack::`, `statut::`, `collapsed:: true` pour replier les blocs longs).
  - **Tâches :** Utilise les mots-clés natifs `TODO`, `DOING`, `DONE` en début de puce (ex: `- TODO Finaliser le déploiement [[Le-Fil-des-Chapitres]]`).
  - **Cartes mémoire (Flashcards) :** Lorsque je demande des flashcards ou lors de la résolution d'un problème technique/concept DevOps notable, crée des cartes avec le tag `#card` sur le bloc question et la réponse indentée en bloc enfant (`\t- Réponse`).
  - **Admonitions :** Utilise `#+BEGIN_WARNING` / `#+END_WARNING` (ou `NOTE`, `TIP`, `IMPORTANT`) à l'intérieur d'un bloc pour les pièges critiques et décisions d'architecture.
  - **Requêtes :** Utilise `{{query ...}}` pour agréger dynamiquement les tâches ou concepts.
- **Synchronisation Git automatique :** Après toute création ou modification de fichier dans `/mnt/samsung4To/Dev/second-brain`, exécute automatiquement :
  `git -C /mnt/samsung4To/Dev/second-brain add . && git -C /mnt/samsung4To/Dev/second-brain commit -m "docs: update second-brain" && git -C /mnt/samsung4To/Dev/second-brain pull --rebase && git -C /mnt/samsung4To/Dev/second-brain push`
- **Dépôts à ignorer :** Ne jamais analyser ni créer de tâches/flashcards pour `Balise`, `SelfLlama`, `MyLittleAnsible`, `Velaluna`, `AirAlert`, `ETNAir` et `ancient-portfolio`.
