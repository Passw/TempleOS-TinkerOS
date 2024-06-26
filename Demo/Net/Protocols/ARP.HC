#define ARP_HASHTABLE_SIZE  1024

#define HTT_ARP 0x00100 //identical to HTT_DICT_WORD

#define ARP_REQUEST 0x01
#define ARP_REPLY   0x02

class CARPHeader
{
  U16 hardware_type;
  U16 protocol_type;

  U8 hardware_addr_len;
  U8 protocol_addr_len;

  U16 operation;

  U8 sender_hardware_addr[MAC_ADDRESS_LENGTH];
  U32 sender_protocol_addr;

  U8 target_hardware_addr[MAC_ADDRESS_LENGTH];
  U32 target_protocol_addr;

};

class CARPHash:CHash
{//store U32 ip_address as CHash->str U8*, MStrPrint("%X")
// U32 ip_address;
  U8 mac_address[MAC_ADDRESS_LENGTH];
};

class CARPGlbls
{
  U32 local_ipv4; // stored in Big Endian

} arp_globals;

CHashTable *arp_cache = NULL;

U0 ARPCacheInit()
{
  arp_cache = HashTableNew(ARP_HASHTABLE_SIZE);
  arp_globals.local_ipv4 = 0;
}

I64 ARPSend(U16 operation,
    U8 *dest_mac_address,
    U8 *send_mac_address,
    U32 send_ip,
    U8 *target_mac_address,
    U32 target_ip)
{//method currently assumes send_ and target_ip EndianU16 already...
  U8 *arp_frame;
  CARPHeader *header;
  I64 de_index = EthernetFrameAllocate(&arp_frame,send_mac_address, dest_mac_address,
          ETHERTYPE_ARP,
          sizeof(CARPHeader));
  if (de_index < 0)
    return de_index; // error state
  header = arp_frame;
  header->hardware_type = EndianU16(HTYPE_ETHERNET);
  header->protocol_type = EndianU16(ETHERTYPE_IPV4);
  header->hardware_addr_len = MAC_ADDRESS_LENGTH;
  header->protocol_addr_len = IP_ADDRESS_LENGTH;
  header->operation = EndianU16(operation);
  MemCpy(header->sender_hardware_addr, send_mac_address, MAC_ADDRESS_LENGTH);
  header->sender_protocol_addr = send_ip;
  MemCpy(header->target_hardware_addr, target_mac_address, MAC_ADDRESS_LENGTH);
  header->target_protocol_addr = target_ip;
  EthernetFrameFinish(de_index);
  return 0;
}

CARPHash *ARPCacheFind(U32 ip_address)
{
  U8 *ip_string = MStrPrint("%X", ip_address);
  CARPHash *entry = HashFind(ip_string, arp_cache, HTT_ARP);
  if (entry == NULL)
  {
    NetLog("ARP CACHE FIND BY IP: Could not find an IP in ARP cache.");
  }
  Free(ip_string);
  return entry;
}

CARPHash *ARPCachePut(U32 ip_address, U8 *mac_address)
{
  CARPHash *entry;
  NetLog("ARP CACHE PUT: Attempting to look for entry in ARP Cache.");
  entry = ARPCacheFind(ip_address);
  if (!entry)
  {
    entry = CAlloc(sizeof(CARPHash));
    NetLog("ARP CACHE PUT: Attempting add to cache: addr, mac:");
    NetLog("               0x%0X, 0x%0X 0x%0X 0x%0X 0x%0X 0x%0X 0x%0X",
        ip_address, mac_address[0], mac_address[1], mac_address[2], mac_address[3],
        mac_address[4], mac_address[5]);
    entry->str = MStrPrint("%X", ip_address);
    entry->type = HTT_ARP;
    MemCpy(entry->mac_address, mac_address, 6);
    HashAdd(entry, arp_cache);
  }
  else
  {
    NetLog("ARP CACHE Put: Entry was already found in Cache. Overwriting.");
    MemCpy(entry->mac_address, mac_address, 6);
  }
  return entry;
}

