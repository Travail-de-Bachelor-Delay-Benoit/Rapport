= Validation et tests de fonctionnement

Pour valider l'intégrité de la pile réseau Nanostack et tester l'ensemble des scénarios de communication envisagés, trois applications de test distinctes ont été développées. Elles se divisent en deux axes de validation complémentaires :

1. *L'axe filaire (Ethernet)* : Une application de validation conçue pour tester le mécanisme de pontage L2 par socket brute sur un support Ethernet classique. Ce scénario simplifié permet de valider le comportement de l'ordonnanceur, l'intégration de la couche de transport UDP, ainsi que la configuration dynamique des adresses IPv6 (SLAAC) sans les perturbations inhérentes aux liaisons radio.
2. *L'axe sans fil (Wi-SUN)* : Un ensemble composé de deux applications (un routeur de bordure  *Border Router*  et un nœud périphérique  *End Device*). Ce système complet permet de valider le pont radio 802.15.4, d'observer la phase de découverte de réseau (PAN Discovery) et de confirmer la capacité de la pile à acheminer des paquets IPv6 sur un média physique partagé.

Ces applications font office de démonstrateurs fonctionnels mais servent également de cibles de compilation de référence pour valider l'intégration du module au système de build de Zephyr.

== Validation de la communication filaire (Ethernet)

Le premier programme de test, implémenté dans le module `app_ethernet`, a pour objectif de valider le comportement de base de la *Nanostack* et du pont logiciel Ethernet (`bridge_l2.c`) sur un canal physique stable et exempt de pertes (liaison filaire). La validation s'est articulée autour de deux phases de tests successives.

=== Validation de la connectivité Link-Local

La première étape de validation a consisté à vérifier la capacité de la *Nanostack* à établir une communication de base en mode *Link-Local* sur le support filaire. L'objectif était de confirmer que le pont logiciel transmettait correctement les paquets ICMPv6 de découverte de voisins (*Neighbor Discovery*) sans altération, permettant ainsi une autoconfiguration IPv6 fonctionnelle.

Le protocole *Neighbor Discovery* est critique en IPv6 : il permet aux interfaces réseau de découvrir les nœuds adjacents et de résoudre leurs adresses matérielles. En utilisant une interface Ethernet, ce mécanisme a été isolé afin de tester la transparence du pont :

- *Initialisation :* Dès l'activation de l'interface, la *Nanostack* génère une requête de sollicitation de voisin (*Neighbor Solicitation*) pour résoudre l'adresse IP cible.
- *Transmission :* Le pont intercepte cette requête, l'encapsule dans une trame Ethernet, et la transmet au driver *Zephyr* via le socket `AF_PACKET`.
- *Réponse :* Le nœud distant répond avec une publicité de voisin (*Neighbor Advertisement*). Cette trame suit le chemin inverse, transitant par le pont pour être injectée dans la pile *Nanostack*.

#figure(
  image("../image/wireshark_ping.png", width: 85%),
  caption: [Processus de découverte de voisins (NDP) à travers le pont logiciel]
)<fig_wireshark_ping>

Le succès de cette phase est validé par la réception effective de réponses ICMPv6. La capture réseau @fig_wireshark_ping montre que les paquets transitent avec les adresses MAC virtuelles configurées précédemment. Cette validation prouve que la logique de routage de la *Nanostack* communique correctement avec le support physique, et que les mécanismes de bas niveau (L2) assurés par le pont ne créent aucune latence bloquante pour les protocoles de découverte IPv6.

=== Phase 2: Validation de l'auto-configuration et de la couche IP

La seconde étape de validation a pour objectif de confirmer la pleine opérabilité de la pile réseau de la *Nanostack* au-dessus du pont logiciel. Il s'agit ici de vérifier que l'encapsulation des trames est correctement interprétée et que les mécanismes d'adressage IPv6 sont fonctionnels.

Le processus se décompose selon deux axes :

