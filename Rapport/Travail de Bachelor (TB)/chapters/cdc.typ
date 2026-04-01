#import "@preview/oxdraw:0.1.0" : *

= Cahier des charges <cahier-des-charges>

== Résumé du contexte <resume-du-contexte>

L'essor des villes intelligentes (_Smart Cities_) rend indispensable le déploiement de réseaux capables d'interconnecter une multitude d'équipements. Ces applications imposent des contraintes réseau strictes : une densité élevée d'appareils, une couverture longue portée et une forte résilience face aux obstacles urbains. 

Pour répondre aux défis de l'IoT (Internet des Objets), *Zephyr* s'est imposé comme une référence. Ce système d'exploitation temps réel (RTOS), lancé en 2016, est spécialement conçu pour les petits systèmes embarqués connectés et à faibles ressources. Il offre une connectivité avancée, de multiples API de communication et prend en charge un large éventail d'architectures 32 et 64 bits.

De son côté, la *Nanostack* est une pile de communication open source reconnue pour son intégration robuste des réseaux maillés, notamment via le protocole Wi-SUN. Cependant, elle a été historiquement développée pour le système d'exploitation Mbed OS, dont la maintenance officielle a pris fin au profit d'autres solutions.

=== Problématique <problematique>

Mbed OS n'étant plus supporté, le projet consiste à porter la pile réseau Nanostack vers Zephyr RTOS afin de pérenniser son utilisation. L'enjeu technique principal réside dans l'adaptation de la couche d'abstraction matérielle (HAL) de la Nanostack pour qu'elle puisse interagir nativement avec l'écosystème et les pilotes matériels de Zephyr.

Ce portage s'articulera autour de deux phases majeures :
1. *Fonctionnement autonome (_Standalone_) :* Adapter et faire tourner le cœur de la Nanostack sur Zephyr de manière indépendante, en validant les interactions de bas niveau (radio, timers, gestion mémoire).
2. *Intégration système(Optionel) :* Coupler intimement la Nanostack à la pile réseau native de Zephyr, afin qu'elle puisse être exploitée par les applications de haut niveau de manière totalement transparente, via l'API standard des _sockets_ BSD.



== Phase du projet

+ Prise en main de la base de code
    - Fork les sources de `mbed-os`
    - Fork les sources de `zephyr-os`
    - Prise en main de la hiérarchie des dossiers de la `Nanostack`
    - Mise en évidence des différents dossier et leur utilisation

+ Prise en main de Zephyr OS
    - Installation devoid pr la toolchain
    - Compiler le kernel ainsi qu'un exemple sur qemu
    - Compiler le kernel ainsi qu'un exemple sur une cible
    - Ecrire un petit programme de test 

+ Mettre en évidence les différences de fonctionnement entre `mbed-os` et `zephyr`
    - Comprendre comment fonctionne la `event-loop` de `mbed-os`
    - Comprendre comment fonctionne les interfaces reseau de `mbed-os`
    - Comprendre comment fonctionne les driver réseau sur `zephyr`
    - Isoler les différents composants

+ Ecrire le rapport intermediaire
    - Mettre l'avancement du projet
    - Expliquer le fonctionnement de zephyr etc

+ Isoler la partie "métier" de la stack est isoler les fonctions lié au kernel
    - Copier la partie qui n'est pas relié a l'os
    - Commencer a faire l'inventaire des fonctions a porter

+ Ecrire la HAL(Hardware Abstraction Layer)
    - Remplacer toute les fonctions kernel appeler par la stack par des fonctions de la HAL
    - Implementer chacune de ses fonctions pour `zephyr`
    
+ Tester l'implémentation
    - Ecrire des test pour garantir le bon fonctionnement de la stack
    - Ecrire un petit programme `zephyr` qui va permettre de faire communiquer 2 boards entre elle avec la nanostack

+ Optionel: Integrer la nanostack a l'ecosystéme reseau de `Zephyr`
    - Porter la nanostacj de facon a ce que on appelle les socket bsd pour que ca fonctionne

+ Redaction du rapport final
    - Documenter les implementations
    - Documenter l'avancement du projet


=== Livrables <livrables>

Les délivrables seront les suivants :
- Le rapport complet 
- Un repo Github contenant le portage de la Nanostack
- Un repo Github contenant un code d'exemple
