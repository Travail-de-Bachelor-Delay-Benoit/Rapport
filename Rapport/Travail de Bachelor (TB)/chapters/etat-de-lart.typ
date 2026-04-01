= État de l'art <etatdelart>

== Standard Wi-SUN <standardwisun>

Le standard Wi-SUN a été développé en janvier 2012 par la Wi-SUN Alliance. Il répond à l'émergence des villes intelligentes (_Smart Cities_), qui exigent de pouvoir interconnecter des centaines de milliers, voire des millions d'appareils au sein d'environnements urbains denses et remplis d'obstacles physiques. 

Pour garantir une communication fiable en s'affranchissant des problèmes de propagation d'ondes et d'interférences, Wi-SUN s'appuie sur des spécifications optimisées pour cet usage, telles que la couche physique IEEE 802.15.4g (sub-GHz). Au niveau réseau, il utilise un adressage IPv6 couplé au protocole de routage dynamique RPL (_Routing Protocol for Low-Power and Lossy Networks_). L'ensemble de cette architecture a été pensé avec un objectif majeur : minimiser drastiquement la consommation énergétique des nœuds du réseau.

== Mbed OS <mbedos>

Mbed OS est un système d'exploitation temps réel (RTOS) destiné aux systèmes embarqués. Il repose sur CMSIS-RTOS@CMSISRTOSHandbook, une couche d'abstraction fournie par Arm, qui permet aux développeurs de dialoguer avec le processeur de manière uniforme, indépendamment du fabricant du matériel. Il intègre un noyau temps réel performant ainsi qu'une gestion complète du _multithreading_.

Particulièrement populaire dans l'écosystème de l'IoT, Mbed OS embarque nativement un grand nombre de modules de connectivité. Il fournit des implémentations de haut niveau pour de nombreux protocoles de communication, tout en supportant un vaste catalogue de cartes de développement et de pilotes (_drivers_).

C'est au sein de cet écosystème qu'a été développée la Nanostack, une pile de communication intégrant, entre autres, le standard Wi-SUN. Cependant, Arm a annoncé la fin de vie (_End of Life_ - EoL) de Mbed OS pour juillet 2026. Cette obsolescence programmée motive directement ce projet : porter la Nanostack vers un RTOS moderne et pérenne afin de continuer à exploiter les avantages du standard Wi-SUN.

== Zephyr

Zephyr est un système d'exploitation open source soutenu par la Linux Foundation, dont la version 1.0 a été publiée le 17 février 2016. Il est spécifiquement conçu pour les systèmes embarqués aux ressources limitées répondant à des contraintes temps réel. S'inspirant fortement de Linux, il en reprend des concepts standards tels que le DeviceTree et Kconfig.

C'est un OS extrêmement modulaire qui prend en charge un vaste panel d'architectures matérielles. Pour simplifier le flux de travail, il s'appuie sur son propre outil en ligne de commande, `west`@WestZephyrsMetatool. Ce dernier permet de cross-compiler, de tester et de déployer aisément son code sur l'ensemble des plateformes compatibles.

=== Gestion de l'énergie

L'un des objectifs premiers du standard Wi-SUN étant de minimiser la consommation électrique des différents nœuds, il est primordial d'intégrer rigoureusement la gestion de l'énergie lors du portage de la Nanostack. Zephyr permet de contrôler cette consommation à deux niveaux distincts :

==== Gestion globale du système (_System Power Management_)

La gestion de la consommation énergétique au niveau du processeur (CPU) s'articule autour de deux politiques de mise en veille principales@SystemPowerManagement :

- *Politique basée sur la résidence (_Residency-based_) :* C'est l'approche automatisée par défaut. Le noyau calcule le temps d'inactivité prévu avant la prochaine tâche planifiée. Il sélectionne ensuite automatiquement l'état de veille le plus profond possible, à condition que le temps d'inactivité soit supérieur au temps de résidence (le seuil de rentabilité énergétique de cet état). Les différents états de veille supportés par le matériel et leurs caractéristiques temporelles sont définis de manière statique dans le _DeviceTree_ à l'aide des _bindings_ `zephyr,power-state`.
- *Politique définie par l'application (_Application-defined_) :* Dans cette configuration, le noyau délègue la prise de décision. C'est au développeur d'implémenter sa propre logique métier pour basculer manuellement le CPU dans les modes d'économie d'énergie adéquats, offrant ainsi un contrôle total basé sur les événements et le comportement spécifique de l'application.

