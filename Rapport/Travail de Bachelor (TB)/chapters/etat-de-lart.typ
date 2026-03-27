= État de l'art <etatdelart>

== Standard Wi-SUN <standardwisun>

Le standard Wi-SUN a été developpé en janvier 2012 par la Wi-SUN alliance.
Il repond a la montée des Smart Cities qui demandent de pouvoir connecter des centaines de milliers voir des millions de device ensemble dans un environnement urbain rempli d'obstacle physique. Pour parvenir a connecter tous ces appareils sans soucis de propagation d'onde et d'interference, il utilise des normes étudiée dans ce but tel que le 802.15.4g. Pour le protocole de routage il utilise RPL (Routing Protocol for Low-Power and Lossy Networks) et un addressage IPv6. Il a été aussi concu dans le but de minimiser la consommation d'énergie.

== Mbed OS <mbedos>

Mbed OS est un systéme d'exploitation temps rééel embarqué qui est basé sur CMSIS-RTOS qui est une API mise a dispostion par ARM pour dialoguer plus simplement et uniformément peu import le fabricant avec le processeur. Il intégre une mécanique temps réel ainsi que de gestion des threads.

Mbed OS intégre un grand nombre de module de connectivité et est particuliérement utilisé dans le monde de l'iot. Il implémente de nombreux protocole de communication et met aux développeur une implémentation haut niveau. Il supporte aussi un grand nombre de board et a beaucoup de driver.

Il a notamment la Nanostack, une pile de communication qui intégre entre autre le protocole Wi-SUN. Malheureusement ARM a décidé de déclarer la End Of Life de Mbed OS en juillet 2026. Ce qui a motivé l'intention de porter la Nanostack sur un nouvel RTOS pour beneficier du standard Wi-SUN sur de nouveaux os.

== Zephyr

Zephyr est un système d'exploitation open source soutenu par la Linux Foundation, dont la version 1.0 a été publiée le 17 février 2016. Il est spécifiquement conçu pour les systèmes embarqués aux ressources limitées répondant à des contraintes temps réel. S'inspirant fortement de Linux, il en reprend des concepts standards tels que le Device Tree et Kconfig.

C'est un OS extrêmement modulaire qui prend en charge un vaste panel d'architectures matérielles. Pour simplifier le flux de travail, il s'appuie sur son propre outil en ligne de commande, west. Ce dernier permet de cross-compiler, de tester et de déployer aisément son code sur l'ensemble des plateformes compatibles.

=== Kernel Zephyr

Le noyau de Zephyr offre divers fonctionnalité pour permettre a l'utilisateur de développer son application sans soucis. Les services étants:
- Threading
- Ordonnancement
- Interruption
- Mechanisme de syncronisation
- Système d'événements
- Gestion de la mémoire


// TODO a refaire je pense que c'est pas assez précis
Il s'occupe aussi de la gestion des driver. Le modele de driver Zephyr ressemble au modele Linux en ayant des driver générique par type d'interface qui doivent être écrit ensuite

=== Gestion de l'énergie

=== Connectivité et protocole

== Nanostack

La Nanostack est une pile de communication developé sur Mbed qui intégre plusieurs protocole de communication. Comme Mbed os est en fin de vie il est nécessaire de porter la pile sur un nouvel os.

Pour cela il faut bien comprendre le fonctionnement de la Nanostack, son système d'evenement.

La Nanostack est composé de 3 parties.

- Le SAL
- Le HAL 
- L'event Loop

=== SAL (Socket Abstraction Layer)

La SAL gère toute la partie purement logicielle de la Nanostack, totalement indépendante du matériel (qui est délégué à la couche matérielle, la HAL). Son rôle principal est de masquer la complexité du réseau en offrant une interface de programmation standardisée (API Socket) à l'application. 

C'est dans cette couche que s'exécutent les machines d'état des différents protocoles (MAC, 6LoWPAN, routage RPL, IPv6, TCP/UDP). Pour fonctionner efficacement sur des microcontrôleurs limités, la SAL s'appuie sur deux piliers :

- *Le Nanostack Event Loop :* Un ordonnanceur d'événements coopératif qui gère le trafic réseau de façon asynchrone pour économiser la RAM, sans nécessiter de multiples _threads_.
- *Une gestion interne de la mémoire dynamique* (`ns_dyn_mem`) *:* Un système d'allocation de _buffers_ réseau optimisé pour prévenir la fragmentation de la mémoire lors d'un trafic intense.

Enfin, la SAL intègre nativement les mécanismes de sécurité (via Mbed TLS) pour chiffrer les communications avant leur transmission.