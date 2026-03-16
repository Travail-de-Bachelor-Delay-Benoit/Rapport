= Cahier des charges <cahier-des-charges>
== Résumé du problème <résumé-du-problème>


// TODO A FAIRE A VOIR A MODIFIER

Avec le developement des villes connectées (Smart City) il est devenu indispensable de pouvoir créer des reseaux qui puissent connecter tous ces nouveaux appareils. Pour répondre aux besoins strictes de ce style d'application (beaucoup de device, de longue portée, d'obstacle urbain)

Zephyr est un RTOS sortit en 2016. Son domaine d'usage est les petits systémes embarqué a faible ressource est connecté. Il est fournit avec plusieurs API de communication et prends en charge plusieurs architecture 32 et 64 bits. 

La Nanostack est une pile de communication Open Source qui intégre le protocole WiSun. Elle est developée pour le RTOS Mbed os qui n'est plus maintenu depuis INSERER DATA ICI.

=== Problématique <problématique>
// TODO A FAIRE A REVOIR A MODIFIER
Embed OS n'étant plus supporter il est nécessaire de porter la Nanostack sur un nouvel OS, en l'occurence ici Zephyr 

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
