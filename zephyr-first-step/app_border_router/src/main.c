#include <string.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

#define TRACE_GROUP "MAIN"
#include "bridge_l2_radio.h"
#include "eventOS_event.h"
#include "eventOS_event_timer.h"
#include "eventOS_scheduler.h"
#include "event_loop.h"
#include "mbed_trace.h"
#include "net_interface.h"
#include "ns_types.h"
#include "nsdynmemLIB.h"
#include "socket_api.h"
#include "wisun_certificates.h"
#include "ws_management_api.h"
#include "ws_bbr_api.h"
#include "ethernet_mac_api.h"

#define APP_ROLE_STR "BORDER_ROUTER"

uint8_t ns_heap[65536] __aligned(8);
static int8_t app_tasklet_id = -1;
static int8_t app_udp_socket = -1;
static int8_t nwk_interface_id = -1;
static int8_t backbone_interface_id = -1;
static bool bootstrap_ready = false;

#define UDP_PORT 12345

static const char *nwk_status_str(arm_nwk_interface_status_type_e status)
{
    switch (status)
    {
    case ARM_NWK_BOOTSTRAP_READY:
        return "BOOTSTRAP_READY (0)";
    case ARM_NWK_RPL_INSTANCE_FLOODING_READY:
        return "RPL_INSTANCE_FLOODING_READY (1)";
    case ARM_NWK_SET_DOWN_COMPLETE:
        return "SET_DOWN_COMPLETE (2)";
    case ARM_NWK_NWK_SCAN_FAIL:
        return "NWK_SCAN_FAIL (3)";
    case ARM_NWK_IP_ADDRESS_ALLOCATION_FAIL:
        return "IP_ADDRESS_ALLOCATION_FAIL (4)";
    case ARM_NWK_DUPLICATE_ADDRESS_DETECTED:
        return "DUPLICATE_ADDRESS_DETECTED (5)";
    case ARM_NWK_AUHTENTICATION_START_FAIL:
        return "AUTHENTICATION_START_FAIL (6)";
    case ARM_NWK_AUHTENTICATION_FAIL:
        return "AUTHENTICATION_FAIL (7)";
    case ARM_NWK_NWK_CONNECTION_DOWN:
        return "NWK_CONNECTION_DOWN (8)";
    case ARM_NWK_NWK_PARENT_POLL_FAIL:
        return "NWK_PARENT_POLL_FAIL (9)";
    case ARM_NWK_PHY_CONNECTION_DOWN:
        return "PHY_CONNECTION_DOWN (10)";
    default:
        return "INCONNU";
    }
}

static void print_interface_addresses(int8_t interface_id)
{
    int n = 0;
    uint8_t addr[16];
    printk("[%s] Adresses IP de l'interface (ID %d) :\n", APP_ROLE_STR, interface_id);
    while (arm_net_address_list_get_next(interface_id, &n, addr) == 0)
    {
        printk("  - %02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x\n",
               addr[0], addr[1], addr[2], addr[3], addr[4], addr[5], addr[6], addr[7],
               addr[8], addr[9], addr[10], addr[11], addr[12], addr[13], addr[14], addr[15]);
    }
}

void app_socket_callback(void *cb_data)
{
    socket_callback_t *cb = (socket_callback_t *)cb_data;

    if (cb->event_type == SOCKET_DATA)
    {
        uint8_t rx_buf[128];
        ns_address_t src_addr;

        int16_t len = socket_recvfrom(cb->socket_id, rx_buf, sizeof(rx_buf) - 1, 0, &src_addr);
        if (len > 0)
        {
            rx_buf[len] = '\0';
            printk("[%s] Recu de [", APP_ROLE_STR);
            for (int i = 0; i < 16; i++)
            {
                printk("%02x", src_addr.address[i]);
                if (i % 2 == 1 && i < 15)
                    printk(":");
            }
            printk("]:%d -> %s", src_addr.identifier, rx_buf);
        }
    }
    else if (cb->event_type == SOCKET_TX_FAIL)
    {
        printk("[%s] Echec de l'envoi de trame UDP (SOCKET_TX_FAIL)\n", APP_ROLE_STR);
    }
}

