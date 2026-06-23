= Conclusion

== Etat final du projet

Ce travail de Bachelor a permis de concrétiser le portage de la pile réseau *Nanostack* au sein de l'environnement *Zephyr*. Le projet a abouti à une architecture modulaire, capable de gérer des flux réseau de manière transparente via un pontage logiciel robuste.

Au terme de ce développement, les objectifs atteints démontrent la viabilité technique de l'approche adoptée :

- *Portage de la pile :* L'intégration de la *Nanostack* dans l'écosystème *Zephyr* est effective, offrant une base pérenne pour les applications IoT.
- *Communication filaire :* Le pont Ethernet est entièrement fonctionnel, permettant une communication IPv6 stable, incluant la gestion complète des couches L2 et L3.
- *Couche d'adaptation radio :* Le développement du pont radio a été validé au niveau structurel, confirmant la capacité du système à traiter les flux TX/RX en conditions réelles.

Certaines étapes, cependant, n'ont pu atteindre leur plein aboutissement en raison de limitations matérielles identifiées :

- *Stabilité de la pile radio Wi-SUN :* L'intégration complète du protocole Wi-SUN reste partielle. Bien que le pontage radio soit opérationnel, l'immaturité actuelle du pilote fourni pour le SoC CC1352 a empêché la finalisation d'un exemple fonctionnel complet.
- *Optimisation directe :* La variante optimisée `bridge_l2_direct.c`, bien qu'initiée, nécessite des travaux complémentaires de synchronisation matérielle pour garantir sa fiabilité.

Ces éléments ne constituent pas une fin en soi, mais plutôt une base technique solide. Le pontage étant validé, la migration de la pile vers un pilote radio stabilisé ou une plateforme matérielle mieux supportée permettra de finaliser l'usage du Wi-SUN. Ce projet offre ainsi une architecture prête à l'emploi, dont la flexibilité facilitera les futures étapes de développement.

== Intégration dans l'écosystème des sockets BSD de Zephyr

Parmi les objectifs optionnels définis dans le cahier des charges, l'intégration complète de la *Nanostack* au sein du sous-système réseau natif de *Zephyr* n'a pas pu être menée à son terme. L'accomplissement de cette tâche aurait permis aux applications d'interagir avec la pile Wi-SUN de manière transparente via l'API standardisée des sockets BSD de Zephyr.

Néanmoins, les travaux d'analyse menés au cours de ce projet confirment que ce rapprochement représente un défi architectural conséquent :
- *Le couplage des pilotes* : Comme mis en évidence lors de la conception du pont filaire, les pilotes de périphériques réseau de Zephyr sont intimement liés à ses couches L2 natives (comme `ETHERNET_L2` ou `IEEE802154_L2`). Réacheminer les paquets depuis les sockets BSD système vers la Nanostack nécessiterait de concevoir une couche de multiplexage ou d'exploiter le mécanisme d'offloading de sockets de Zephyr (_Socket Offloading_).
- *L'encapsulation des tampons* : L'interfaçage imposerait de traduire dynamiquement les descripteurs de paquets natifs de Zephyr (`net_pkt`) en structures de tampons internes de la Nanostack, ce qui induirait une surcharge de traitement et une complexité de gestion mémoire.

Cette intégration constitue ainsi un chantier de développement majeur à part entière. Elle figure en tête des perspectives futures pour ce portage, ouvrant la voie à une intégration native de la technologie Wi-SUN dans les prochaines versions du RTOS Zephyr.

== Perspectives futures

Le travail réalisé dans le cadre de ce Travail de Bachelor pose les bases fonctionnelles du portage de la pile *Nanostack* sous *Zephyr RTOS*. Plusieurs axes d'amélioration et développements futurs permettraient de consolider ce projet et d'envisager son utilisation dans des déploiements industriels.

=== Caractérisation métrologique et énergétique
Bien que la latence et la stabilité aient été validées sur une liaison filaire point à point, il serait pertinent de mener des campagnes de mesures approfondies dans un environnement de réseau maillé multi-sauts :
- *Analyse de performance* : Évaluer le débit effectif, la perte de paquets et la latence lors de la reconstruction dynamique de routes par le protocole RPL.
- *Profilage de consommation* : Mesurer précisément (via un analyseur de puissance ou un outil de type *Power Profiler*) la signature énergétique du microcontrôleur CC1352P7 lors des phases de veille active (`K_FOREVER`) et de réveil radio, afin de certifier l'autonomie sur batterie des nœuds finaux.

=== Contribution et correction du pilote matériel Texas Instruments
La limitation actuelle obligeant à restreindre les communications au canal 0 découle d'un bug dans le calcul des fréquences au sein du pilote IEEE 802.15.4 de Zephyr. Une perspective clé consisterait à corriger cette fonction au niveau du pilote natif de Zephyr afin de prendre en charge l'ensemble des 35 canaux de la bande européenne. Cette contribution *upstream* permettrait de réactiver le saut de fréquence (FHSS) et de rendre le système pleinement conforme aux spécifications Wi-SUN FAN.

=== Intégration par déchargement de sockets (Socket Offloading)
À terme, l'intégration système idéale consisterait à implémenter la Nanostack comme pile IP principale pour l'interface radio via l'API de déchargement (*Socket Offloading*)@NetworkTrafficOffloading de Zephyr. Ce mécanisme permettrait aux applications d'utiliser les fonctions de sockets standards du système d'exploitation (`zsock_socket`, `zsock_sendto`, etc.) tout en bénéficiant de l'efficacité et de la sécurité de la Nanostack en arrière-plan, sans modification du code applicatif.

== Planification finale <planification-finale>

