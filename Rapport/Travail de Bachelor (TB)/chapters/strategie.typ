= Méthodologie de portage et d'intégration

== Intégration logicielle : Bibliothèque vs Module Zephyr

Lors du portage d'une base de code aussi volumineuse que la Nanostack, la méthode d'intégration au système de compilation est un choix d'architecture critique. Zephyr propose deux approches principales pour inclure du code tiers : l'intégration en tant que bibliothèque statique au sein de l'application, ou la création d'un Module Zephyr externe .

=== L'approche Bibliothèque classique
Cette méthode consisterait à copier l'intégralité des fichiers sources de la Nanostack directement dans le dossier de l'application finale, et à configurer le fichier `CMakeLists.txt` de l'application pour les compiler. 
- *Avantage :* Mise en place initiale très rapide.
- *Inconvénient :* Cette approche lie fortement la pile réseau à l'application métier. Elle rend la mise à jour de la Nanostack difficile, pollue l'historique de version (Git) du projet principal et empêche toute réutilisation simple de la pile par d'autres projets.

=== L'approche Module Zephyr (_Out-of-Tree_)
Un Module Zephyr est un dépôt de code (par exemple sur GitHub) totalement indépendant de l'arbre source de Zephyr et de l'application finale. Il est automatiquement téléchargé et lié lors de la configuration du projet grâce à l'outil de gestion de paquets `west` (via le fichier `west.yml`).

- *Séparation des responsabilités :* Le code de la Nanostack reste isolé. L'application métier se contente de l'appeler via les API.
- *Intégration native (Kconfig et CMake) :* Un module permet de définir ses propres menus de configuration (`Kconfig`). Ainsi, les paramètres de la Nanostack (activation du Wi-SUN, taille des _buffers_, niveau de log) apparaîtront directement dans les menus de configuration de Zephyr (via `menuconfig`), exactement comme les sous-systèmes natifs.
- *Portabilité et partage :* En plaçant la Nanostack dans son propre dépôt Git structuré comme un module, elle devient facilement distribuable. N'importe quel développeur de la communauté pourra l'intégrer à son projet Zephyr en ajoutant simplement une ligne à son manifeste `west`.

=== Comparaison des approches

Afin de justifier le choix de l'architecture logicielle, le tableau suivant dresse le bilan des avantages et inconvénients des deux méthodes d'intégration au sein de l'écosystème Zephyr :

#figure(
  table(
    columns: (auto, 1fr, 1fr),
    align: left,
    stroke: 0.5pt,
    fill: (col, row) => if row == 0 { luma(240) } else { none },
    
    // En-têtes du tableau
    [*Approche*], [*Avantages*], [*Inconvénients*],
    
    // Ligne 1 : Bibliothèque classique
    [*Bibliothèque classique* \ _(In-Tree)_], 
    [
      - Mise en place initiale rapide et intuitive.
      - Ne requiert pas d'outils externes (uniquement CMake).
      - Utile pour un prototypage très basique et isolé.
    ], 
    [
      - Forte dépendance logicielle (couplage fort) entre l'application et la pile réseau.
      - Mise à jour future de la Nanostack très complexe.
      - Pollution de l'historique Git du projet principal.
      - Aucune intégration native avec les menus de configuration `Kconfig`.
      - Réutilisation par d'autres plus ardues.
    ],
    
    // Ligne 2 : Module Zephyr
    [*Module Zephyr* \ _(Out-of-Tree)_], 
    [
      - Séparation stricte des responsabilités .
      - Intégration native aux menus `Kconfig` de Zephyr (comme une fonctionnalité de base).
      - Gestion des dépendances automatisée via l'outil `west`.
      - Versionnement Git totalement indépendant.
      - Code standardisé, facilement distribuable et réutilisable par la communauté open source.
    ], 
    [
      - Courbe d'apprentissage initiale un peu plus rude (nécessite de maîtriser l'outil `west` et le format `module.yml`).
      - Configuration initiale (fichiers de liaison) légèrement plus verbeuse.
    ]
  ),
  caption: [Comparaison des méthodes d'intégration logicielle sous Zephyr]
) <tab_comparaison_modules>

=== Décision architecturale
Pour ce projet de Bachelor, *l'approche par Module Zephyr est retenue*. Elle est la seule à garantir une architecture logicielle propre. La stratégie consistera donc à :
1. Créer un dépôt Git dédié au portage.
2. Y inclure les sources originales de la Nanostack.
3. Créer les fichiers de liaison requis par Zephyr (`zephyr/module.yml`, `CMakeLists.txt` et `Kconfig`) à la racine de ce dépôt pour que le système de compilation reconnaisse la pile réseau comme une extension native.