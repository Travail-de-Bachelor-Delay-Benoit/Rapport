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

=== Historique