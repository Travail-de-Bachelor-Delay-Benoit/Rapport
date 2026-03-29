= Planification <planification>

== Planification initiale <planification-initiale>

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
    heures: 50
  ),
  (
    nom: "6. Création de la HAL",
    taches: [- Remplacement des appels kernel \ - Implémentation pour `zephyr`],
    heures: 120
  ),
  (
    nom: "7. Phase de tests",
    taches: [- Écriture des tests de validation \ - Dev d'un programme de communication P2P],
    heures: 80
  ),
  (
    nom: "8. Intégration (Optionnel)",
    taches: [- Portage pour appel via les sockets BSD],
    heures: 40
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

  table.cell(colspan: 2, align: right)[*Total estimé*], 
  [*#total_heures h*], 
  [*100%*]
)
== Diagrame de gantt initiale <diagramme-gantt-initiale>

#figure(
  image("../image/gantt_initiale.svg"),
  caption: "Planification Initiale"
)