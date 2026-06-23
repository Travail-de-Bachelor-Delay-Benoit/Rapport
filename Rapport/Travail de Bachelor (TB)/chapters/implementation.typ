= Implémentation

== Compilation de la Nanostack

Adapter la *Nanostack*, initialement faite pour *Mbed OS*, à *Zephyr* a été le premier gros chantier. Bien que les deux utilisent *CMake*, ils fonctionnent différemment : *Mbed* est très décentralisé avec ses fichiers de build dans chaque dossier, alors que *Zephyr* centralise tout via son noyau.

Afin de préserver l'intégrité de la base de code d'origine et d'éviter une maintenance complexe, le choix a été fait de l'encapsuler dans un module dédié, `Zephyr-Nanostack`, via un fichier maître orchestrant la compilation.

=== Intégration à l'interface de configuration Kconfig

En plus de *CMake*, il fallait que la stack s'intègre dans le système de configuration de *Zephyr* (*Kconfig* et *Kbuild*). L'idée est de pouvoir activer ou désactiver la stack et ses composants directement via `menuconfig` ou les fichiers `prj.conf`.

#figure(
  caption: [Structure du fichier `Kconfig`],
  supplement: [Listing],
  align(left)[
    ```kconfig
    menuconfig NANOSTACK
        bool "Intégration de la Nanostack"
        select MBEDTLS
        select MBEDTLS_ENTROPY_C
        default n

    if NANOSTACK
      config NANOSTACK_BRIDGE_RADIO
        bool "Utiliser le pont radio (AF_PACKET)"
        default n

      config NANOSTACK_BRIDGE_RADIO_DIRECT
        bool "Utiliser le pont radio direct"
        default n
    endif
    ```
  ]
) <lst_kconfig>

L'avantage est notable : grâce aux directives `select`, *Zephyr* gère les dépendances de manière autonome. Chaque option crée une macro C (`CONFIG_NANOSTACK_BRIDGE_RADIO`) utilisable directement dans le code avec des `#ifdef`.

=== Le fichier CMakeLists.txt maître

==== Gestion conditionnelle de la compilation

Pour que le build reste léger, l'inclusion de la stack est conditionnée. Si l'option n'est pas activée, le compilateur n'accède pas au dossier.

#figure(
  caption: [Compilation conditionnelle],
  supplement: [Listing],
  align(left)[
    ```cmake
    if(CONFIG_NANOSTACK)
        add_subdirectory(nanostack)
    endif()
    ```
  ]
) <lst_cmake_cond>

==== Gestion des dépendances Mbed

Intégrer les composants de *Mbed* (comme `mbed-trace` ou `coap-service`) a été technique : il fallait que *Zephyr* puisse compiler ces modules sans modifier leurs fichiers sources. Pour chaque composant, il a été nécessaire d'extraire les propriétés d'interface, de déclarer les répertoires pour les en-têtes, et lier le tout à la bibliothèque cible.

#figure(
  caption: [Liaison dynamique des dépendances],
  supplement: [Listing],
  align(left)[
    ```cmake
    zephyr_library_include_directories(
        include
        src/nanostack-libservice
        src/mbed-trace/include
        zephyr_port/include
        $<TARGET_PROPERTY:mbed-core,INTERFACE_INCLUDE_DIRECTORIES>
    )

    add_subdirectory(src/mbed-trace)

    zephyr_library_sources(
        $<TARGET_PROPERTY:mbed-core,INTERFACE_SOURCES>
        src/sample.c
    )
    ```
  ]
) <lst_cmake_mbed_integration>

== Architecture du portage et gestion des conflits

Pour garantir une structure propre, l'ensemble des mécanismes d'adaptation a été isolé au sein d'un répertoire dédié, `zephyr_port`. Cette séparation physique est un choix architectural clé pour assurer l'indépendance du code source original et faciliter toute mise à jour ultérieure. Un développeur tiers peut ainsi immédiatement distinguer la logique réseau native de l'adaptation système, qui concentre toute la complexité liée aux API du RTOS.

=== Gestion des conflits de nommage : l'approche par "Glue Code"

Lors de l'intégration, un conflit de nommage critique s'est présenté : le mot-clé `device`, largement utilisé dans la *Nanostack*, entrait en collision avec le fichier d'en-tête `zephyr/device.h`. Pour éviter de renommer des milliers d'occurrences, ce qui aurait rendu toute mise à jour difficilement gérable, une méthode de redirection en deux temps a été mise en place.

D'abord, un fichier `glue.h` a été créé pour faire office de "couche de réécriture" :

#figure(
  caption: [Gestion du conflit `device` via le fichier `glue.h`],
  supplement: [Listing],
  align(left)[
    ```c
    #include <zephyr/kernel.h>
    #include <zephyr/device.h>

    // On renomme device pour éviter la collision
    #define device ns_device

    #include "zephyr_port.h"
    ```
  ]
) <lst_glue_header>