void app_tasklet_handler(arm_event_s *event)
{
    if (event->event_type == ARM_LIB_TASKLET_INIT_EVENT)
    {
        printk("[%s] Initialisation du socket UDP sur le port %d...\n", APP_ROLE_STR, UDP_PORT);

        app_udp_socket = socket_open(SOCKET_UDP, UDP_PORT, app_socket_callback);
        if (app_udp_socket < 0)
        {
            printk("[%s] Erreur d'ouverture du socket UDP: %d\n", APP_ROLE_STR, app_udp_socket);
        }
        else
        {
            printk("[%s] Socket UDP ouvert avec succes (ID=%d)\n", APP_ROLE_STR, app_udp_socket);
        }

        arm_nwk_interface_down(nwk_interface_id);

        // 1. Configurer le bootstrap Wi-SUN Border Router
        int8_t ws_boot = arm_nwk_interface_configure_6lowpan_bootstrap_set(
            nwk_interface_id,
            NET_6LOWPAN_BORDER_ROUTER,
            NET_6LOWPAN_WS);
        printk("[%s] arm_nwk_interface_configure_6lowpan_bootstrap_set (Wi-SUN): %d\n", APP_ROLE_STR, ws_boot);

        // 2. Enregistrer les certificats de test pour l'authentificateur EAP-TLS de Wi-SUN
        arm_certificate_entry_s trusted_cert = {
            .cert = WISUN_ROOT_CERTIFICATE,
            .key = NULL,
            .cert_len = sizeof(WISUN_ROOT_CERTIFICATE),
            .key_len = 0};
        int8_t cert_ret1 = arm_network_trusted_certificate_add(&trusted_cert);
        printk("[%s] Ajout certificat racine de confiance: %d\n", APP_ROLE_STR, cert_ret1);

        arm_certificate_entry_s own_cert = {
            .cert = WISUN_SERVER_CERTIFICATE,
            .key = WISUN_SERVER_KEY,
            .cert_len = sizeof(WISUN_SERVER_CERTIFICATE),
            .key_len = sizeof(WISUN_SERVER_KEY)};
        int8_t cert_ret2 = arm_network_own_certificate_add(&own_cert);
        printk("[%s] Ajout certificat serveur propre: %d\n", APP_ROLE_STR, cert_ret2);

        // 3. Recuperer le timer FHSS exporte par le pont radio
        fhss_timer_t *fhss_timer = (fhss_timer_t *)bridge_l2_radio_fhss_timer_get();
        printk("[%s] Adresse FHSS Timer: %p\n", APP_ROLE_STR, fhss_timer);

        // 4. Initialiser la gestion Wi-SUN sur l'interface radio
        int8_t ws_init = ws_management_node_init(nwk_interface_id, REG_DOMAIN_EU, "Wi-SUN-Network", fhss_timer);
        printk("[%s] ws_management_node_init: %d\n", APP_ROLE_STR, ws_init);

        // 5. Configurer le domaine reglementaire (Europe Sub-GHz, 50kbps mode 1a)
        int8_t ws_domain = ws_management_regulatory_domain_set(nwk_interface_id, REG_DOMAIN_EU, 2, OPERATING_MODE_1a);
        printk("[%s] ws_management_regulatory_domain_set: %d\n", APP_ROLE_STR, ws_domain);

        // Restreindre le masque de canaux au canal 0 uniquement pour correspondre au pilote CC1352
        uint32_t channel_mask[8] = {0};
        channel_mask[0] = 1; // Bit 0 à 1 (seul le canal 0 est autorisé)
        int8_t ws_mask = ws_management_channel_mask_set(nwk_interface_id, channel_mask);
        printk("[%s] ws_management_channel_mask_set: %d\n", APP_ROLE_STR, ws_mask);

        // Configurer les fonctions de canal unicast et broadcast en mode fixe (Fixed Channel 0)
        int8_t ws_uc_fhss = ws_management_fhss_unicast_channel_function_configure(nwk_interface_id, 0, 0, 0);
        printk("[%s] ws_management_fhss_unicast_channel_function_configure: %d\n", APP_ROLE_STR, ws_uc_fhss);

        int8_t ws_bc_fhss = ws_management_fhss_broadcast_channel_function_configure(nwk_interface_id, 0, 0, 0, 0);
        printk("[%s] ws_management_fhss_broadcast_channel_function_configure: %d\n", APP_ROLE_STR, ws_bc_fhss);

        // 6. Configurer la securite link layer
        arm_nwk_link_layer_security_mode(nwk_interface_id, NET_SEC_MODE_NO_LINK_SECURITY, 0, NULL);

        // 7. Configurer le BBR
        int8_t bbr_pan = ws_bbr_pan_configuration_set(nwk_interface_id, 0x1234);
        printk("[%s] ws_bbr_pan_configuration_set: %d\n", APP_ROLE_STR, bbr_pan);

        int8_t bbr_cfg = ws_bbr_configure(nwk_interface_id, BBR_ULA_C | BBR_DEFAULT_ROUTE);
        printk("[%s] ws_bbr_configure: %d\n", APP_ROLE_STR, bbr_cfg);

        int8_t bbr_start = ws_bbr_start(nwk_interface_id, backbone_interface_id);
        printk("[%s] ws_bbr_start: %d\n", APP_ROLE_STR, bbr_start);

        int8_t up_status = arm_nwk_interface_up(nwk_interface_id);
        printk("[%s] arm_nwk_interface_up: %d\n", APP_ROLE_STR, up_status);

        eventOS_event_timer_request(1, 102, app_tasklet_id, 2000);
    }
    // PHY mode : 5arm_nwk_link_layer_security_mode
    //
    else if (event->event_type == ARM_LIB_NWK_INTERFACE_EVENT)
    {
        arm_nwk_interface_status_type_e status = (arm_nwk_interface_status_type_e)event->event_data;
        printk("[%s] Evenement Interface Reseau : %s\n", APP_ROLE_STR, nwk_status_str(status));

        if (status == ARM_NWK_BOOTSTRAP_READY)
        {
            printk("[%s] Bootstrap OK ! Interface prete.\n", APP_ROLE_STR);
            bootstrap_ready = true;
            print_interface_addresses(nwk_interface_id);
        }
        else
        {
            bootstrap_ready = false;
            if (status == ARM_NWK_IP_ADDRESS_ALLOCATION_FAIL)
            {
                printk("[%s] Echec de l'allocation d'adresse IP.\n", APP_ROLE_STR);
            }
        }
    }
    else if (event->event_type == 102)
    {
        eventOS_event_timer_request(1, 102, app_tasklet_id, 2000);
    }
}