==== Gestion de l'alimentation des périphériques (_Device Power Management_)

Le _Device Power Management_ confie la gestion de la consommation énergétique directement aux pilotes (_drivers_) des périphériques. Zephyr propose deux méthodes distinctes pour contrôler l'état d'alimentation de ces composants matériels@DevicePowerManagement :

- *Gestion dynamique (_Device Runtime Power Management_) :* Dans ce modèle asynchrone, l'état d'alimentation d'un périphérique est géré de manière autonome en fonction de son utilisation réelle. Les pilotes peuvent adapter leur consommation, mais ils peuvent également être contrôlés explicitement par les applications de haut niveau ou les autres sous-systèmes de Zephyr via des API dédiées, permettant un réveil "à la demande".
- *Gestion centralisée par le système (_System-Managed Device Power Management_) :* Dans ce mode, le noyau coordonne la mise en veille des périphériques en synchronisation avec celle du processeur (CPU). Lorsqu'une transition vers un état de basse consommation global est décidée, le système se charge de suspendre automatiquement tous les périphériques inactifs. Cette suspension s'effectue strictement dans l'ordre inverse de leur initialisation, afin de préserver les dépendances matérielles et de garantir la stabilité du système.

=== Connectivité et protocoles

Pour répondre aux exigences de l'Internet des Objets, Zephyr embarque nativement une pile réseau complète, modulaire et hautement optimisée, appelée le _Net Subsystem_. Cette pile est conçue pour s'adapter aux architectures à faibles ressources tout en offrant des fonctionnalités dignes des systèmes d'exploitation majeurs.

L'architecture réseau de Zephyr s'articule autour de plusieurs couches clés :

- *L'interface applicative (API) :* Zephyr expose une interface de programmation basée sur le standard POSIX (_BSD Sockets_). Ce choix architectural est crucial, car il permet aux développeurs de créer des applications réseau de haut niveau (utilisant CoAP, MQTT ou HTTP) de manière totalement agnostique vis-à-vis du matériel et des protocoles sous-jacents.
- *Le cœur réseau (Couches 3 et 4) :* Le système gère nativement le routage IPv4 et IPv6, ainsi que les protocoles de transport TCP et UDP.
- *La couche liaison de données (Couche 2) :* Le _Net Subsystem_ supporte une grande variété de technologies physiques et de protocoles de liaison, tels que l'Ethernet, le Wi-Fi, le Bluetooth Low Energy (BLE) et la norme radio `IEEE 802.15.4`.


Bien que Zephyr intègre nativement la norme `IEEE 802.15.4` et supporte des protocoles maillés comme Thread (via l'intégration d'OpenThread), il souffre actuellement d'un manque important pour les déploiements urbains à grande échelle : il n'existe à ce jour aucune implémentation open source native du standard *Wi-SUN* dans son écosystème. 

C'est précisément cette lacune que le portage de la Nanostack vient combler.


== Nanostack

La Nanostack est la pile réseau développée originellement pour Mbed OS. Mbed OS arrivant en fin de vie, la migration de cette pile logicielle vers un nouvel OS est devenue indispensable.

Pour mener à bien ce portage, il est crucial d'appréhender l'architecture interne de la Nanostack. Celle-ci repose sur une séparation stricte des responsabilités, divisée en deux couches principales, animées par un moteur d'événements :

- La *SAL* (_Socket Abstraction Layer_) : La partie purement logicielle et applicative.
- La *HAL* (_Hardware Abstraction Layer_) : L'interface avec les composants matériels.
- Le *Nanostack Event Loop* : Le cœur asynchrone qui cadence l'ensemble des opérations.

=== SAL (Socket Abstraction Layer)

La SAL gère toute la partie purement logicielle de la Nanostack, totalement indépendante du matériel (qui est délégué à la couche matérielle, la HAL). Son rôle principal est de masquer la complexité du réseau en offrant une interface de programmation standardisée (API Socket) à l'application. 