Ce chapitre présente le planning final et effectif des travaux réalisés tout au long de ce projet de Bachelor.

L'implémentation de la couche d'abstraction matérielle (HAL) ainsi que la phase de test et de validation ont requis un investissement en temps nettement supérieur aux estimations initiales. La complexité liée à l'écriture des ponts materiels a été sous estimée. Ce décalage a néanmoins été en partie compensé par la phase d'isolation métier/kernel et d'inventaire des fonctions à porter, qui s'est avérée plus rapide qu'escompté.

Cependant, cette redistribution de la charge horaire a impacté le périmètre final du projet : le temps restant n'a pas permis d'aborder l'intégration de la Nanostack au sein des sockets BSD natives de Zephyr, qui constituait un objectif initial optionnel. Les efforts se sont concentrés sur la robustesse du pontage de niveau 2 et de l'ordonnancement de la pile, garantissant ainsi la fiabilité des communications physiques.

#let phases = (
  (
    nom: "1. Base de code",
    taches: [- Fork de `mbed-os` et `zephyr-os` \ - Analyse de la hiérarchie de la `Nanostack`],
    heures: 20
  ),
  (
    nom: "2. Prise en main Zephyr",
    taches: [- Installation de la toolchain \ - Compilation kernel + exemples \ - Programme de test],
    heures: 40
  ),
  (
    nom: "3. Étude comparative",
    taches: [- Analyse de l'`event-loop` \ - Interfaces et drivers réseau \ - Isolation des composants],
    heures: 50
  ),
  (
    nom: "4. Rapport intermédiaire",
    taches: [- Rédaction de l'état d'avancement \ - Explication théorique],
    heures: 20
  ),
  (
    nom: "5. Isolation métier/kernel",
    taches: [- Copie de la partie agnostique \ - Inventaire des fonctions à porter],
    heures: 10
  ),
  (
    nom: "6. Création de la HAL",
    taches: [- Remplacement des appels kernel \ - Implémentation pour `zephyr`],
    heures: 180
  ),
  (
    nom: "7. Phase de tests",
    taches: [- Écriture des tests de validation \ - Dev d'un programme de communication P2P],
    heures: 95
  ),
  (
    nom: "8. Intégration (Optionnel)",
    taches: [- Portage pour appel via les sockets BSD],
    heures: 5
  ),
  (
    nom: "9. Rapport final",
    taches: [- Documentation des implémentations \ - Bilan du projet],
    heures: 30
  )
)

#let total_heures = phases.fold(0, (accumulateur, p) => accumulateur + p.heures)

#table(
  columns: (auto, 3fr, 1fr, auto),
  inset: 10pt,
  align: (left, left, center, center),
  fill: (col, row) => if row == 0 { luma(230) } else { none },
  
  table.header(
    [*Phase*], [*Tâches associées*], [*Temps alloué*], [*Proportion*]
  ),
  
  ..phases.map(p => (
    [*#p.nom*], 
    p.taches, 
    [#p.heures h], 
    [#calc.round((p.heures / total_heures) * 100)%]
  )).flatten(),

  table.cell(colspan: 2, align: right)[*Total effectif*], 
  [*#total_heures h*], 
  [*100%*]
)

=== Diagramme de Gantt final <diagramme-gantt-final>

#figure(
  image("../image/gantt_finale.svg"),
  caption: [Diagramme de Gantt de la planification finale et effective]
) <fig_gantt_final>


== Conclusion personnelle <conclusion-personnelle>

La réalisation de ce travail de Bachelor a constitué une expérience particulièrement enrichissante, tant sur le plan technique que méthodologique. 

Ce projet m'a permis d'appréhender les subtilités et la rigueur indispensables aux travaux de portage de logiciels embarqués complexes. En me plongeant au cœur de la Nanostack, j'ai approfondi mes compétences en programmation réseau et affiné ma compréhension des mécanismes de transmission sans fil sub-GHz. Sur le plan de l'ingénierie système, l'opportunité de manipuler et de comparer des systèmes d'exploitation temps réel (RTOS) aux philosophies distinctes, tels que le moderne *Zephyr* et le plus historique *Mbed OS*, s'est révélée extrêmement formatrice. Le travail direct sur du matériel physique varié (modules de développement Texas Instruments et cartes Ethernet) m'a confronté aux réalités concrètes et parfois imprévues de l'intégration matérielle.

Enfin, ce travail a renforcé mes compétences en gestion de projet. Faire face à des imprévus techniques, évaluer l'avancement réel face aux objectifs et adapter la planification sous contrainte de temps m'ont appris à structurer et à prioriser les tâches de manière autonome. Ce projet représente ainsi un jalon clé dans mon parcours de futur ingénieur.

== Remerciements

Je tiens à exprimer ma profonde gratitude aux personnes qui ont contribué à la réalisation de ce Travail de Bachelor.

Mes remerciements s'adressent tout d'abord au Professeur Favrat, pour la qualité de son encadrement et son accompagnement tout au long de ce projet.

Je souhaite également remercier chaleureusement Yann Charbon pour ses précieux conseils, sa disponibilité et la pertinence de ses réponses à mes nombreuses interrogations.

Enfin, je remercie Eva Ray, Thomas Germano, Melissa Gehring et Manuel Cabras pour leur relecture attentive de ce document et leurs suggestions constructives.

#v(2cm) // Espace vertical avant la signature
#align(right)[
  #box(width: 200pt)[
    #align(left)[
      
      #v(1.5cm)
      *Benoît Delay* \

      
      #v(1cm)
      // Si vous avez une image de votre signature (ex: signature.png dans le dossier image) :
      // #image("../image/signature.png", width: 80%)
  
    ]
  ]
]