/*
 Vars
*/
#import "../vars.typ": *
#import "@preview/mmdr:0.2.2"

/*
 Includes
*/
#import "template/affiche.typ": affiche
#show: affiche.with(
  title: TBtitle, 
  dpt: "ISC",
  filiere_short: "ISC",
  filiere_long: TBfiliere,
  orientation: "ISCE",
  author: TBauthor,
  supervisor: TBsupervisor,
  industryContact: TBindustryContact,
)

= Contexte
L’émergence des villes intelligentes (_Smart Cities_) nécessite l'interconnexion fiable et sécurisée de flottes massives d'objets connectés (capteurs, compteurs d'énergie) sur de longues distances. Le protocole de réseau maillé sub-GHz sécurisé **Wi-SUN** s'est imposé comme une référence industrielle majeure pour ces déploiements.

Cependant, la pile réseau open-source de référence, la **Nanostack**, était historiquement développée sous *Mbed OS*, un système d'exploitation abandonné en 2024. Le système temps réel moderne **Zephyr RTOS**, soutenu par la Linux Foundation, s'est imposé comme la nouvelle plateforme de référence pour l'IoT embarqué, mais ne dispose à ce jour d'aucune implémentation Wi-SUN native dans son écosystème.

= Objectifs
Ce travail de Bachelor a pour but de porter la pile *Nanostack* sous *Zephyr RTOS* afin de pérenniser la technologie et d'offrir une solution de connectivité Wi-SUN entièrement open-source. Les objectifs clés sont :

- **Concevoir un module externe** (_Out-of-Tree_) pour intégrer proprement la Nanostack dans le système de compilation CMake et de configuration Kconfig de Zephyr.
- **Réimplémenter la couche d'adaptation matérielle (HAL)** de la pile (sections critiques, temporisateurs, TRNG) en utilisant les primitives natives du noyau Zephyr.
- **Concevoir des ponts réseau logiciels** pour intercepter les trames de couche 2 (Ethernet et Radio) et les injecter directement dans la pile.
- **Valider le portage** sur du matériel réel (puces Texas Instruments CC1352P7) à l'aide de programmes de test fonctionnels.

= Résultats
Les développements réalisés ont permis d'aboutir à un portage fonctionnel et stable :

- **Architecture modulaire :** La Nanostack s'intègre sous forme de module autonome. La boucle d'événements a été optimisée avec un réveil sur sémaphore (`K_FOREVER`) pour préserver l'autonomie en veille profonde du CPU.
- **Cryptographie de liaison :** Adaptation du chiffrement AES-128 via la bibliothèque *Mbed TLS* de Zephyr avec un pool statique de contextes AES afin de prévenir la fragmentation de la RAM.
- **Validation filaire (Ethernet) :** Le pontage L2 est pleinement opérationnel. L'autoconfiguration IPv6 (SLAAC) et les pings ICMPv6 sont fonctionnels avec une latence moyenne inférieure à 1 ms.
- **Validation sans fil (Wi-SUN) :** L'échange bidirectionnel de trames physiques entre un routeur de bordure (6LBR) et un nœud périphérique (6LN) a été démontré. Une limitation du pilote radio TI CC1352 sous Zephyr a été identifiée et contournée par un filtrage logique restreignant l'écoute au canal fixe 0 (868.3 MHz).

= Conclusion
Ce projet a permis de valider la faisabilité technique de l'exécution de la *Nanostack* sous *Zephyr RTOS*. Les bases d'interfaçage et de pontage logiciel développées sont robustes et agnostiques au matériel. 

Les perspectives d'évolution se concentrent sur la correction du pilote radio Texas Instruments natif de Zephyr afin de prendre en charge le saut de fréquence (FHSS) réglementaire, ainsi que sur l'intégration finale de la pile via le mécanisme de déchargement de sockets (_Socket Offloading_) pour en faire la pile réseau IP native de référence sous Zephyr.