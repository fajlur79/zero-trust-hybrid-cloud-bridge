#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <linux/if_ether.h>
#include <netinet/ip.h>
#include <netinet/ether.h>
#include <linux/if_packet.h>
#include <net/if.h>

#define BUFFER_SIZE 65536
#define TARGET_INTERFACE "tap0"

int main (){
    int raw_socket;
    unsigned char buffer[BUFFER_SIZE];   
    printf("[*] Starting Custom Packet Inspector on %s...\n", TARGET_INTERFACE);
    
    raw_socket = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
    if (raw_socket < 0) {
        perror("[-] Socket creation failed. Are you running as root?");
        return 1;
    }

    int ifindex = if_nametoindex(TARGET_INTERFACE);
    if (ifindex == 0) {
        perror("[-] Could not find interface. Is tap0 up?");
        return 1;
    }

    struct sockaddr_ll sll;
    memset(&sll, 0, sizeof(sll));
    sll.sll_family = AF_PACKET;
    sll.sll_protocol = htons(ETH_P_ALL);
    sll.sll_ifindex = ifindex;

    if (bind(raw_socket, (struct sockaddr *)&sll, sizeof(sll))< 0) {
        perror("[-] Strict bind failed");
        close(raw_socket);
        return 1;
    }


    printf("[+] Successfully bound to %s (Index: %d). Listening for packets...\n\n", TARGET_INTERFACE, ifindex);
    while(1){
        int data_size = recvfrom(raw_socket, buffer, BUFFER_SIZE, 0, NULL, NULL);
        if (data_size < 0) {
            printf("[-] Failed to received packets.\n");
            return 1;
        }

        struct ethhdr *eth = (struct ethhdr *)buffer;
        
        if (ntohs(eth->h_proto)== ETH_P_IP){
            struct iphdr *ip = (struct iphdr *)(buffer + sizeof(struct ethhdr));

            struct sockaddr_in source, dest;
            source.sin_addr.s_addr = ip->saddr;
            dest.sin_addr.s_addr = ip->daddr;

            printf("-------------------------------------------------\n");
            printf("🖧   PACKET INTERCEPTED (%d, bytes)\n", data_size);
            printf("    Source IP:      %s\n", inet_ntoa(source.sin_addr));
            printf("    Destination IP: %s\n", inet_ntoa(dest.sin_addr));


            if (ip->protocol == 1) {
                printf("    Protocol:       ICMP (Ping)\n");
            } else if (ip->protocol == 6){
                printf("    Protocol:       TCP\n");    
            }else if (ip->protocol == 17) {
                printf("    Protocol:       UDP\n");
            } else {
                printf("    Protocol:       Unknown (%d)\n", ip->protocol);
            }
        }
    }

    close(raw_socket);
    return 0;

}
