#import "@preview/oxdraw:0.1.0" : *

= Cahier des charges <cahier-des-charges>

== Résumé du contexte <resume-du-contexte>

L'essor des villes intelligentes (_Smart Cities_) rend indispensable le déploiement de réseaux capables d'interconnecter une multitude d'équipements. Ces applications imposent des contraintes réseau strictes : une densité élevée d'appareils, une couverture longue portée et une forte résilience face aux obstacles urbains. 

Pour répondre aux défis de l'IoT, *Zephyr* s'est imposé comme une référence. Ce système d'exploitation temps réel, lancé en 2016, est spécialement conçu pour les petits systèmes embarqués connectés et à faibles ressources. Il offre une connectivité avancée, de multiples API de communication et prend en charge un large éventail d'architectures 32 et 64 bits.

De son côté, la *Nanostack* est une pile de communication open source reconnue pour son intégration robuste des réseaux maillés, notamment via le protocole Wi-SUN. Cependant, elle a été historiquement développée pour le système d'exploitation Mbed OS, dont la maintenance officielle a pris fin au profit d'autres solutions.

=== Problématique <problematique>

Mbed OS n'étant plus supporté, le projet consiste à porter la pile réseau Nanostack vers Zephyr afin de pérenniser son utilisation. L'enjeu technique principal réside dans l'adaptation de la couche d'abstraction matérielle (HAL) de la Nanostack pour qu'elle puisse interagir nativement avec l'écosystème et les pilotes matériels de Zephyr.

Ce portage s'articulera autour de deux phases majeures :
1. *Fonctionnement autonome (_Standalone_) :* Adapter et faire tourner le cœur de la Nanostack sur Zephyr de manière indépendante, en validant les interactions de bas niveau (radio, timers, gestion mémoire).
2. *Intégration système (Optionel) :* Coupler intimement la Nanostack à la pile réseau native de Zephyr, afin qu'elle puisse être exploitée par les applications de haut niveau de manière totalement transparente, via l'API standard des _sockets_ BSD.



== Phase du projet

+ Prise en main de la base de code
    - Fork les sources de `mbed-os`
    - Fork les sources de `zephyr`
    - Prise en main de la hiérarchie des dossiers de la `Nanostack`
    - Mise en évidence des différents dossiers et leur utilisation

+ Prise en main de Zephyr
    - Installation de la toolchain de Zephyr
    - Compiler le kernel ainsi qu'un exemple sur qemu
    - Compiler le kernel ainsi qu'un exemple sur une cible
    - Ecrire un petit programme de test 

+ Mettre en évidence les différences de fonctionnement entre `mbed-os` et `zephyr`
    - Comprendre comment fonctionne la `event-loop` de `mb1ed-os`
    - Comprendre comment fonctionne les interfaces réseau de `mbed-os`
    - Comprendre comment fonctionne les drivers réseau sur `zephyr`
    - Isoler les différents composants

+ Ecrire le rapport intermediaire
  - Documenter l'avancement des travaux de recherche préliminaires
  - Rédiger une étude théorique sur les mécanismes internes de Zephyr (gestion de l'énergie, architecture réseau, etc.)
  - Établir les choix techniques et méthodologiques pour la phase d'implémentation

+ Isoler la partie "métier" de la stack et isoler les fonctions liées au kernel
    - Copier la partie qui n'est pas reliée à l'OS
    - Commencer à faire l'inventaire des fonctions à porter

+ Ecrire la HAL(Hardware Abstraction Layer)
    - Remplacer toutes les fonctions kernel appelées par la stack par des fonctions de la HAL
    - Implémenter chacune de ces fonctions pour `zephyr`
    
+ Tester l'implémentation
    - Ecrire des tests pour garantir le bon fonctionnement de la stack
    - Ecrire un petit programme `zephyr` qui va permettre de faire communiquer 2 boards entre elles avec la Nanostack

+ Optionnel: Intégrer la Nanostack à l'écosystème réseau de `Zephyr`
    - Intégrer la Nanostack au sous-système réseau de Zephyr afin de permettre aux applications de communiquer via l'API standardisée des sockets BSD.

+ Rédaction du rapport final
    - Documenter les implementations
    - Documenter l'avancement du projet


=== Livrables <livrables>

Les délivrables seront les suivants :
- Le rapport complet 
- Un repo Github contenant le portage de la Nanostack
- Un repo Github contenant un code d'exemple
