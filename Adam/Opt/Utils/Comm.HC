#help_index "Comm"

#define UART_THR		0
#define UART_RDR		0
#define UART_BRDL		0
#define UART_IER		1
#define UART_BRDH		1
#define UART_IIR		2
#define UART_LCR		3
#define UART_MCR		4
#define UART_LSR		5
#define UART_MSR		6

#define COMf_ENABLED	0
class CComm
{
  I64   base,
        flags;
  CFifoU8 *RX_fifo;
};

public CComm comm_ports[5];

public U0 CommHndlr(I64 port)
{// Com port IRQ handler
  CComm *c=&comm_ports[port];
  I64 stat;
  if (Bt(&c->flags,COMf_ENABLED))
  {
    stat=InU8(c->base+UART_IIR);
    if (stat & 4)	//RX
      FifoU8Ins(c->RX_fifo,InU8(c->base+UART_RDR));
  }
}

interrupt U0 IRQComm3()
{// Com 2/4 IRQ handler
  CommHndlr(2);
  CommHndlr(4);
  OutU8(0x20,0x20);
}

interrupt U0 IRQComm4()
{// Com 1/3 IRQ handler
  CommHndlr(1);
  CommHndlr(3);
  OutU8(0x20,0x20);
}

public U0 CommInit()
{// Com port base/IRQ init function
  MemSet(&comm_ports,0,sizeof(comm_ports));
  comm_ports[1].base=0x3F8;
  comm_ports[2].base=0x2F8;
  comm_ports[3].base=0x3E8;
  comm_ports[4].base=0x2E8;
  IntEntrySet(0x23,&IRQComm3);
  IntEntrySet(0x24,&IRQComm4);
}
CommInit;

public CComm *CommInit8n1(I64 port,I64 baud)
{// Com port init function
  CComm *c=&comm_ports[port];
  PUSHFD
  CLI
  if (LBts(&c->flags,COMf_ENABLED))
  {
    FifoU8Del(c->RX_fifo);
  }
  c->RX_fifo=FifoU8New(512);
  OutU8(c->base+UART_LCR,0);	//Set for IER
  OutU8(c->base+UART_IER,0);	//Disable all IRQ
  OutU8(c->base+UART_LCR,0x80);	//Enable baud rate control
  OutU8(c->base+UART_BRDL,0x180/(baud/300) & 0xFF);	//LSB
  OutU8(c->base+UART_BRDH,0x180/(baud/300) / 256);	//MSB
  OutU8(c->base+UART_LCR,3);	//8-none-1
  InU8(c->base+UART_RDR);	//read garbage
  InU8(c->base+UART_LSR);
  OutU8(c->base+UART_MCR,4);
  OutU8(c->base+UART_IER,0);	//Disable all IRQ
  OutU8(c->base+UART_MCR,0xA);	//out2 and rts
  OutU8(0x21,InU8(0x21) & (0xFF-0x18));	//Enable 8259 IRQ 3 & 4
  OutU8(c->base+UART_IER,1);	//RX but no THR empty
  POPFD
  return c;
}

public U0 CommPutChar(I64 port,U8 b)
{// Write 1 byte to com port
  I64 base=comm_ports[port].base;
  while (!(InU8(base+UART_LSR) & 0x20))
    Yield;
  OutU8(base+UART_THR,b);
  while (!(InU8(base+UART_LSR) & 0x20))
    Yield;
}

public U8 CommGetChar(I64 port)
{// Get 1 byte from com port
  U8 chr;
  while (1)
  {
    if (FifoU8Rem(comm_ports[port].RX_fifo, &chr))
      return chr;
    else
      Yield;
  }
}

public Bool CommGetCharNoWait(I64 port, U8 *byte_out)
{// Try to get 1 byte from com port
  if (FifoU8Rem(comm_ports[port].RX_fifo, byte_out))
  {
    return TRUE;
  }
  return FALSE;
}


public U0 CommFlush(I64 port)
{// Flush com port fifos
  FifoU8Flush(comm_ports[port].RX_fifo);
}

public U0 CommPutS(I64 port,U8 *st)
{// Writes string to com port
  I64 b;
  while (b=*st++)
    CommPutChar(port,b);
}

public U0 CommPutBlk(I64 port,U8 *buf,I64 cnt)
{// Writes a block to com port
  while (cnt--)
    CommPutChar(port,*buf++);
}

public U0 CommPrint(I64 port,U8 *fmt,...)
{// Prints format string to com port
  U8 *buf=StrPrintJoin(NULL,fmt,argc,argv);
  CommPutS(port,buf);
  Free(buf);
}

