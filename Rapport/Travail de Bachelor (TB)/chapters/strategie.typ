// Macro globale pour les blocs de code (à placer en haut de ton fichier principal)
#let codeblock(body) = block(
  fill: luma(245), 
  stroke: luma(200), 
  inset: 10pt, 
  radius: 4pt, 
  width: 100%, 
)[
  // La numérotation des lignes est maintenant gérée automatiquement ici !
  #show raw.line: it => {
    box(width: 1.5em, align(right, text(fill: luma(150), str(it.number))))
    h(1em)
    it.body
  }
  #body
]

= Méthodologie et architecture du portage

== Intégration logicielle : Bibliothèque vs Module Zephyr

Lors du portage d'une base de code aussi volumineuse que la Nanostack, la méthode d'intégration au système de compilation est un choix d'architecture critique. Zephyr propose deux approches principales pour inclure du code tiers : l'intégration en tant que bibliothèque statique au sein de l'application, ou la création d'un Module Zephyr externe @ModulesExternalProjects
.

=== L'approche Bibliothèque classique (_In-Tree_)
Cette méthode consisterait à copier l'intégralité des fichiers sources de la Nanostack directement dans le dossier de l'application finale, et à configurer le fichier `CMakeLists.txt` de l'application pour les compiler. 
- *Avantage :* Mise en place initiale très rapide.
- *Inconvénient :* Cette approche lie fortement la pile réseau à l'application métier. Elle rend la mise à jour de la Nanostack difficile, pollue l'historique de version (Git) du projet principal et rend la réutilisation de la pile par d'autres projets quasiment impossible.

=== L'approche Module Zephyr (_Out-of-Tree_)
Un Module Zephyr est un dépôt de code (par exemple hébergé sur GitHub) totalement indépendant de l'arbre source de Zephyr et de l'application finale. Il est automatiquement téléchargé et lié lors de la configuration du projet grâce à l'outil de gestion de paquets `west` (via le fichier `west.yml`).

- *Séparation des responsabilités :* Le code de la Nanostack reste isolé. L'application métier se contente de l'appeler via les API publiques.
- *Intégration native (Kconfig et CMake) :* Un module permet de définir ses propres menus de configuration (`Kconfig`). Ainsi, les paramètres de la Nanostack (activation du Wi-SUN, taille des _buffers_) apparaîtront directement dans les menus de configuration de Zephyr (via `menuconfig`), exactement comme les sous-systèmes natifs.
- *Portabilité et partage :* En plaçant la Nanostack dans son propre dépôt Git structuré comme un module, elle devient facilement distribuable à l'ensemble de la communauté open source.

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
      - Réutilisation par d'autres projets plus ardue.
    ],
    
    // Ligne 2 : Module Zephyr
    [*Module Zephyr* \ _(Out-of-Tree)_], 
    [
      - Séparation stricte des responsabilités.
      - Intégration native aux menus `Kconfig` de Zephyr.
      - Gestion des dépendances automatisée via l'outil `west`.
      - Versionnement Git totalement indépendant.
      - Code standardisé et facilement distribuable.
    ], 
    [
      - Courbe d'apprentissage initiale légèrement plus rude (nécessite de maîtriser le format `module.yml`).
      - Configuration initiale des fichiers de liaison plus verbeuse.
    ]
  ),
  caption: [Comparaison des méthodes d'intégration logicielle sous Zephyr]
) <tab_comparaison_modules>

=== Décision architecturale et Manifeste `west`
Pour ce projet de Bachelor, l'approche par Module *Zephyr* est retenue. Elle est la seule à garantir une architecture logicielle pérenne. Le choix de cette architecture en module externe (_Out-of-Tree_) implique l'utilisation avancée du système de manifeste.

L'application finale contiendra un fichier `west.yml`. Lors de l'initialisation de l'environnement (via la commande `west update`), l'outil se chargera de cloner le dépôt de la Nanostack, de l'insérer dans l'espace de travail (_workspace_), et de parser son fichier `zephyr/module.yml` pour lier ses menus et scripts de compilation au système principal.

== Implémentation de la structure du module

Pour être reconnu par le système de compilation de Zephyr, le module externe doit respecter une topologie stricte et fournir trois fichiers fondamentaux : `module.yml` (description), `CMakeLists.txt` (compilation) et `Kconfig` (configuration).

La topologie classique du module développé pour ce portage est la suivante :

#figure(
  align(left)[
    #rect(fill: luma(245), inset: 12pt, radius: 4pt, width: 85%)[
      ```text
      zephyr-nanostack/
      ├── zephyr/
      │   └── module.yml       <-- Déclaration du module pour west
      ├── include/             <-- En-têtes publiques (API de la Nanostack)
      ├── src/                 <-- Code source C (event_loop, adaptateurs...)
      ├── CMakeLists.txt       <-- Règles de compilation Zephyr
      └── Kconfig              <-- Options d'activation pour le menuconfig
      ```
    ]
  ],
  caption: [Arborescence type du module Zephyr pour la Nanostack]
) <fig_arborescence_module>