Ensuite, pour appliquer cette règle de manière globale sans altérer les fichiers sources `.c`, le système de build *CMake* a été configuré pour forcer l'inclusion automatique de ce fichier d'en-tête via l'option `-include`. Cette approche est totalement transparente et préserve l'intégrité de la pile originale.

#figure(
  caption: [Forcer l'inclusion de `glue.h` via CMake],
  supplement: [Listing],
  align(left)[
    ```cmake
    target_compile_options(zephyr_library_nanostack PRIVATE
        -include ${PORT_DIR}/include/glue.h
        -fcommon 
        -Wno-error=inline
    )
    ```
  ]
) <lst_cmake_include>

== Abstraction des services système (OS Abstraction Layer)

Comme prévu dans l'état de l'art, la *Nanostack* nécessite une couche d'adaptation pour ses appels système. C'est l'OS Abstraction Layer : un pont entre les besoins de la stack et les services de *Zephyr*.

=== Gestion de la concurrence

Pour éviter les problèmes d'accès concurrents (_race conditions_), un système de sections critiques réentrantes a été implémenté@InterruptsZephyrProject.

#figure(
  caption: [Gestion des sections critiques],
  supplement: [Listing],
  align(left)[
    ```c
    static unsigned int irq_key;
    static volatile int nesting_level = 0;

    void platform_enter_critical() {
        unsigned int key = irq_lock();
        if (nesting_level == 0) irq_key = key;
        nesting_level++;
    }

    void platform_exit_critical() {
        if (nesting_level > 0 && --nesting_level == 0) {
            irq_unlock(irq_key);
        }
    }

    K_SEM_DEFINE(ns_event_sem, 0, 1);
    ```
  ]
) <lst_concurrence>

Un compteur (`nesting_level`) est utilisé pour gérer l'imbrication et un sémaphore est mis en œuvre pour réveiller la pile sans bloquer le reste du système.

=== Gestion temporelle (Timers)

La stack travaille avec des tranches temporelles ("slots") de 50 µs. Ce comportement a été mappé sur les timers de *Zephyr*@TimersZephyrProject en convertissant les slots en microsecondes, avec un arrondi supérieur pour conserver la précision.

#figure(
  caption: [Mapping des timers],
  supplement: [Listing],
  align(left)[
    ```c
    void platform_timer_start(uint16_t slots) {
        k_timer_start(&nanostack_timer, K_USEC(slots * 50), K_NO_WAIT);
    }

    uint16_t platform_timer_get_remaining_slots(void) {
        k_ticks_t remaining = k_timer_remaining_ticks(&nanostack_timer);
        uint32_t us = k_ticks_to_us_floor32(remaining);
        return (uint16_t)((us + 49) / 50); 
    }
    ```
  ]
) <lst_timer_porting>

=== Génération de nombres aléatoires

Enfin, pour l'aléa, la stack d'origine utilisait une gestion manuelle de la graine. Sous *Zephyr*@RandomNumberGeneration, le noyau gère cela de manière plus sécurisée via son générateur de nombres aléatoires matériel . La sécurité a donc été déléguée au système d'exploitation en laissant vides les fonctions de "seed" manuelles.
#import "@preview/mmdr:0.2.2"
#figure(
  caption: [Abstraction de l'aléa],
  supplement: [Listing],
  align(left)[
    ```c
    static inline void randLIB_seed_random(void) { }
    static inline void randLIB_add_seed(uint64_t seed) { }

    static inline uint16_t randLIB_get_16bit(void) {
        return sys_rand16_get();
    }
    ```
  ]
) <lst_random_porting>

=== Intégration de la cryptographie (Mbed TLS)

La pile réseau Nanostack requiert des primitives de chiffrement symétrique AES-CCM-128 pour sécuriser les trames de données de niveau 2. Sous Mbed OS, ces opérations s'appuient sur la bibliothèque *Mbed TLS*. Afin de réaliser ce portage sous Zephyr, les appels cryptographiques propriétaires de la Nanostack (fonctions `arm_aes_start`, `arm_aes_encrypt` et `arm_aes_finish`) ont été mappés vers l'implémentation native de *Mbed TLS* fournie par le noyau Zephyr.

Cette intégration s'organise autour des points techniques suivants :

==== Déclarations Kconfig de Zephyr
L'intégration de Mbed TLS s'effectue de manière transparente en configurant les options requises dans le fichier `Kconfig` de notre module. Grâce aux sélections automatiques (@lst_kconfig_mbedtls), Zephyr se charge de compiler la bibliothèque et de lier le générateur de nombres aléatoires matériel de la puce cible.

#figure(
  caption: [Sélection de Mbed TLS via Kconfig],
  supplement: [Listing],
  align(left)[
    ```kconfig
    menuconfig NANOSTACK
        bool "Intégration de la Nanostack"
        select MBEDTLS
        select MBEDTLS_ENTROPY_C
    ```
  ]
) <lst_kconfig_mbedtls>

