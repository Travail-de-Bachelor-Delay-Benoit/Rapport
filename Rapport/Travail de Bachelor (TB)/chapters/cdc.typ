#import "@preview/oxdraw:0.1.0" : *

= Cahier des charges <cahier-des-charges>
== Résumé du problème <résumé-du-problème>


Avec le developement des villes connectées (Smart City) il est devenu indispensable de pouvoir créer des reseaux qui puissent connecter tous ces nouveaux appareils. Pour répondre aux besoins strictes de ce style d'application (beaucoup de device, de longue portée, d'obstacle urbain)

Zephyr est un RTOS sortit en 2016. Son domaine d'usage est les petits systémes embarqué a faible ressource et connecté. Il est fournit avec plusieurs API de communication et prends en charge plusieurs architecture 32 et 64 bits. 

La Nanostack est une pile de communication Open Source qui intégre le protocole WiSun. Elle est developée pour le RTOS Mbed os qui n'est plus maintenu depuis 2024.

=== Problématique <problématique>
// TODO A FAIRE A REVOIR A MODIFIER
Embed OS n'étant plus supporté, il a été decidé de porter la Nanostack sur Zephyr. Il s'agit donc de porter la partie hardware de la Nanostack afin de l'intégrer dans l'écosystéme Zephyr. Dans un premier temps il faut la faire fonctionner en standalone puis dans un second temps il faut l'intégrer a l'écosystéme Zephyr et pouvoir le faire fonctionner depuis des socket BSD.

// Rendu du diagramme depuis le fichier externe


== Phase du projet

//A VOIR A CORRIGER
+ Prise en main de la base de code
    - Fork les sources de `mbed-os`
    - Fork les sources de `zephyr-os`
    - Prise en main de la hiérarchie des dossiers de la `Nanostack`
    - Mise en évidence des différents dossier et leur utilisation

+ Prise en main de Zephyr OS
    - Installation de la toolchain
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
2