Côté application, il suffira de modifier le fichier `west.yml` du projet cible pour y indiquer cette nouvelle dépendance et son URL Git :

#figure(
  caption: [Déclaration du module dans le `west.yml` de l'application],
  supplement: [Listing],
  align(left)[
    #codeblock[
      ```yaml
      manifest:
        projects:a
          - name: zephyr-nanostack
            url: [https://github.com/Travail-de-Bachelor-Delay-Benoit/zephyr-nanostack.git](https://github.com/Travail-de-Bachelor-Delay-Benoit/zephyr-nanostack.git)
            revision: main
      ```
    ]
  ]
) <lst_west_yml>

Une fois le module téléchargé, l'activation de la pile réseau se fera via le système de configuration standard. Le fichier `Kconfig` du module exposera les options nécessaires :

#figure(
  caption: [Fichier `Kconfig` à la racine du module],
  supplement: [Listing],
  align(left)[
    #codeblock[
      ```kconfig
      menuconfig NANOSTACK
          bool "Support de la pile réseau Nanostack (Wi-SUN)"
          default n
          help
            Active la compilation et l'intégration de la Nanostack.
      ```
    ]
  ]
) <lst_kconfig>

Enfin, le développeur n'aura plus qu'à ajouter `CONFIG_NANOSTACK=y` dans le fichier `prj.conf` de son application pour que la pile soit automatiquement incluse à la compilation.

== Adaptation du moteur d'événements (_Event Loop_)

L'un des défis majeurs du portage consiste à substituer les primitives de Mbed OS (CMSIS-RTOS) par celles de Zephyr. Le cœur de la Nanostack reposant sur un moteur d'événements (_Event Loop_), ce dernier doit s'exécuter dans son propre fil d'exécution (_thread_).

Sous Zephyr, ce fil d'exécution sera instancié à l'aide de l'API native `K_THREAD_DEFINE` ou `k_thread_create`. Il est crucial que l'implémentation de ce _thread_ prenne rigoureusement en compte la politique de gestion de l'énergie. En effet, la basse consommation étant l'un des piliers du standard Wi-SUN, la boucle d'événements ne doit en aucun cas monopoliser le processeur. Lorsqu'aucun événement réseau n'est présent dans la file d'attente, le _thread_ de la Nanostack devra explicitement relâcher la main (via `k_sleep` ou en bloquant sur une primitive de synchronisation) afin de permettre à Zephyr de basculer le système en veille profonde (_Deep Sleep_).

== Intégration cryptographique (Mbed TLS)

Le standard Wi-SUN impose des exigences de sécurité strictes, nécessitant l'authentification des nœuds (EAP-TLS) et le chiffrement des trames. La Nanostack s'appuie historiquement sur le projet *Mbed TLS* pour sa partie cryptographique.

Cette dépendance s'intègre parfaitement à la stratégie de portage puisque Zephyr utilise également Mbed TLS comme bibliothèque cryptographique officielle par défaut. Le portage ne nécessitera donc pas de réécrire les algorithmes de sécurité. Il consistera principalement à s'assurer que le système de compilation du module (via `CMake` et `Kconfig`) force l'activation de Mbed TLS (`CONFIG_MBEDTLS=y`). 

De plus, une attention particulière devra être portée sur l'entropie matérielle. Pour générer des clés cryptographiques robustes, la pile devra être correctement interfacée avec le générateur de nombres aléatoires matériel exposé par les API de Zephyr.

== Refonte des règles de compilation (CMakeLists)

La dernière étape stratégique concerne l'adaptation du processus de compilation. Mbed OS utilisait son propre système d'assemblage, qui doit être entièrement remplacé par des directives CMake compatibles avec l'écosystème Zephyr.

Le fichier `CMakeLists.txt` situé à la racine du module exploitera les macros spécifiques de l'OS (comme `zephyr_library()` et `zephyr_library_sources()`). Ces directives permettront d'inclure conditionnellement les fichiers sources en langage C de la Nanostack uniquement si l'option `CONFIG_NANOSTACK` est sélectionnée par l'utilisateur, garantissant ainsi que le code mort n'encombre pas la mémoire flash des applications ne nécessitant pas le Wi-SUN.

De plus, une attention particulière devra être accordée à la compilation du cœur de la Nanostack (les parties totalement agnostiques et indépendantes du système d'exploitation). Il sera également impératif de refléter avec précision la nouvelle arborescence des fichiers dans les directives CMake, afin de garantir la bonne résolution des chemins d'inclusion (_headers_) et de préserver l'intégrité de l'architecture logicielle.