==== Allocation statique des contextes AES (`zephyr_port.c`)
La Nanostack requiert l'allocation d'une structure `mbedtls_aes_context` à chaque ouverture de session de chiffrement. Pour éviter l'utilisation de `malloc` qui fragmenterait la mémoire vive (RAM) du microcontrôleur lors du traitement intensif de paquets, un pool statique de contextes réentrants a été implémenté (@lst_aes_porting) :
- Un tableau statique `context_list` d'une taille minimale est déclaré en mémoire.
- La fonction d'allocation `mbed_tls_context_get` parcourt ce pool et réserve un contexte libre sous la protection d'une section critique réentrante (`platform_enter_critical`), évitant ainsi toute corruption par un thread concurrent.
- `arm_aes_start` initialise le contexte avec la clé secrète de 128 bits.
- Une fois le chiffrement terminé par `arm_aes_encrypt`, la fonction `arm_aes_finish` libère le contexte Mbed TLS et remet le drapeau `reserved` à faux pour les futures trames.

#figure(
  caption: [Gestion statique et réeentrante des contextes de chiffrement AES],
  supplement: [Listing],
  align(left)[
    ```c
    struct arm_aes_context {
        mbedtls_aes_context ctx;
        bool reserved;
    };
    static struct arm_aes_context context_list[ARM_AES_MBEDTLS_CONTEXT_MIN];

    static struct arm_aes_context *mbed_tls_context_get(void) {
        platform_enter_critical();
        for (int i = 0; i < ARM_AES_MBEDTLS_CONTEXT_MIN; i++) {
            if (!context_list[i].reserved) {
                context_list[i].reserved = true;
                platform_exit_critical();
                return &context_list[i];
            }
        }
        platform_exit_critical();
        return NULL;
    }

    void *arm_aes_start(const uint8_t *key) {
        struct arm_aes_context *context = mbed_tls_context_get();
        if (context) {
            mbedtls_aes_init(&context->ctx);
            if (0 != mbedtls_aes_setkey_enc(&context->ctx, key, 128)) {
                mbedtls_aes_free(&context->ctx);
                platform_enter_critical();
                context->reserved = false;
                platform_exit_critical();
                return NULL;
            }
        }
        return (void *)context;
    }
    ```
  ]
) <lst_aes_porting>

==== Implémentation des stubs POSIX
Certains fichiers de la bibliothèque *Mbed TLS* compilés pour des architectures génériques font référence à des appels système d'accès aux fichiers (POSIX). N'ayant pas besoin de système de fichiers pour la gestion en mémoire de la cryptographie réseau, des fonctions de substitution (*stubs*) minimales (`open`, `close`, `read`, `write`, `lseek`, `unlink`) retournant simplement `-1` ont été implémentées. Cela permet de satisfaire le lieur (*linker*) sans alourdir le binaire final.


== Couche d'adaptation L2 (Data Link Layer)

La *Nanostack* doit pouvoir s'appuyer sur les pilotes matériels natifs de *Zephyr* pour émettre et recevoir des données. L'objectif ici était de créer un pont (*bridge*) entre l'API de réception de la *Nanostack* (la couche MAC) et les *drivers* L2 de *Zephyr* (Ethernet et IEEE 802.15.4).

=== Mécanisme de pontage réseau

Pour chaque interface, un mécanisme de transfert de paquets bidirectionnel a été mis en place. Concrètement, le pont doit traiter deux flux :

- *Flux descendant (Tx) :* La *Nanostack* envoie des trames formatées. Celles-ci doivent être traduites pour être acceptées par l'interface réseau de *Zephyr*.
- *Flux montant (Rx) :* À chaque réception d'une trame par le driver de *Zephyr*, le paquet est encapsulé et redirigé vers la pile réseau de la *Nanostack* pour traitement.

L'utilisation de deux types de ponts répond à des besoins spécifiques :

- *Pont Ethernet(AF_PACKET) :* Utilisé pour acheminer les trames Ethernet, ce pont exploite l'interface AF_PACKET de Zephyr pour capturer et injecter des trames de couche 2 (Data Link Layer) directement au sein de la pile réseau. 
- *Pont radio (AF_PACKET) :* Utilisé pour les communications sans fil, où la gestion des adresses MAC et la fragmentation sont critiques. Ici, le pont permet de faire transiter des trames brutes (raw frames) directement vers le driver IEEE 802.15.4.
- *Pont radio direct :* Une version simplifiée du pontage, utilisée pour minimiser la latence en court-circuitant certaines vérifications logicielles.

#figure(
  image("../image/bridge.png", width: 80%),
  caption: [Architecture du mécanisme de pontage réseau],

)

Cette adaptation est transparente pour les deux systèmes. La *Nanostack* croit toujours piloter une interface radio ou Ethernet, alors qu'en réalité, elle s'appuie sur la pile réseau de *Zephyr* pour accéder aux ressources matérielles. Cette architecture de "bridge" permet de conserver toute la logique de routage de la *Nanostack* tout en bénéficiant de la fiabilité des drivers *Zephyr* et ainsi éviter la récriture de tous les drivers.

=== Architecture et configuration des ponts réseaux

