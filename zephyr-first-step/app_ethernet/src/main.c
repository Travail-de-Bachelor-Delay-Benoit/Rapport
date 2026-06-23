#include <string.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>
#define TRACE_GROUP "MAIN"
#include "bridge_l2.h"
#include "eventOS_event.h"
#include "eventOS_event_timer.h" // <-- IMPORTANT
#include "eventOS_scheduler.h"
#include "event_loop.h"
#include "mbed_trace.h"
#include "net_interface.h"
#include "ns_types.h"
#include "nsdynmemLIB.h"
#include "socket_api.h"

extern void system_timer_tick_update(uint32_t ticks);
uint8_t ns_heap[16384] __aligned(8);
static int8_t app_tasklet_id = -1;
static int8_t icmp_sock = -1;
static int8_t id;

static int8_t app_tcp_listener = -1;
static int8_t app_tcp_client_socket = -1;
static uint32_t send_counter = 0;

void app_tcp_client_callback(void *cb_data)
{
  socket_callback_t *cb = (socket_callback_t *)cb_data;
  if (cb->event_type == SOCKET_CONNECT_CLOSED ||
      cb->event_type == SOCKET_CONNECTION_RESET ||
      cb->event_type == SOCKET_TX_FAIL)
  {
    printk("Client TCP deconnecte (event=0x%x).\n", cb->event_type);
    socket_close(cb->socket_id);
    if (cb->socket_id == app_tcp_client_socket)
    {
      app_tcp_client_socket = -1;
    }
  }
}

void app_tcp_listener_callback(void *cb_data)
{
  socket_callback_t *cb = (socket_callback_t *)cb_data;
  if (cb->event_type == SOCKET_INCOMING_CONNECTION)
  {
    ns_address_t client_addr;
    int8_t client_sock =
        socket_accept(cb->socket_id, &client_addr, app_tcp_client_callback);
    if (client_sock >= 0)
    {
      printk("Nouveau client TCP connecte ! IP: ");
      for (int i = 0; i < 16; i++)
      {
        printk("%02x", client_addr.address[i]);
        if (i % 2 == 1 && i < 15)
          printk(":");
      }
      printk(", Port: %d\n", client_addr.identifier);

      // Fermer l'ancien client s'il y en avait un actif
      if (app_tcp_client_socket >= 0)
      {
        socket_close(app_tcp_client_socket);
      }
      app_tcp_client_socket = client_sock;
    }
  }
}

static void print_interface_addresses(int8_t interface_id)
{
  int n = 0;
  uint8_t addr[16];
  printk("Adresses IP de l'interface (ID %d) :\n", interface_id);
  while (arm_net_address_list_get_next(interface_id, &n, addr) == 0)
  {
    printk("  - "
           "%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%"
           "02x%02x\n",
           addr[0], addr[1], addr[2], addr[3], addr[4], addr[5], addr[6],
           addr[7], addr[8], addr[9], addr[10], addr[11], addr[12], addr[13],
           addr[14], addr[15]);
  }
}

void app_tasklet_handler(arm_event_s *event)
{
  if (event->event_type == ARM_LIB_TASKLET_INIT_EVENT)
  {
    // Ouvrir le socket TCP Nanostack en mode ecoute sur le port 12345
    app_tcp_listener =
        socket_open(SOCKET_TCP, 12345, app_tcp_listener_callback);
    if (app_tcp_listener < 0)
    {
      printk("Erreur d'ouverture du socket TCP: %d\n", app_tcp_listener);
    }
    else
    {
      socket_listen(app_tcp_listener, 1);
      printk("Serveur TCP Nanostack en ecoute sur le port 12345 !\n");
    }

    // Timer de 1 seconde (1000 millisecondes)
    eventOS_event_timer_request(1, 102, app_tasklet_id, 1000);
    printk("Tasklet pret, serveur TCP configure...\n");
  }
  else if (event->event_type == ARM_LIB_NWK_INTERFACE_EVENT)
  {
    arm_nwk_interface_status_type_e status =
        (arm_nwk_interface_status_type_e)event->event_data;
    printk("Evenement Interface Reseau recu ! Status: %d\n", status);

    if (status == ARM_NWK_BOOTSTRAP_READY)
    {
      printk("=> Bootstrap pret ! IP obtenue(s) avec succes.\n");
      print_interface_addresses(id);
    }
    else if (status == ARM_NWK_IP_ADDRESS_ALLOCATION_FAIL)
    {
      printk("=> Echec de l'allocation d'adresse IP (DHCP ou ND).\n");
    }
  }
  else if (event->event_type == 102)
  {
    send_counter++;

    if (app_tcp_client_socket >= 0)
    {
      char send_buf[64];
      int len =
          snprintk(send_buf, sizeof(send_buf), "Compteur: %u\n", send_counter);
      socket_send(app_tcp_client_socket, send_buf, len);
      printk("sended\n");
    }

    // Reprogrammer le timer pour dans 1 seconde
    eventOS_event_timer_request(1, 102, app_tasklet_id, 1000);
  }
}
static void trace_printer(const char *str)
{
  printk("%s\n", str);
}
int main(void)
{
  printk("\n--- INIT STACK ---\n");
  ns_dyn_mem_init(ns_heap, sizeof(ns_heap), NULL, NULL);

  mbed_trace_init();
  mbed_trace_print_function_set(trace_printer);
  mbed_trace_config_set(TRACE_ACTIVE_LEVEL_ALL | TRACE_MODE_COLOR);

  eventOS_scheduler_init();

  id = setup_nanostack_bridge();
  if (id < 0)
  {
    printk("ERREUR CRITIQUE: Impossible d'initialiser le bridge AF_PACKET.\n");
  }
  else
  {
    printk("Bridge initialisé avec succès ! Interface ID: %d\n", id);
  }
  app_tasklet_id = eventOS_event_handler_create(&app_tasklet_handler, 0);

  nanostack_event_loop_start();

  while (1)
  {
    k_msleep(1000);
  }
}