C'est dans cette couche que s'exécutent les machines d'état des différents protocoles (MAC, 6LoWPAN, routage RPL, IPv6, TCP/UDP). Pour fonctionner efficacement sur des microcontrôleurs limités, la SAL s'appuie sur trois piliers :

- *Le Nanostack Event Loop :* Un ordonnanceur d'événements coopératif qui gère le trafic réseau de façon asynchrone pour économiser la RAM, sans nécessiter de multiples _threads_.
- *Une gestion interne du temps et de la mémoire* (`ns_timer` et `ns_dyn_mem`) *:* Un système de minuteurs virtuels pour les _timeouts_ réseau et un allocateur de _buffers_ optimisé pour prévenir la fragmentation de la mémoire lors d'un trafic intense.

Enfin, la SAL intègre nativement les mécanismes de sécurité (via Mbed TLS) pour chiffrer les communications avant leur transmission. Il est important de noter que bien que Mbed OS ait atteint sa fin de vie, le projet Mbed TLS demeure activement maintenu par la communauté TrustedFirmware @ImportantUpdateMbed2024. Son intégration reste donc pertinente et pérenne pour ce projet, nous dispensant de chercher une solution cryptographique alternative.

=== HAL (Hardware Abstraction Layer)

La HAL fait le pont entre le système d'exploitation hôte (Zephyr) et la Nanostack. Son rôle est de relier la logique logicielle de la pile réseau aux composants physiques. C'est à ce niveau que se fait l'interface avec les pilotes matériels (_drivers_), indispensables pour communiquer via `Ethernet` ou via la norme `IEEE 802.15.4`.

Pour réussir le portage vers Zephyr, l'implémentation de la HAL doit couvrir plusieurs domaines critiques :

- *L'allocation de la mémoire* : Bien que la Nanostack possède son propre gestionnaire de mémoire interne, elle doit interagir avec le noyau du RTOS hôte lors de son initialisation pour réserver son bloc de mémoire principal (via l'allocation dynamique de Zephyr ou l'assignation d'un bloc statique).
- *La gestion de la concurrence (Multithreading)* : Mbed OS et Zephyr étant tous deux des RTOS, la HAL doit traduire les primitives de synchronisation. Il est impératif d'implémenter les mutex, les sémaphores et les sections critiques pour protéger l'état de la Nanostack contre les accès concurrents provenant de différents _threads_.
- *Les horloges matérielles et interruptions* : La HAL doit faire le lien entre les minuteurs (_timers_) matériels gérés par Zephyr et les événements temporels de la Nanostack, tout en gérant les interruptions matérielles (par exemple, signaler à la pile logicielle qu'un paquet radio vient d'être physiquement reçu).

=== Le moteur d'événements (_Nanostack Event Loop_)

Au cœur de l'architecture de la Nanostack se trouve un composant central : le _Nanostack Event Loop_. Plutôt que de créer un fil d'exécution (_thread_) pour chaque connexion ou tâche réseau, ce qui serait bien trop coûteux en mémoire pour un microcontrôleur, la pile utilise un ordonnanceur d'événements coopératif.