Le module *zephyr-nanostack* intègre directement la définition et l'implémentation des ponts nécessaires à la communication. Ces composants sont exposés via des fichiers d'en-tête dédiés, garantissant une architecture propre et modulaire.

Pour optimiser l'empreinte mémoire et ne compiler que les composants strictement nécessaires, le choix du pont s'effectue au moment de la configuration via le système *Kconfig*. Ce mécanisme permet de définir le comportement réseau du système dans le fichier `prj.conf` ou via l'interface `menuconfig`.

Le pont Ethernet est activé par défaut si aucune autre option n'est spécifiée, assurant une compatibilité immédiate avec les réseaux filaires. Le pont radio utilisant `AF_PACKET` est activé via l'option `NANOSTACK_BRIDGE_RADIO`, permettant de faire transiter les trames vers le driver IEEE 802.15.4 de *Zephyr*. Enfin, le pont radio direct est accessible via `NANOSTACK_BRIDGE_RADIO_DIRECT` ; cette variante court-circuite certaines étapes logicielles pour minimiser la latence.

#figure(
  image("../image/config_flow.png", width: 70%),
  caption: [Flux de configuration des ponts réseaux]
)

Cette structure offre une grande souplesse. Le développeur peut basculer d'une technologie réseau à une autre sans modifier le code source, mais simplement en ajustant les paramètres de build. Le système de *Kconfig* garantit ainsi qu'aucune logique inutile n'est intégrée dans l'image binaire finale, respectant les contraintes de ressources propres aux systèmes embarqués.

=== Intégration de la liaison Ethernet (bridge_l2.c)

Afin d'assurer la liaison entre le pilote matériel (couche L1), la couche de liaison de Zephyr (couche L2) et la pile Nanostack (qui implémente ses propres couches supérieures L2/L3), il est nécessaire de concevoir une couche d'adaptation. L'objectif est de permettre à la Nanostack de recevoir et d'émettre des trames physiques via le pilote matériel.
Dans un premier temps, les recherches se sont orientées vers l'utilisation de l'API de gestion de la couche de liaison (L2 Layer Management)@L2LayerManagement de Zephyr. Cependant, il est rapidement apparu que les pilotes de périphériques réseau sont liés statiquement et de manière immuable à la couche L2 native de Zephyr (`ETHERNET_L2`). Ce couplage rend impossible tout court-circuitage dynamique à l'exécution, comme le met en évidence la structure de données `net_if_dev` de Zephyr présentée dans le @lst_l2_struct.
#figure(
  caption: [Structure net_if_dev de Zephyr],
  supplement: [Listing],
  align(left)[
    ```c
    struct net_if_dev {
        /** Périphérique matériel associé à l'interface réseau */
        const struct device *dev;
        /** Pointeur strictement constant vers la couche L2 de l'interface */
        const struct net_l2 * const l2;
        /** Pointeur vers les données privées de la couche L2 */
        void *l2_data;
        /* ... Reste de la structure ... */
    };
    ```
  ]
) <lst_l2_struct>
Dans cette structure, la déclaration `const struct net_l2 * const l2;` applique une double contrainte de lecture seule : le pointeur `l2` ainsi que la structure d'API L2 pointée sont définis comme constants. Ces informations sont figées à la compilation, stockées en mémoire Flash (ROM) et ne peuvent donc pas être réassignées en cours d'exécution.
Cette assignation statique provient des macros d'initialisation réseau appelées par le pilote lors de sa compilation, présentées dans le @lst_l2_define :
#figure(
  caption: [Macro d'initialisation d'une interface Ethernet dans Zephyr],
  supplement: [Listing],
  align(left)[
    ```c
    #define Z_ETH_NET_DEVICE_INIT_INSTANCE(node_id, dev_id, name, instance, \
                                           init_fn, pm, data, config, prio, \
                                           api, mtu)                        \
        Z_NET_DEVICE_INIT_INSTANCE(node_id, dev_id, name, instance,         \
                                   init_fn, pm, data, config, prio,         \
                                   api, ETHERNET_L2,                        \
                                   NET_L2_GET_CTX_TYPE(ETHERNET_L2), mtu)
    ```
  ]
) <lst_l2_define>
Comme l'illustre ce Listing, le symbole `ETHERNET_L2` est passé directement en paramètre de macro lors de l'enregistrement de l'interface.
Par conséquent, utiliser une couche L2 alternative (comme celle requise par la Nanostack) directement sur l'interface réseau exigerait de modifier le code source de tous les pilotes de périphériques pour y injecter une autre macro d'initialisation. Pour éviter cette réécriture invasive et préserver l'agnosticisme matériel des pilotes, l'implémentation d'un pont logiciel s'est avérée indispensable. La trame brute est capturée à l'aide d'un socket brut (`AF_PACKET`) et transmise à la Nanostack, contournant ainsi la couche L2 de Zephyr sans altérer le pilote, comme décrit sur le schéma d'architecture ci-dessous (@fig_bridge_arch).
#figure(
  image("../image/bridge_ethernet.png"),
  caption: [Architecture et flux de données à travers le pont logiciel bridge_l2.c],
) <fig_bridge_arch>
Pour pallier les limitations rencontrées lors de l'implémentation d'une couche L2 personnalisée, le choix s'est porté sur l'utilisation des sockets `AF_PACKET`. Ce mécanisme permet d'intercepter les trames Ethernet directement au niveau de la couche de liaison de données, en contournant les piles réseau supérieures de Zephyr.
Cette approche offre une grande maîtrise sur les flux de données :
- *Flux entrant (Rx)* : Les trames Ethernet sont capturées dès leur réception par le pilote matériel, puis injectées directement dans la Nanostack. Ce processus garantit que la pile réseau traite les données brutes sans interférence du noyau.
- *Flux sortant (Tx)* : Les trames générées par la Nanostack sont récupérées avant leur traitement par le système et transmises au driver physique de Zephyr. Cela permet de conserver une totale autonomie sur la construction et l'encapsulation des paquets.
L'avantage majeur de cette méthode réside dans sa capacité à traiter les trames de niveau 2 de manière transparente. En utilisant les sockets `AF_PACKET`, le pont bénéficie de la sûreté des drivers de Zephyr tout en conservant le contrôle complet sur l'intégralité du cycle de vie des paquets au sein de la Nanostack. C'est une solution résiliente qui assure une communication fluide entre la pile réseau et le matériel, sans compromettre l'intégrité du noyau.
Cette architecture, bien qu'extrêmement stable et flexible, introduit une légère surcharge au niveau du traitement des paquets, liée au passage par les sockets `AF_PACKET` et au contexte de commutation entre la pile réseau et le noyau. Toutefois, après analyse, cette perte de performance s'avère négligeable au regard des gains en termes de fiabilité et de maintenabilité. Elle n'impacte en rien la stabilité globale du système.

