/* Gopher client for TempleOS/Sockets
   by Declan Hoare 2020
   ported to ZealOS and modified by TomAwezome in 2021
   Public Domain - No Warranty */

#define GOPHER_CLIENT_LOADED

#ifndef GOPHER_ASSOCIATIONS
#define GOPHER_ASSOCIATIONS
U8 *gopher_associations[256];
#endif

I64 GopherOpen(U8 *host, U16 port, U8 *selector, U8 *query)
{
  U8 *line;
  I64 sock;
  if (host == NULL)
  {
    return -1;
  }
//  sock = create_connection(host, port);
  sock = TCPConnectionCreate(host, port);
  if (sock <= 0)
  {
    PrintErr("Failed to connect to %s:%d\n", host, port);
    return sock;
  }
  if (query == NULL)
  {
    line = StrPrint(NULL, "%s\r\n", selector);
  }
  else
  {
    line = StrPrint(NULL, "%s\t%s\r\n", selector, query);
  }
  sock(CTCPSocket *)->timeout = TCP_TIMEOUT;
//  sendString(sock, line, 0);
  TCPSocketSendString(sock, line);
  Free(line);
  return sock;
}

public I64 GopherDl(U8 *host, U16 port = 70, U8 *selector, U8 *query = NULL, U8 *dest)
{
  CFile *f;
  U8         buf[BLK_SIZE];
  I64        data_len = 0, total_len = 0, got, sock;
  progress4 = 0;
  f = FOpen(dest, "w");
  if (!f)
  {
    PrintErr("Failed to open %s for writing\n", dest);
    return -1;
  }
  sock = GopherOpen(host, port, selector, query);
  if (sock <= 0)
  {
    return sock;
  }
  while (TRUE)
  {
//      got = recv(sock, buf + data_len, sizeof(buf) - data_len, 0);
    got = TCPSocketReceive(sock, buf + data_len, sizeof(buf) - data_len);
    if (got <= 0)
    {
      if (got < 0)
        PrintErr("Failed to receive TCP data\n");
      if (data_len != 0 && !FBlkWrite(f, buf))
      {
        break;
      }
      f->de.size = total_len;
      FClose(f);
      TCPSocketClose(sock);
      return got;
    }
    data_len += got;
    total_len += got;
    progress4 += got;
    if (data_len == BLK_SIZE)
    {
      if (!FBlkWrite(f, buf))
      {
        break;
      }
      data_len = 0;
    }
  }
  TCPSocketClose(sock);
  PrintErr("Write failed, %s may be corrupted\n", dest);
  FClose(f);
  return -1;
}

U0 PrintEscaped(U8 *txt, U8 *backslashes = "")
{
  U8 *cur;
  U64 offending;
  while (cur = StrFirstOcc(txt, "$$\\\""))
  {
    offending = *cur;
    *cur = 0;
    if (offending == '$$')
    {
      "%s$$$$", txt;
    }
    else
    {
      "%s%s%c", txt, backslashes, offending;
    }
    txt = cur + 1;
  }
  "%s", txt;
}

U8 *GopherBasename(U8 *selector)
{
  U8 *lastslash = StrLastOcc(selector, "/"), *result;
  if (lastslash == NULL)
  {
    result = selector;
  }
  else
  {
    result = lastslash + 1;
  }
  //BAD FOR FILENAMES: ? / | = % : ; * + " < > space
  result = StrReplace(result, "?", "");
  result = StrReplace(result, "/", "",, TRUE);
  result = StrReplace(result, "|", "",, TRUE);
  result = StrReplace(result, "=", "",, TRUE);
  result = StrReplace(result, "%", "",, TRUE);
  result = StrReplace(result, ":", "",, TRUE);
  result = StrReplace(result, ";", "",, TRUE);
  result = StrReplace(result, "*", "",, TRUE);
  result = StrReplace(result, "+", "",, TRUE);
  result = StrReplace(result, "\"", "",, TRUE);
  result = StrReplace(result, "<", "",, TRUE);
  result = StrReplace(result, ">", "",, TRUE);
  result = StrReplace(result, " ", "",, TRUE);
  if (StrLen(result) > 22)
    result[21] = 0; // truncate filename len
  AdamLog("%s\n", result);
  return result;
}