static eth_mac_api_t dummy_eth_mac_api;
static uint8_t dummy_eth_mac[6] = {0x02, 0x11, 0x22, 0x33, 0x44, 0x55};

static int8_t dummy_eth_mac48_get(const eth_mac_api_t *api, uint8_t *mac_dest)
{
    memcpy(mac_dest, dummy_eth_mac, 6);
    return 0;
}

static int8_t dummy_eth_iid64_get(const eth_mac_api_t *api, uint8_t *iid_ptr)
{
    iid_ptr[0] = dummy_eth_mac[0] ^ 0x02;
    iid_ptr[1] = dummy_eth_mac[1];
    iid_ptr[2] = dummy_eth_mac[2];
    iid_ptr[3] = 0xFF;
    iid_ptr[4] = 0xFE;
    iid_ptr[5] = dummy_eth_mac[3];
    iid_ptr[6] = dummy_eth_mac[4];
    iid_ptr[7] = dummy_eth_mac[5];
    return 0;
}

static int8_t dummy_eth_mac48_set(const eth_mac_api_t *api, const uint8_t *mac_src)
{
    memcpy(dummy_eth_mac, mac_src, 6);
    return 0;
}

static void dummy_eth_data_req(const eth_mac_api_t *api, const eth_data_req_t *data)
{
    // Interface mock, rien a envoyer physiquement
}

static int8_t dummy_eth_mac_initialize(eth_mac_api_t *api,
                                       eth_mac_data_confirm *conf_cb,
                                       eth_mac_data_indication *ind_cb,
                                       uint8_t parent_id)
{
    api->parent_id = parent_id;
    api->data_conf_cb = conf_cb;
    api->data_ind_cb = ind_cb;
    return 0;
}

static int8_t setup_dummy_backbone_interface(void)
{
    dummy_eth_mac_api.data_req = dummy_eth_data_req;
    dummy_eth_mac_api.mac_initialize = dummy_eth_mac_initialize;
    dummy_eth_mac_api.mac48_get = dummy_eth_mac48_get;
    dummy_eth_mac_api.mac48_set = dummy_eth_mac48_set;
    dummy_eth_mac_api.iid64_get = dummy_eth_iid64_get;
    dummy_eth_mac_api.address_resolution_needed = true;

    int8_t backbone_id = arm_nwk_interface_ethernet_init(&dummy_eth_mac_api, "eth0");
    if (backbone_id >= 0)
    {
        arm_nwk_interface_configure_ipv6_bootstrap_set(backbone_id, NET_IPV6_BOOTSTRAP_AUTONOMOUS, NULL);
        arm_nwk_interface_up(backbone_id);
    }
    return backbone_id;
}

static void trace_printer(const char *str)
{

    printk("%s\n", str);
}

int main(void)
{
    printk("\n--- NANOSTACK DIRECT RADIO BRIDGE TEST APPLICATION (%s) ---\n", APP_ROLE_STR);

    mbed_trace_init();
    mbed_trace_print_function_set(trace_printer);
    mbed_trace_config_set(TRACE_ACTIVE_LEVEL_ALL | TRACE_MODE_COLOR);

    ns_dyn_mem_init(ns_heap, sizeof(ns_heap), NULL, NULL);
    eventOS_scheduler_init();

    backbone_interface_id = setup_dummy_backbone_interface();
    if (backbone_interface_id < 0)
    {
        printk("ERREUR CRITIQUE: Impossible d'initialiser le backbone Ethernet.\n");
        return -1;
    }
    printk("Interface backbone Ethernet (eth0) initialisee avec ID: %d\n", backbone_interface_id);

    nwk_interface_id = setup_nanostack_bridge_radio();
    if (nwk_interface_id < 0)
    {
        printk("ERREUR CRITIQUE: Impossible d'initialiser le bridge radio.\n");
        return -1;
    }

    printk("Interface pont radio (AF_PACKET) initialisee avec ID: %d\n", nwk_interface_id);

    app_tasklet_id = eventOS_event_handler_create(&app_tasklet_handler, 0);

    nanostack_event_loop_start();

    while (1)
    {
        k_msleep(1000);
    }
}
