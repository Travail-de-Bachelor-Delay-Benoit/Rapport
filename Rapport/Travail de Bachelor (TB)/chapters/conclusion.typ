= Conclusion du rapport intermédiaire <conclusion>

== Bilan et planification des travaux futurs <travail_a_faire>

La première phase de ce travail de Bachelor a permis de mener à bien l'analyse exhaustive du code source de la Nanostack et de s'approprier les concepts avancés de l'écosystème Zephyr RTOS. Cette étude théorique et la définition de l'architecture logicielle posent les bases nécessaires à la réalisation technique du projet.

La seconde phase se concentrera sur l'implémentation pratique de la stratégie détaillée précédemment, à savoir le portage effectif de la Nanostack sous forme de module Zephyr. Une fois cette intégration logicielle achevée, une phase de validation matérielle sera menée. Elle consistera à développer des programmes de test spécifiques et à les déployer sur les cartes de développement, afin d'évaluer le fonctionnement du portage.

Enfin, en fonction du temps imparti à l'issue de la phase de test, une étape d'intégration système avancée sera étudiée. Celle-ci aura pour but d'interfacer directement la Nanostack avec le sous-système réseau natif de Zephyr (_Net Subsystem_). L'accomplissement de cette tâche permettrait aux applications d'interagir avec le réseau Wi-SUN de manière totalement transparente, via l'API standardisée des _sockets_ BSD.

== État des lieux de la planification <etat_planification>

#figure(
  image("../image/planification_rendu_intermediaire.png"),
  caption: [État de la planification au 02.04.2026]
) <fig_planification>

Sur le plan du calendrier, l'avancement global du projet est conforme aux prévisions. Bien que la rédaction de ce rapport intermédiaire ait nécessité un investissement en temps supérieur aux estimations initiales, ce décalage a été entièrement compensé par une réalisation plus rapide de l'étude comparative.

Concernant les étapes à venir, une légère révision de la charge de travail a été effectuée. La phase de portage nécessitera probablement davantage de temps que prévu, notamment en raison de l'adaptation des règles de compilation (`CMakeLists.txt`) pour l'écosystème Zephyr, une tâche qui n'avait pas été isolée dans la planification initiale. Néanmoins, ce surcroît de travail devrait être naturellement équilibré par la phase d'inventaire des fonctions, dont l'envergure s'avère plus restreinte qu'escompté.