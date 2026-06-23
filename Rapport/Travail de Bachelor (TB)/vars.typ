#let language = "fr"

#let studentFirstname = "Benoit"
#let studentLastname = "Delay"

// Use feminine or masculine form in template's text. Example: "La soussignée" or "Le soussigné"
#let TBfeminineForm = false // for the author
#let TBsupervisorFeminineForm = false // same, but for the supervisor. Example: "Enseignante responsable"

#let confidential = false

#let TBtitle = "Portage de la pile de communication Nanostack (Wi-SUN) sur Zephyr RTO"
#let TBsubtitle = "Travail de Bachelor"
#let TByear = "2026"
#let TBacademicYears = "2025-26"

#let TBdpt = "Département des Technologie de l'information et de la communication (TIC)"
#let TBfiliere = "Informatique et systèmes de communication"
#let TBorient = "Informatique Embarquée"

#let TBauthor = studentFirstname + " " + studentLastname
#let TBsupervisor = "Prof. Favrat Pierre"
#let TBindustryContact = "Nom"

#let TBresumePubliable = [
  L’émergence des Smart Cities impose l’interconnexion de flottes massives d'objets. Le standard de réseau maillé sub-GHz sécurisé Wi-SUN s'impose comme la référence pour ces déploiements. Cependant, sa pile open-source de référence, la Nanostack, était liée à Mbed OS, système abandonné en 2024. Ce travail de Bachelor présente le portage de la Nanostack sous le RTOS moderne Zephyr, comblant l'absence de solution Wi-SUN open-source sur cette plateforme.

Développé en module externe, le portage introduit une couche d'adaptation (OSAL) réimplémentant les primitives système (timers, sections critiques et aléa). La cryptographie de liaison s'appuie sur Mbed TLS via un pool statique de contextes AES pour préserver la RAM. L'interfaçage utilise deux ponts logiciels bidirectionnels (Ethernet et Radio) basés sur les sockets bruts AF_PACKET de Zephyr pour injecter les trames de couche 2 directement dans la pile. De plus, la boucle d'événements a été optimisée énergétiquement par une mise en veille indéfinie (K_FOREVER) de l'ordonnanceur.

La validation sur matériel réel (TI CC1352P7) démontre la viabilité du portage. Le pont Ethernet assure une autoconfiguration IPv6 (SLAAC) et des pings stables avec une latence inférieure à 1 ms. La communication bidirectionnelle du pont radio a été validée par l'échange de trames physiques entre un routeur de bordure (6LBR) et un nœud (6LN). Une limitation du pilote radio de Zephyr a été identifiée et contournée en restreignant la pile au canal 0 (868.3 MHz). Ce projet pose des bases solides pour une future intégration de Wi-SUN sous Zephyr via le déchargement de sockets.
]