==== Gestion de la virtualisation d'adresse MAC et du filtrage

La gestion de l'adressage MAC a soulevé une problématique d'unicité sur le support physique. Afin d'éviter tout conflit de boucles réseau ou de collision de paquets, une distinction claire a été implémentée entre l'adresse MAC réelle de l'interface gérée par *Zephyr* et une adresse MAC virtuelle dédiée à la *Nanostack*.
En manipulant le premier octet de l'adresse, comme illustré dans le @lst_mac_fake, le premier octet de l'adresse est modifié afin de forcer l'activation du bit d'administration locale (*Locally Administered Address*). Cette pratique standard permet d'indiquer que cette adresse n'est pas une adresse universelle définie par le constructeur, mais une entité réseau spécifique gérée logiciellement.
#figure(
  caption: [Virtualisation de l'adresse MAC via le bit d'administration locale],
  supplement: [Listing],
  align(left)[
    ```c
    // Récupération de la MAC réelle de l'interface
    struct net_linkaddr *link_addr = net_if_get_link_addr(iface);
    memcpy(nanostack_mac_addr, link_addr->addr, 6);
    // Forçage du bit d'administration locale (LAA)
    // Cela distingue l'entité Nanostack de l'interface Zephyr
    nanostack_mac_addr[0] |= 0x02;
    ```
  ]
) <lst_mac_fake>
Cette séparation est indispensable pour que la *Nanostack* opère comme un nœud distinct sur le réseau physique, alors même qu'elle partage le même contrôleur Ethernet que le système hôte. 
Trois aspects techniques critiques complètent cette implémentation au sein de `bridge_l2.c` :
1. *Le Mode Promiscuous* : L'appel à `net_if_set_promisc(iface)` force le contrôleur Ethernet physique à accepter tous les paquets du média, y compris ceux destinés à notre MAC virtuelle. Sans cela, le filtre matériel du contrôleur rejetterait immédiatement les trames destinées à la Nanostack.
2. *Le filtrage du Loopback local* : Lors de l'envoi de trames via le socket brut `AF_PACKET`, Zephyr copie par défaut ces trames sur tous les sockets écouteurs de cette interface. Le thread de réception (`listening_thread`) doit donc vérifier si la MAC source de la trame reçue correspond à la MAC virtuelle (`nanostack_mac_addr`). Si c'est le cas, la trame est ignorée pour couper court à une boucle de rétroaction infinie.
3. *L'IID et l'Autoconfiguration IPv6* : L'adresse MAC virtuelle est passée à la fonction `my_iid64_get` afin de calculer l'identifiant d'interface (IID) IPv6 conforme aux RFC de routage. Cet IID est forcé dans les champs `iid_eui64` et `iid_slaac` de la Nanostack. Les adresses IPv6 générées par auto-configuration (SLAAC) dérivent ainsi proprement de la MAC virtuelle et n'entrent pas en collision avec celles de Zephyr.

=== Intégration de la liaison Radio AF_PACKET (bridge_l2_radio.c)

Contrairement à la liaison Ethernet où la couche de liaison L2 de Zephyr gère la quasi-totalité des opérations d'encapsulation de manière transparente, l'intégration d'une radio IEEE 802.15.4 (Sub-GHz) requiert un contrôle beaucoup plus fin de la couche physique (L1) par la pile Nanostack. La stack doit pouvoir piloter l'état de la radio, initier l'écoute du canal (CCA - *Clear Channel Assessment*), changer de fréquence ou encore obtenir les métriques de qualité de lien (LQI et RSSI).