U0 GopherTextView(U8 *host, U16 port, U8 *selector)
{
  U8 *basename;
  U8 *tmpname;
  DirMk("::/Tmp/Gopher");
  basename = ExtChg(GopherBasename(selector), "TXT");
  tmpname = StrPrint(NULL, "::/Tmp/Gopher/%s", basename);
  Free(basename);
  if (GopherDl(host, port, selector,, tmpname) == 0)
  {
    AdamLog("%s\n", tmpname);
    Plain(tmpname);
  }
  else
  {
    PrintErr("Failed to download %s from %s:%d\n",
             selector, host, port);
  }
  Free(tmpname);
}

U0 GopherLine(U8 *line)
{
  U64 type;
  U8 *display;
  U8 *selector;
  U8 *host = NULL;
  U16 port = 0;
  if (*line == 0)
  {
    "\n";
    return;
  }
  type = *line++;
  display = line;
  line = StrFind("\t", line);
  if (line)
  {
    *line = 0;
    line++;
  }
  selector = line;
  if (line)
  {
    line = StrFind("\t", line);
  }
  if (line)
  {
    *line = 0;
    line++;
  }
  host = line;
  if (line)
  {
    line = StrFind("\t", line);
  }
  if (line)
  {
    *line = 0;
    line++;
    port = Str2I64(line);
  }
  if (!*host)
    return;
  switch (type)
  {
  case '3':
    PrintErr("");
  case 'i':
    PrintEscaped(display);
    break;
  default:
    "$$MA,\""
    ;
    PrintEscaped(display, "\\");
    "\",LM=\"%s(\\\""
    , gopher_associations[type];
    PrintEscaped(host, "\\\\\\");
    "\\\",%d,\\\""
    , port;
    PrintEscaped(selector, "\\\\\\");
    "\\\");\\n\"$$";
  }
  "\n";
}

public I64 GopherMenu(U8 *host, U16 port = 70, U8 *selector = "/", U8 *query = NULL)
{
  I64 sock, n;
  U8  buf[256];
  sock = GopherOpen(host, port, selector, query);
  if (sock <= 0)
  {
    return sock;
  }
  do
  {
//      n = recvLine(sock, buf, sizeof(buf), 0);
    n = TCPSocketReceiveLine(sock, buf, sizeof(buf));
    if (StrCmp(buf, ".") == 0)
    {
      break;
    }
    GopherLine(buf);
  }
  while (n > 0);
//  close(sock);
  TCPSocketClose(sock);
  return 0;
}

class CQueryForm
{
  U8 query[65] format "$$DA-P,A=\"Query:%s\"$$";
};
U0 GopherQueryPmt(U8 *host, U16 port, U8 *selector)
{
  CQueryForm form;
  form.query[0] = 0;
  if (PopUpForm(&form))
  {
    GopherMenu(host, port, selector, form.query);
  }
}

class CDlForm
{
  U8 name[256] format "$$DA-P,LEN=255,A=\"FileName:%s\"$$";
};
U0 GopherDlPmt(U8 *host, U16 port, U8 *selector)
{
  CDlForm    form;
  U8        *basename;
  basename = GopherBasename(selector);
  MemSet(form.name, 0, 256);
  MemCpy(form.name, basename,
         MinI64(StrLen(basename), sizeof(form.name) - 1));
  form.name[255] = 0;
  if (PopUpForm(&form))
  {
    if (StrLen(form.name) >= 26)
      form.name[25] = 0;
    GopherDl(host, port, selector,, form.name);
  }
}

public I64 Gopher(U8 *hostname)
{
  return GopherMenu(hostname);
}

MemSetI64(gopher_associations, "GopherDlPmt", 256);
gopher_associations['0'] = "GopherTextView";
gopher_associations['1'] = "GopherMenu";
gopher_associations['7'] = "GopherQueryPmt";
/* Include this file from your Net/Load.HC, then add more associations */


DocMax;
"\n\nTry using Gopher to connect to a gopher server, for example:"
"\n\n$FG,2$          Gopher(\"gopher.floodgap.com\");$FG$"
"\n\n$FG,2$          GopherMenu(\"eyeblea.ch\",70,\"/~zealos\");$FG$"
"\n\n$FG,2$          Gopher(\"codevoid.de\");$FG$"
"\n\n";