- *Auto-configuration (SLAAC) :* Lors de l'initialisation du pont `bridge_l2.c`, la *Nanostack* génère automatiquement ses adresses IPv6 (locales et globales) en s'appuyant sur l'adresse MAC virtuelle définie précédemment. Le succès de cette étape confirme que le pont transmet avec succès les messages de sollicitation de routeur (*Router Solicitation*), permettant à la pile d'obtenir ses paramètres réseau de manière autonome.

- *Validation par test d'écho (Ping) :* Afin de tester l'intégrité de la chaîne logique, des requêtes ICMPv6 (`ping6`) ont été émises depuis un PC hôte vers l'adresse IPv6 de la carte. La réception des réponses (*Echo Replies*) valide l'intégralité du cycle de vie du paquet : la capture via le socket `AF_PACKET`, l'injection dans la *Nanostack*, le traitement complet de la pile IP interne, et enfin la reconstruction de la réponse pour le support physique.

#figure(
  image("../image/wireshark_ping_router.png", width: 90%),
  caption: [Analyse des échanges ICMPv6 : preuve de la bidirectionnalité du pont]
) <fig_wireshark_ping_router>

La capture réseau @fig_wireshark_ping_router illustre ces échanges. On y observe clairement la requête d'écho entrante et la réponse sortante. La transparence du pont est ici totale : la pile IP de la *Nanostack* traite les paquets de manière native, sans détecter qu'ils transitent par une interface virtuelle. Ce test constitue la preuve ultime que le pontage ne corrompt aucune donnée et que les couches supérieures (IP/ICMPv6) sont parfaitement alignées avec les spécifications du matériel.

=== Phase 3: Validation de l'API de Socket et de la couche Transport (Serveur TCP)

Une fois la couche IP validée, il était nécessaire de vérifier le bon fonctionnement de l'API de programmation réseau (*Socket API*) de la *Nanostack* ainsi que la fiabilité de sa couche de transport TCP.

Pour ce faire, un serveur TCP a été développé au sein d'une tâche coopérative (*Tasklet*) de la *Nanostack* :
- Le serveur écoute sur le port `12345`.
- Un gestionnaire d'événements (`app_tasklet_handler`) intercepte la connexion d'un client externe (`SOCKET_INCOMING_CONNECTION`) et accepte la liaison via la fonction native `socket_accept`.
- Un timer logique de la *Nanostack* se déclenche toutes les secondes pour incrémenter un compteur et envoyer la chaîne de caractères `"Compteur: X\n"` au client TCP connecté (Listing @lst_ethernet_tcp).

#figure(
  caption: [Gestion de la connexion TCP et envoi du compteur dans le Tasklet],
  supplement: [Listing],
  align(left)[
    ```c
    void app_tasklet_handler(arm_event_s *event) {
        if (event->event_type == ARM_LIB_TASKLET_INIT_EVENT) {
            app_tcp_listener = socket_open(SOCKET_TCP, 12345, app_tcp_listener_callback);
            socket_listen(app_tcp_listener, 1);
            eventOS_event_timer_request(1, 102, app_tasklet_id, 1000);
        } else if (event->event_type == 102) { // Événement timer (1s)
            send_counter++;
            if (app_tcp_client_socket >= 0) {
                char send_buf[64];
                int len = snprintk(send_buf, sizeof(send_buf), "Compteur: %u\n", send_counter);
                socket_send(app_tcp_client_socket, send_buf, len);
            }
            eventOS_event_timer_request(1, 102, app_tasklet_id, 1000); // Relance du timer
        }
    }
    ```
  ]
) <lst_ethernet_tcp>

Ce test a été validé en se connectant à la carte depuis le PC hôte à l'aide de l'utilitaire `netcat` (`nc -6 <adresse_ip_carte> 12345`). La réception fluide du flux de compteurs a prouvé que la gestion des fenêtres de réception, des acquittements TCP et de l'ordonnancement des sockets de la *Nanostack* fonctionne de concert avec le système de threads de Zephyr.

=== Analyse de la latence réseau