Pour répondre à ces exigences, le pont `bridge_l2_radio.c` enregistre un pilote physique virtuel auprès de la Nanostack via la structure `phy_device_driver_s`. Les callbacks de cette structure redirigent les requêtes matérielles de la Nanostack vers l'API radio native de Zephyr (`ieee802154_radio_api`), tout en utilisant des sockets bruts `AF_PACKET` pour le transit des trames de données.

==== Architecture de séparation des Sockets (Socket Split) et Thread RX

L'implémentation initiale utilisant un unique socket bidirectionnel sur la file de travail système de Zephyr (*system work queue*) provoquait des interblocages (*deadlocks*) et des pertes de paquets lors d'un trafic bidirectionnel intense.

Pour y pallier, une architecture de séparation des descripteurs de sockets a été mise en place (@lst_socket_split) :
1. Un socket dédié exclusivement à l'émission : `radio_bridge_sock_tx`.
2. Un socket dédié exclusivement à la réception : `radio_bridge_sock_rx`.

#figure(
  caption: [Initialisation et séparation des sockets TX et RX],
  supplement: [Listing],
  align(left)[
    ```c
    // Création du socket d'émission (TX)
    radio_bridge_sock_tx = zsock_socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
    zsock_bind(radio_bridge_sock_tx, (struct sockaddr *)&sll, sizeof(sll));

    // Création du socket de réception (RX)
    radio_bridge_sock_rx = zsock_socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
    zsock_bind(radio_bridge_sock_rx, (struct sockaddr *)&sll, sizeof(sll));
    ```
  ]
) <lst_socket_split>

Cette séparation s'accompagne d'un thread d'écoute dédié à la réception (`radio_rx_thread`), s'exécutant de manière asynchrone avec une priorité temps réel. Ce thread boucle sur un appel bloquant à `zsock_recvfrom` pour intercepter les trames entrantes et les réinjecter immédiatement dans la Nanostack via le callback `phy_rx_cb` (@lst_rx_thread).

#figure(
  caption: [Thread de réception radio asynchrone et filtrage],
  supplement: [Listing],
  align(left)[
    ```c
    static void radio_rx_thread(void *p1, void *p2, void *p3) {
        static uint8_t rx_buf[2048];
        struct sockaddr_ll src_addr;
        socklen_t addr_len;

        while (1) {
            addr_len = sizeof(src_addr);
            int len = zsock_recvfrom(radio_bridge_sock_rx, rx_buf, sizeof(rx_buf), 0,
                                     (struct sockaddr *)&src_addr, &addr_len);
            
            // Élimination des trames émises par notre propre nœud (loopback)
            if (src_addr.sll_pkttype == PACKET_OUTGOING) {
                continue;
            }

            // Transmission de la trame brute directement à la Nanostack
            if (radio_driver.phy_rx_cb && radio_phy_id >= 0) {
                nanostack_lock();
                radio_driver.phy_rx_cb(rx_buf, len, 255, -50, radio_phy_id);
                nanostack_unlock();
            }
        }
    }
    ```
  ]
) <lst_rx_thread>

Cette structure asynchrone évite que le traitement d'une réception ne vienne bloquer la boucle d'émission de paquets ou le cœur d'ordonnancement de la Nanostack.

==== Cycle de transmission et émulation de fin d'émission (TX State Machine)

Lors de l'émission d'un paquet, la Nanostack appelle la fonction `radio_tx`. Afin de respecter le protocole CSMA-CA (évitement de collision) sans bloquer le thread appelant, le pont utilise une machine à états asynchrone s'appuyant sur le gestionnaire de tâches de Zephyr (*K_WORK*) et des timers. 

Le flux d'émission se déroule comme suit :
1. `radio_tx` copie le paquet dans un tampon temporaire `pending_tx_buf` et planifie la tâche `tx_prepare_work`.
2. Le gestionnaire `tx_prepare_work_handler` interroge la pile pour s'assurer que le canal est libre (`PHY_LINK_CCA_PREPARE`).
3. Si le canal est libre, le paquet est envoyé sur le média via le socket `radio_bridge_sock_tx`.
4. Le temps de transmission physique est estimé en fonction du nombre d'octets et du débit de modulation configuré (`radio_channel_config.datarate`). Un timer de fin de transmission (`tx_done_timer`) est alors démarré avec cette durée calculée.
5. À l'expiration du timer, la fonction de rappel `phy_tx_done_cb` est appelée avec le statut `PHY_LINK_TX_SUCCESS`, indiquant à la Nanostack qu'elle peut libérer ses tampons et planifier le paquet suivant.

==== Limitation des fréquences et contournement du pilote Texas Instruments CC1352