Toutes les actions du réseau (réception d'un paquet, expiration d'un délai, demande de l'application) sont converties en événements et placées dans une file d'attente globale (_Event Queue_). L'Event Loop dépile ensuite ces événements un par un de manière asynchrone et déclenche les fonctions de rappel (_callbacks_) associées. Ce fonctionnement garantit une utilisation minimale et déterministe de la RAM.

=== Dépendance au système d'exploitation hôte (CMSIS-RTOS)

Bien que la Nanostack soit agnostique vis-à-vis du matériel, elle dépend intrinsèquement des services du système d'exploitation sur lequel elle tourne pour ses opérations fondamentales. Dans son environnement d'origine (Mbed OS), cette dépendance est gérée via l'API standardisée *CMSIS-RTOS*.

La pile réseau fait régulièrement appel à cette couche de compatibilité pour trois fonctions critiques :
- *La synchronisation :* Utilisation de verrous (_mutexes_) pour protéger ses structures de données internes lorsque des requêtes proviennent de différents _threads_ applicatifs.
- *L'allocation mémoire :* Réservation de la mémoire au démarrage pour son allocateur interne (`ns_dyn_mem`).
- *La gestion du temps :* Interfaçage avec les horloges du système pour la gestion des _timeouts_ et le cadencement de l'Event Loop.

*Enjeu pour le portage :* C'est sur ce point précis que se situe le cœur de la migration. Les appels à CMSIS-RTOS étant profondément ancrés dans la couche d'adaptation de la Nanostack, l'objectif du projet sera de substituer ces appels par les primitives natives de Zephyr (comme les API `k_mutex` ou `k_timer`), assurant ainsi une intégration fluide sans dénaturer le code source des protocoles.

=== Réception des paquets sous Mbed OS

Pour comprendre les enjeux du portage, il est essentiel d'analyser le flux de données actuel lors de la réception d'un paquet sous Mbed OS. Mbed OS étant majoritairement orienté objet (C++), tandis que la Nanostack est écrite en C, le passage du monde matériel au monde réseau nécessite une interface de traduction.

Le flux de réception d'une trame radio (ex: `IEEE 802.15.4`) se déroule en quatre étapes :

1. *L'interruption matérielle (ISR) :* Lorsque la puce radio reçoit un paquet valide, elle lève une interruption matérielle. Le noyau Mbed OS intercepte cette IRQ et exécute la routine d'interruption du pilote radio.
2. *L'interface matérielle (`NanostackRfPhy`) :* Mbed OS utilise une classe abstraite en C++ nommée `NanostackRfPhy`. Le pilote radio spécifique à la carte (par exemple, un driver Atmel ou STM32) hérite de cette classe. C'est ce pilote qui va lire les données brutes sur le bus matériel (SPI/UART).
3. *Le pont C/C++ et la fonction de rappel (_Callback_) :* Lors de l'initialisation du système, la classe `NanostackRfPhy` enregistre le périphérique radio auprès de la couche C de la Nanostack via l'API `arm_net_phy_register()`. Cette fonction fournit au pilote un pointeur vers une fonction de réception interne à la pile (souvent `phy_rx_cb`). Le pilote Mbed OS appelle cette fonction C en lui passant les données du paquet.
4. *L'Event Loop dans un _Thread_ Mbed OS :* C'est ici que la magie de la Nanostack opère. La fonction de rappel ne traite pas la trame directement. Elle alloue un tampon avec `ns_dyn_mem`, y copie la charge utile, et poste un événement réseau dans le _Nanostack Event Loop_. Sous Mbed OS, cet _Event Loop_ s'exécute en continu à l'intérieur d'un _thread_ CMSIS-RTOS dédié (souvent nommé `ns_thread`). Le RTOS réveille ce _thread_, qui dépile l'événement et fait remonter le paquet de manière asynchrone vers les couches MAC, 6LoWPAN et IPv6.

#figure(
  image("../image/Nanostack ISR Event-2026-03-29-224243.png"),
  caption: [Transaction driver -> Nanostack]
)

L'architecture actuelle démontre que la Nanostack n'a aucune conscience de la classe C++ `NanostackRfPhy` ni du fonctionnement interne de l'ISR de Mbed OS. Elle s'attend uniquement à ce qu'un code externe (la HAL) appelle sa fonction de rappel C (`phy_rx_cb`) et lui fournisse des événements. Dans Zephyr, il suffira de reproduire ce comportement depuis l'API `ieee802154` native.

=== Conclusion de l'état de l'art

L'analyse de ces différentes technologies met en évidence la pertinence du portage de la Nanostack vers Zephyr. D'un côté, le standard Wi-SUN répond parfaitement aux exigences des réseaux urbains modernes. De l'autre, Zephyr offre une base temps réel robuste, modulaire et taillée pour l'efficacité énergétique, mais manque encore d'une implémentation Wi-SUN native. L'architecture interne de la Nanostack, séparant habilement la logique réseau (SAL) des interactions matérielles (HAL), rend cette intégration réalisable. Le défi technique ne réside donc pas dans la réécriture des protocoles, mais bien dans la conception des interfaces (adaptateurs) entre la HAL de la Nanostack et les API natives de Zephyr.