Afin de quantifier l'impact du pontage logiciel sur la performance globale du système, une série de tests de latence basés sur l'envoi de 100 requêtes ICMPv6 (`ping6`) a été réalisée. Ces mesures permettent d'évaluer le temps de traitement induit par le passage à travers le socket `AF_PACKET` et la pile *Nanostack* dans différents scénarios de configuration.

Les résultats synthétisés dans le Tableau @tab:resultats_ping mettent en évidence une excellente réactivité en conditions nominales. En communication *Link-Local* ou via un routeur, la latence moyenne demeure inférieure à 1 ms, confirmant que le pontage logiciel n'introduit qu'une surcharge négligeable.

En revanche, l'activation des traces de débogage de la pile (`mbed_trace` redirigé vers le port série via la fonction `printk`) révèle une augmentation significative de la latence, passant à environ 60 ms. Cette hausse est due au caractère synchrone de l'affichage série sous Zephyr : à un débit de 115 200 bauds, l'envoi de chaque caractère bloque activement le processeur pendant environ $87$ µs. L'écriture de plusieurs lignes de log détaillées lors du traitement d'une trame accapare ainsi le temps CPU, ce qui retarde d'autant l'exécution de la boucle d'événements de la Nanostack et augmente artificiellement le temps de réponse aux requêtes d'écho.

#figure(
  table(
    columns: (auto, 1fr, 1fr, 1fr, 1fr),
    inset: 10pt,
    align: center + horizon,
    fill: (col, row) => if row == 0 { luma(230) } else { white },
    table.header(
      [*Scénario*], [*Min (ms)*], [*Moy (ms)*], [*Max (ms)*], [*Écart-type (ms)*]
    ),
    [Link-Local], [0.58], [0.68], [1.20], [0.08],
    [Via Routeur], [0.63], [0.71], [1.08], [0.08],
    [Routeur (Traces actives)], [59.45], [59.99], [87.68], [3.15]
  ),
  caption: [Analyse des performances de latence ICMPv6]
) <tab:resultats_ping>

Ces mesures démontrent la viabilité de l'architecture pour des applications temps-réel standards. La stabilité des écarts-types en conditions nominales prouve que le déterminisme du système est préservé, rendant cette implémentation robuste pour un usage en milieu industriel.

== Validation de la communication sans fil (Wi-SUN / 802.15.4)

La validation sans fil s'appuie sur deux programmes distincts fonctionnant en miroir : le routeur de bordure (`app_border_router`) et le nœud périphérique (`app_device_node`). Ils s'exécutent sur deux cartes distinctes équipées de puces radio TI CC1352P7.

=== Le Routeur de Bordure (app_border_router)

Le routeur de bordure (6LBR - *IPv6 Low-power Border Router*) est le nœud d'infrastructure central du réseau Wi-SUN. Il coordonne le PAN, gère l'authentification des nœuds entrants et assure le routage entre le domaine radio 802.15.4 et le backbone Ethernet.

L'initialisation de l'application s'effectue dans sa tâche principale (`app_tasklet_handler`) :
1. *Configuration du bootstrap* : L'interface est déclarée comme `NET_6LOWPAN_BORDER_ROUTER` sous le profil de réseau `NET_6LOWPAN_WS` (Wi-SUN).
2. *Authentification (EAP-TLS)* : Le routeur charge le certificat de l'autorité racine (CA) et son propre certificat de serveur de test afin d'agir comme authentificateur.
3. *Paramétrage physique et réglementaire* : Le routeur est configuré pour la bande européenne Sub-GHz (`REG_DOMAIN_EU`) en mode FSK à 50 kbps (Operating Mode 1a).
4. *Restriction au canal 0* : Afin de contourner la limitation physique du pilote Zephyr, les mécanismes de saut de fréquence (FHSS) sont débrayés. Les canaux d'émission unicast et broadcast sont fixés sur le canal 0 (868.3 MHz) et le masque de canaux Wi-SUN est restreint à cette seule fréquence.
5. *Démarrage du service BBR* : Le routeur configure son PAN ID (`0x1234`), active la diffusion de sa route par défaut via les paramètres Backbone Router (`ws_bbr_configure`) et démarre l'interface.