Un défi majeur est apparu lors des phases de test avec les modules Texas Instruments CC1352P7. Le protocole Wi-SUN en Europe est conçu pour s'étendre sur la bande 863 MHz découpée en 35 canaux (de 0 à 34). Lors de la phase de découverte du réseau (*PAN Discovery*), la Nanostack tente d'effectuer des sauts de fréquence automatiques sur l'ensemble de ces canaux.

Cependant, l'examen approfondi du code source du pilote d'origine fourni par Texas Instruments dans Zephyr (`zephyr/drivers/ieee802154/ieee802154_cc13xx_cc26xx_subg.c`) révèle une limitation logicielle stricte. La fonction chargée de calculer la fréquence à configurer sur la puce radio n'autorise que le canal 0 (868.3 MHz) et rejette systématiquement les canaux supérieurs à 10, comme le montre le  @lst_ti_driver_bug.

#figure(
  caption: [Limitation des canaux dans le pilote de périphérique TI CC1352 de Zephyr],
  supplement: [Listing],
  align(left)[
    ```c
    static inline int drv_channel_frequency(uint16_t channel, uint16_t *frequency, uint16_t *fractFreq)
    {
        /* ... */
        if (channel == 0) {
            *frequency = 868;
            *fractFreq = 0x4ccd; // Fréquence de 868.3 MHz
        } else if (channel <= 10) {
            *frequency = 906 + 2 * (channel - 1); // Bande US 915 MHz
            *fractFreq = 0;
        } else {
            *frequency = 0;
            *fractFreq = 0;
            return channel <= 26 ? -ENOTSUP : -EINVAL; // Erreur renvoyée !
        }
        /* TODO: This incorrectly mixes up legacy BPSK SubGHz PHY channel page
         * zero frequency calculation with SUN FSK operating mode #3 PHY radio... */
        return 0;
    }
    ```
  ]
) <lst_ti_driver_bug>

Comme l'indique explicitement le commentaire `TODO` laissé par les développeurs du pilote, le calcul des fréquences mélange par erreur la configuration historique BPSK de la page 0 avec les nouveaux paramètres requis par la modulation SUN FSK (utilisée par Wi-SUN). Le pilote est donc incapable de calculer dynamiquement la fréquence pour un canal Wi-SUN valide (comme le canal 12 ou 24 sur la page de canaux 9).

Pour contourner cette limitation du constructeur sans avoir à réécrire intégralement le pilote de périphérique de la puce CC1352, un filtrage logique applicatif a été implémenté via l'API de gestion Wi-SUN. En configurant un masque de canaux restrictif à l'aide de la fonction `ws_management_channel_mask_set` (en forçant le bit du canal 0 à 1 et tous les autres à 0), la Nanostack a été contrainte à rester exclusivement sur le canal 0. 

Cette approche a permis de valider notre objectif premier : apporter la preuve de concept que notre pont radio fonctionne, et que les nœuds parviennent à s'échanger des trames physiques sur l'unique fréquence opérationnelle de 868.3 MHz. Néanmoins, cette configuration figeant la communication sur un canal unique empêche l'activation du mécanisme de saut de fréquence (FHSS) obligatoire pour la certification Wi-SUN. Bien que la communication radio soit fonctionnelle et démontrée, le système ne peut pas dans cet état établir un véritable réseau Wi-SUN conforme aux spécifications standard.

==== Étude d'une alternative : Le pont radio direct et ses limitations

Dans l'optique d'optimiser au maximum la latence de transmission et d'éliminer la surcharge induite par le passage par les sockets du noyau, une variante nommée "pont direct" (`bridge_l2_radio_direct.c`) a été conçue et expérimentée. 

L'idée théorique était de court-circuiter entièrement la pile réseau de Zephyr :
- *En réception (Rx)* : Enregistrer un filtre réseau synchrone (`net_pkt_filter`) pour capturer la trame dès sa réception par le pilote et la transmettre directement à la Nanostack, en demandant au noyau de détruire le paquet d'origine pour éviter un double traitement.
- *En émission (Tx)* : Allouer un paquet brut et appeler directement la fonction d'émission physique du transceiver (`radio_api->tx`) exposée par le pilote matériel de Zephyr, sans passer par les abstractions supérieures.

Bien que séduisante, cette implémentation s'est avérée instable et a conduit à des dysfonctionnements critiques. L'analyse de ces échecs a mis en lumière trois contraintes architecturales majeures de Zephyr :

1. *Le problème de la fragmentation mémoire (RX)* :
   Les paquets réseau dans Zephyr (`net_pkt`) sont stockés sous forme de listes chaînées de fragments de tampons (`net_buf`). Dans l'implémentation directe, la lecture brute des données via `buf->data` ne lisait que le premier fragment, alors que la taille passée correspondait à la trame entière. Cela provoquait des lectures hors limites de la mémoire (*buffer overflow* en lecture), menant à des corruptions de données et des plantages système (*Kernel Panic*). Pour résoudre cela proprement, il aurait fallu réimplémenter une copie linéaire complète via `net_pkt_read`, annulant le gain de performance espéré.

