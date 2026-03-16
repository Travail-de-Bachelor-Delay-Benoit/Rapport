# Ebauche cahier des charges

- 1 . Prise en main de la base de code
    - Fork les sources de `mbed-os`
    - Fork les sources de `zephyr-os`
    - Prise en main de la hiéarchie des dossiers de la nanostack
    - Mise en évidence des différents dossier et leur utilisation

- 2 . Prise en main de Zephyr OS
    - Installation de la toolchain
    - Compiler le kernel ainsi qu'un exemple sur qemu
    - Compiler le kernel ainsi qu'un exemple sur une cible
    - Ecrire un petit programme de test 

- 3 . Elaboration du cahier des charges
    - Planifier le travail en amont
    - Isoler les points importants4

- 3 . Mettre en évidence les différences de fonctionnement entre `mbed-os` et `zephyr`
    - Comprendre comment fonctionne la `event-loop` de `mbed-os`
    - Comprendre comment fonctionne les interfaces reseau de `mbed-os`
    - Comprendre comment fonctionne les driver réseau sur `zephyr`
    - Isoler les différents composants

- 4 . Ecrire le rapport intermediaire
    - Mettre l'avancement du projet
    - Expliquer le fonctionnement de zephyr etc
- 5 . Isoler la partie "métier" de la stack est isoler les fonctions lié au kernel
    - Copier la partie qui n'est pas relié a l'os
    - Commencer a faire l'inventaire des fonctions a porter

- 6 . Ecrire la HAL(Hardware Abstraction Layer)
    - Remplacer toute les fonctions kernel appeler par la stack par des fonctions de la HAL
    - Implementer chacune de ses fonctions pour `zephyr`
    
- 7 . Tester l'implémentation
    - Ecrire des test pour garantir le bon fonctionnement de la stack
    - Ecrire un petit programme `zephyr` qui va permettre de faire communiquer 2 boards entre elle avec la nanostack
- 8 . Optionel: Integrer la nanostack a l'ecosystéme reseau de `Zephyr`
    - Porter la nanostacj de facon a ce que on appelle les socket bsd pour que ca fonctionne

- 9 Redaction du rapport final
    - Documenter les implementations
    - Documenter l'avancement du projet