=== Le Nœud Périphérique (app_device_node)

Le nœud périphérique (6LN - *IPv6 Low-power Node*) est un appareil final destiné à rejoindre le PAN créé par le routeur de bordure afin d'envoyer ses données capteurs ou télémétriques.

L'initialisation de son tasklet de contrôle (`app_tasklet_handler`) est calquée sur celle du routeur, garantissant l'alignement des paramètres réseau (Listing @lst_device_setup) :
- *Rôle de nœud* : Il est configuré comme simple routeur/hôte Wi-SUN (`NET_6LOWPAN_ROUTER`).
- *Certificats clients* : Il charge le certificat racine de confiance (CA) et son propre certificat client Wi-SUN (`WISUN_CLIENT_CERTIFICATE`) pour s'authentifier auprès du routeur.
- *Alignement physique* : Les paramètres de domaine réglementaire (Europe, 50 kbps FSK) et la restriction au **canal fixe 0** sont identiques à ceux du routeur.

#figure(
  caption: [Configuration Wi-SUN et restriction de canal sur le nœud périphérique],
  supplement: [Listing],
  align(left)[
    ```c
    void app_tasklet_handler(arm_event_s *event) {
        if (event->event_type == ARM_LIB_TASKLET_INIT_EVENT) {
            // Configuration du rôle de routeur/hôte Wi-SUN
            arm_nwk_interface_configure_6lowpan_bootstrap_set(
                nwk_interface_id, NET_6LOWPAN_ROUTER, NET_6LOWPAN_WS);

            // Ajout des certificats du Supplicant (EAP-TLS client)
            arm_network_trusted_certificate_add(&trusted_cert);
            arm_network_own_certificate_add(&own_cert);

            // Alignement réglementaire et forçage du canal 0 (868.3 MHz)
            ws_management_node_init(nwk_interface_id, REG_DOMAIN_EU, "Wi-SUN-Network", fhss_timer);
            ws_management_regulatory_domain_set(nwk_interface_id, REG_DOMAIN_EU, 2, OPERATING_MODE_1a);
            
            uint32_t channel_mask[8] = {1}; // Canal 0 uniquement
            ws_management_channel_mask_set(nwk_interface_id, channel_mask);
            ws_management_fhss_unicast_channel_function_configure(nwk_interface_id, 0, 0, 0);

            // Démarrage de l'interface
            arm_nwk_interface_up(nwk_interface_id);
        }
    }
    ```
  ]
) <lst_device_setup>

Une fois démarré, le nœud périphérique ouvre son propre socket UDP d'émission et entre dans une phase d'écoute active du média (balayage réseau) à la recherche de trames d'annonce PAN (*PAN Advertisements*) émises par le routeur de bordure afin de démarrer sa procédure d'association.

=== Validation de la couche de pontage radio

Bien que l'intégration complète du protocole Wi-SUN se soit heurtée aux limitations du pilote radio natif, la validation de la couche d'adaptation radio a pu être réalisée avec succès. L'objectif était de confirmer que le pont radio (`bridge_l2_radio.c` adapté) est capable de gérer le flux de données bidirectionnel entre la pile radio et le noyau.

Les tests effectués confirment la robustesse de l'interfaçage : nous observons un trafic TX/RX conforme aux attentes, prouvant que le passage de la trame radio vers le socket `AF_PACKET` et sa réinjection dans la pile sont opérationnels. Comme illustré dans la @img_proof_radio, la pile radio détecte et traite les trames entrantes, tandis que les requêtes d'émission sont correctement transmises au driver physique.

#figure(
  image("../image/radio_rx_tx.png", width: 85%),
  caption: [Logs système : Validation de la transmission bidirectionnelle (TX/RX) du pont radio]
)<img_proof_radio>

