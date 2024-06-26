U8 src[6] = {0xDE, 0xAD, 0xBE, 0xEF, 0xC0, 0xDE};
U8 dst[6] = {0xF0, 0x0D, 0xBE, 0xAD, 0xDE, 0xAF};

U0 DHCPTest()
{
  CUDPSocket *udp_socket = UDPSocket(AF_INET);
  U32 your_ip;
  U32 dns_ip;
  U32 router_ip;
  U32 subnet_mask;
  U8 *packet_buffer;
  I64 de_index;
  if (ipv4_globals.local_ip != 0)
  {
    "\nThis test will only work on unconfigured network.\n";
    "To force for testing, comment out $FG,0$NetConfigure;$FG$ in $LK,"
Run.HC",A="FF:
C:
    /Home/Net/Run.HC,NetConfigure"$.\n\n";
    return;
  }
  DHCPInnerCfg(udp_socket, &your_ip, &dns_ip, &router_ip, &subnet_mask);
  UDPSocketClose(udp_socket);
  while (TRUE)
  {
    de_index = EthernetFrameAllocate(&packet_buffer, src, dst, 0x0000, 8);
    *(packet_buffer(U64 *)) = EndianU64(0xDEADBEEFC0DEFADE);
    EthernetFrameFinish(de_index);
    Sleep(300);
  }
}

DHCPTest;