U0 ARPLocalIPV4Set(U32 ip_address)
{// takes in little endian IP, stores into globals as Big Endian
  arp_globals.local_ipv4 = EndianU32(ip_address);
  ARPSend(ARP_REPLY,
      ethernet_globals.ethernet_broadcast,
      EthernetMACGet,
      arp_globals.local_ipv4,
      ethernet_globals.ethernet_broadcast,
      arp_globals.local_ipv4);
}

I64 ARPHandler(CEthernetFrame *ethernet_frame)
{// Use of ARPHandler must accnt for -1 error codes.
  CARPHeader *header;
  U16 operation;
  header = ethernet_frame->data;
  operation = EndianU16(header->operation);
  if (ARP_REQUEST==operation && header->target_protocol_addr != arp_globals.local_ipv4)
    return 0; // Don't bother logging or futher processing these
  NetLog("ARP HANDLER: Entering ARP Handler.");
  if (ethernet_frame->ethertype != ETHERTYPE_ARP)
  {
    NetErr("ARP HANDLER: Caught wrong frame ethertype.");
    return -1;
  }
  if (ethernet_frame->length < sizeof(CARPHeader))
  {
    NetErr("ARP HANDLER: Caught wrong frame length.");
    return -1;
  }
  if (EndianU16(header->hardware_type) != HTYPE_ETHERNET)
  {
    NetErr("ARP HANDLER: Caught wrong frame hardware type.");
    return -1;
  }
  if (EndianU16(header->protocol_type) != ETHERTYPE_IPV4)
  {
    NetErr("ARP HANDLER: Caught wrong frame protocol type.");
    return -1;
  }
  if (header->hardware_addr_len != HLEN_ETHERNET)
  {
    NetErr("ARP HANDLER: Caught wrong frame hardware address length.");
    return -1;
  }
  if (header->protocol_addr_len != PLEN_IPV4)
  {
    NetErr("ARP HANDLER: Caught wrong frame protocol address length.");
    return -1;
  }
  switch (operation)
  {
  case ARP_REQUEST:
    if (header->target_protocol_addr == arp_globals.local_ipv4)
    {
      NetLog("ARP HANDLER: Saw request, sending back reply.");
      ARPSend(ARP_REPLY,
          header->sender_hardware_addr,
          EthernetMACGet,
          arp_globals.local_ipv4,
          header->sender_hardware_addr,
          header->sender_protocol_addr);
    }
    else
      NetWarn("ARP HANDLER: Saw request, target IP address is not this machine.");
    break;
  case ARP_REPLY:
    NetLog("ARP HANDLER: Saw reply, putting into ARP Cache.");
    ARPCachePut(EndianU32(header->sender_protocol_addr), header->sender_hardware_addr);
    break;
  default:
    NetErr("ARP HANDLER: Unrecognized operation: 0x%X", operation);
    break;
  }
  NetLog("ARP HANDLER: Exiting.");
  return 0;
}

U0 ARPRep()
{
  I64 i, j;
  CARPHash *temp_hash;
  U32 address;
  "$$LTBLUE$$ARP Report:$$FG$$\n\n";
  "ARP Local Address: $FG,6$%d.%d.%d.%d$FG$\n\n"
  ,
  arp_globals.local_ipv4.u8[0],
  arp_globals.local_ipv4.u8[1],
  arp_globals.local_ipv4.u8[2],
  arp_globals.local_ipv4.u8[3];
  for (i = 0; i <= arp_cache->mask; i++)
  {
    temp_hash = arp_cache->body[i];
    while (temp_hash)
    {
      "ARP Hash @ $FG,3$0x%X$FG$:\n", temp_hash;
      address = EndianU32(Str2I64(temp_hash->str, 16)(U32));
      " IP Address:     $FG,6$%d.%d.%d.%d$FG$\n"
      ,
      address.u8[0], address.u8[1], address.u8[2], address.u8[3]; // todo: kludge
      " MAC Address:    $FG,6$";
      $FG$
      for (j = 0; j < MAC_ADDRESS_LENGTH; j++)
        "%02X ", temp_hash->mac_address[j];
      "$FG$\n\n";
      temp_hash = temp_hash->next;
    }
  }
  "\n";
}

ARPCacheInit;