Cette validation est très importantes : elle démontre que le blocage identifié ne provient pas de l'architecture de pontage, mais bien d'une défaillance au sein de la pile radio bas niveau. L'architecture développée est ainsi agnostique au support physique et prête à fonctionner de manière transparente dès qu'une version stable du driver radio sera déployée sur cette plateforme matérielle.

=== État d'avancement du pont direct (bridge_l2_direct.c)

Parallèlement aux validations effectuées, une variante optimisée, `bridge_l2_direct.c`, a été initiée. L'objectif de cette implémentation est de court-circuiter le passage par la pile réseau `AF_PACKET` afin de minimiser davantage la latence par un accès direct aux buffers du driver radio.

À ce jour, cette version demeure en phase d'investigation. L'intégration complète requiert une synchronisation plus fine avec les interruptions du contrôleur radio, ce qui n'a pas encore atteint l'état de stabilité fonctionnelle nécessaire pour une exploitation en production. Ce module demeure toutefois un axe de développement prioritaire, représentant la prochaine étape logique pour maximiser les performances de l'architecture une fois la plateforme matérielle totalement stabilisée.

=== Analyse de l'empreinte mémoire

Afin de mesurer la quantité de mémoire non volatile occupée par la compilation de la Nanostack et de Zephyr sur le microcontrôleur, une analyse de l'empreinte mémoire a été réalisée. Le @tab:empreinte_memoire détaille l'occupation mémoire pour les trois applications de test développées dans ce projet.

#figure(
  table(
    columns: (2fr, 1.5fr, 1.5fr),
    inset: 10pt,
    align: center + horizon,
    fill: (col, row) => if row == 0 { luma(230) } else { white },
    table.header(
      [*Nom*], [*Flash*], [*RAM*]
    ),
    [`app_ethernet`], [355.728 Ko], [74.256 Ko],
    [`app_border_router`], [516.796 Ko], [120.4 Ko],
    [`app_device_node`], [513.14 Ko], [120.336 Ko]
  ),
  caption: [Empreinte mémoire (Flash et RAM) après compilation]
) <tab:empreinte_memoire>

L'analyse de ces résultats met en évidence plusieurs aspects clés de l'intégration système :

- *Impact fonctionnel de la pile réseau* : L'application filaire (`app_ethernet`) présente l'empreinte la plus réduite avec environ 355 Ko de Flash et 74 Ko de RAM . En revanche, l'activation des fonctionnalités Wi-SUN complètes pour le nœud (`app_device_node`) et le routeur de bordure (`app_border_router`) entraîne une augmentation significative de l'occupation mémoire, atteignant environ 513 Ko à 516 Ko de Flash et 120 Ko de RAM. Cette différence de près de 160 Ko de Flash et 46 Ko de RAM s'explique par l'intégration de la pile de routage maillé (RPL, FHSS, Trickle timers), des services de découverte (PAN Discovery), ainsi que de la bibliothèque de sécurité *Mbed TLS* nécessaire pour l'authentification EAP-TLS de niveau 2.

- *Compatibilité avec la cible matérielle* : Le microcontrôleur CC1352P7 dispose de 704 Ko de Flash (ROM) et 144 Ko de RAM. Les résultats confirment que les deux applications Wi-SUN compilées sont pleinement compatibles avec les limites physiques de la cible. L'occupation de la Flash reste inférieure à 74% de la capacité totale, laissant une marge de sécurité confortable pour le code applicatif. 

- *Marges de la mémoire vive (RAM)* : Avec une consommation de RAM s'élevant à environ 120 Ko (soit 83% de la RAM disponible), la marge de manœuvre restante pour l'exécution d'applications métiers complexes est plus restreinte. Ce constat valide a posteriori les choix d'implémentation stricts effectués lors du portage, notamment la mise en place d'un pool statique de contextes cryptographiques AES au lieu d'allocations dynamiques, afin de prévenir tout risque de fragmentation ou de dépassement de pile (_stack overflow_) en cours d'exécution.