2. *L'inversion de contexte et les interblocages (Deadlocks)* :
   Les règles de filtrage de paquets (`net_pkt_filter`) sont exécutées directement dans le contexte d'interruption (ISR) du pilote matériel ou dans le thread réseau à haute priorité de Zephyr (`net_rx`). Appeler le callback de traitement de la Nanostack dans ce contexte forçait le processeur à exécuter la logique de routage L3 complexe au milieu de l'ISR. De plus, la nécessité d'acquérir le verrou `nanostack_lock()` dans ce contexte d'interruption créait des conflits d'exclusion mutuelle avec les autres threads, provoquant des interblocages (*deadlocks*) complets du système.

3. *L'absence de synchronisation de l'émetteur (TX)* :
   L'API physique `radio_api->tx` initie l'envoi de manière asynchrone au niveau matériel. Signaler immédiatement une réussite de transmission (`PHY_LINK_TX_SUCCESS`) à la Nanostack dès le retour de cette fonction — sans attendre le déroulement du protocole CSMA-CA ni la réception de l'acquittement physique (ACK) par la puce radio — faussait complètement la logique de retransmission de la pile réseau, causant d'importantes pertes de paquets.

Cette tentative infructueuse a ainsi démontré qu'un pont direct synchrone brise l'isolation des contextes de Zephyr. Cela a pleinement validé le choix de notre architecture finale basée sur les sockets `AF_PACKET` avec séparation des canaux d'émission et de réception, qui délègue proprement la gestion des files d'attente et le changement de contexte de thread au système d'exploitation.

=== Boucle d'événements et ordonnancement (event_loop.c)

La pile réseau Nanostack est conçue selon un modèle asynchrone événementiel. Elle n'exécute pas de threads en interne, mais s'appuie sur son propre ordonnanceur non préemptif coopératif (`eventOS_scheduler`). Cet ordonnanceur empile les tâches (timers, réceptions de trames, calculs de routes) dans une file d'attente globale et attend qu'un thread hôte les exécute séquentiellement.

Afin d'intégrer ce modèle dans l'architecture préemptive de Zephyr, une boucle d'événements dédiée a été implémentée au sein du fichier `event_loop.c` (@lst_event_loop).

#figure(
  caption: [Boucle d'événements et thread dédié à la Nanostack],
  supplement: [Listing],
  align(left)[
    ```c
    static void nanostack_thread_entry(void *p1, void *p2, void *p3) {
        while (1) {
            // Exécution verrouillée de l'ordonnanceur coopératif
            nanostack_lock();
            eventOS_scheduler_run_until_idle();
            nanostack_unlock();

            // Mise en veille optimale jusqu'au prochain événement matériel
            k_sem_take(&ns_event_sem, K_FOREVER);
        }
    }

    // Déclaration du thread avec priorité temps réel préemptive de 0
    K_THREAD_DEFINE(nanostack_thread_id, 8192, nanostack_thread_entry, 
                    NULL, NULL, NULL, 0, 0, -1);
    ```
  ]
) <lst_event_loop>

Cette implémentation repose sur trois concepts clés :

1. *Un thread@ThreadsZephyrProject dédié de haute priorité* : La Nanostack traite des protocoles réseau sensibles au facteur temps (comme le saut de fréquence en Wi-SUN). Le thread `nanostack_thread_id` est donc instancié avec une priorité préemptive de 0 (la plus haute priorité pour les threads applicatifs de Zephyr) et une pile confortable de 8 Ko pour éviter tout débordement lors des calculs cryptographiques ou de routage.
2. *L'accès exclusif à la pile réseau (`nanostack_lock`)* : Afin d'éviter les accès concurrents destructeurs entre les threads de réception réseau de Zephyr et la boucle d'ordonnancement de la Nanostack, l'appel à `eventOS_scheduler_run_until_idle()` est entièrement encapsulé dans une section d'exclusion mutuelle (*Mutex*).
3. *Mise en veille et optimisation énergétique (`K_FOREVER`)* : Une fois que l'ordonnanceur a traité tous les événements en attente et est devenu inactif (*idle*), le thread s'endort sur le sémaphore `ns_event_sem`. 
   - *Choix du `K_FOREVER`* : Pendant la phase de développement, un timeout temporaire de 1 ms (`K_MSEC(1)`) avait été mis en place comme sécurité (*fallback*) pour forcer le réveil périodique de la pile en cas de signal manqué. Une fois le portage fiabilisé, ce timeout a été remplacé par `K_FOREVER`. La Nanostack notifiant systématiquement chaque nouvel événement (expiration de timer, réception de paquets) via l'appel `eventOS_scheduler_signal()`, le réveil est garanti à chaque événement réel.
   - *Impact sur la consommation* : L'utilisation de `K_FOREVER` évite 1000 réveils de contexte inutiles par seconde. Lorsque la file d'attente est vide, le microcontrôleur peut basculer immédiatement sur son thread d'inactivité (*Idle Thread*), coupant les horloges internes du processeur via l'instruction `WFI` (Wait For Interrupt) et optimisant ainsi grandement l'autonomie sur batterie.

