= Glossaire des termes techniques
#figure(
table(
  columns: (1fr, 3fr), // La première colonne prend 1/4 de l'espace, la 2ème prend 3/4
  inset: 10pt,         // Marge interne des cellules pour que le texte respire
  align: horizon,      // Alignement vertical au centre

  // En-tête du tableau
  table.header(
    [*Acronyme / Terme*], [*Définition*]
  ),

  // Lignes du tableau
  [*RTOS*],
  [*Real-Time Operating System* : Système d'exploitation déterministe conçu pour traiter un événement et fournir une réponse dans un délai strict et garanti.],

  [*SAL*], 
  [*Software Abstraction Layer* : Couche logicielle de la Nanostack qui offre une interface standardisée (API Socket) et gère les protocoles réseau indépendamment du matériel.],

  [*HAL*], 
  [*Hardware Abstraction Layer* : Couche d'abstraction matérielle. Elle fait le lien entre le logiciel (comme la SAL) et les composants physiques (antenne radio, timers, etc.).],

  [*6LoWPAN*], 
  [*IPv6 over Low-Power Wireless Personal Area Networks* : Protocole permettant de compresser et transmettre des paquets IPv6 sur des réseaux sans fil à faible consommation (comme le 802.15.4).],

  [*RPL*], 
  [*Routing Protocol for Low-Power and Lossy Networks* : Protocole de routage dynamique utilisé par la Nanostack pour trouver le meilleur chemin dans un réseau maillé (mesh).],

  [*Mbed TLS*], 
  [Bibliothèque de cryptographie autonome (anciennement liée à Mbed OS) fournissant les mécanismes de sécurité comme TLS et DTLS pour chiffrer les communications.],

  [*TRNG*], 
  [*True Random Number Generator* : Générateur de nombres aléatoires matériel, indispensable à Mbed TLS pour créer des clés de chiffrement robustes.]
  
),
caption: [Glossaire des termes techniques]
)
= Introduction <introduction>
L'émergence des Smart Cities transforme radicalement la gestion des infrastructures urbaines en imposant une connectivité omniprésente et en temps réel. Ce changement d'échelle crée un besoin critique pour des réseaux capables de s'affranchir des contraintes physiques de la ville, notamment en termes de densité et de portée. Les solutions traditionnelles atteignent leurs limites face à des déploiements massifs, lorsqu'il s'agit de connecter des dizaines de milliers d'appareils, allant des compteurs électriques intelligents à l'éclairage public.
 
// TODO AJOUTER LA DOCUMENTATION https://fr.digi.com/solutions/by-technology/wi-sun#wi-sun-protocol

Pour répondre à ces problématiques, le standard Wi-SUN a été créé en janvier 2012. Il s'appuie sur une couche physique sub-GHz (norme IEEE 802.15.4g), offrant une meilleure propagation radio en milieu urbain dense et une grande résilience face aux obstacles physiques. Ce réseau maillé permet d'interconnecter des millions d'appareils grâce à l'adressage IPv6 et au protocole de routage RPL (Routing Protocol for Low-power and Lossy Networks). Au-delà de ses capacités d'auto-découverte et d'auto-réparation, il garantit la sécurité du réseau via le standard IEEE 802.1X, qui assure l'authentification de chaque nœud. Enfin, la Wi-SUN Alliance encadre l'interopérabilité entre les constructeurs, garantissant ainsi l'homogénéité et la pérennité des déploiements.

Zephyr est un RTOS en plein essor, soutenu par la Linux Foundation depuis sa première publication en février 2016 @ZephyrAnnounce. Il est conçu pour des appareils et des systèmes présentant de fortes contraintes mémoire. Son architecture repose sur un unique espace d'adressage ainsi qu'une gestion statique de la mémoire. Il reprend des concepts essentiels à Linux, tels que le DeviceTree et Kconfig, ce qui le rend hautement configurable et facilement adaptable à de nouvelles cibles matérielles. Néanmoins, à l'heure actuelle, il n'existe aucune implémentation open-source du standard Wi-SUN sur ce RTOS, malgré le fait qu'il intègre déjà nativement de nombreux protocoles réseau.

Nanostack est une pile de communication open-source intégrant le standard Wi-SUN. Actuellement, elle est étroitement liée à l'écosystème Mbed OS, un système qui n'est plus maintenu depuis 2024. Ce travail de Bachelor a pour but de pallier cette obsolescence en portant la Nanostack vers Zephyr et en l'intégrant pleinement à son architecture. À terme, cette contribution permettra de déployer Zephyr dans un contexte de Smart Cities de manière entièrement open-source, tout en garantissant la pérennité de cette solution réseau.

== Structure du document <structure-du-document>

Ce rapport intermédiaire s'articule autour des axes suivants :

- *Cahier des charges* : Définition des phases du projet et des livrables attendus.
- *Planification initiale* : Présentation du calendrier prévisionnel et des jalons du projet.
- *État de l'art* : Analyse des différentes technologies étudiées en vue du portage.
- *Stratégie de portage de la Nanostack* : Détail de la méthodologie employée pour adapter les différents composants, ainsi que l'argumentaire des choix techniques réalisés.
- *Bilan et planification actualisée* : État d'avancement des travaux au regard de la planification initiale et ajustement pour la suite du projet.