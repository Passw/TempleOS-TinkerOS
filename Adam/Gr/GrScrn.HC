#help_index "Graphics/Scrn"

U0 GrUpdateTaskODEs(CTask *task)
{
  sys_task_being_scrn_updated=task;
  try
    ODEsUpdate(task);
  catch
  {
    LBts(&task->win_inhibit,WIf_SELF_ODE);
    "Exception in WinMgr: Update Task ODEs\n";
    PutExcept;
    Sleep(3000);
    VGAFlush;
  }
  sys_task_being_scrn_updated=NULL;
}

U0 GrUpdateTaskWin(CTask *task)
{//Draw a win.  Only Core0 tasks have a win.
  CDC *dc;
  CD3I64 saved_scroll;
  sys_task_being_scrn_updated=task;
  try
  {
    if (!Bt(&task->display_flags,DISPLAYf_NO_BORDER))
      TextBorder(Fs,task->win_left,task->win_right,task->win_top,
                 task->win_bottom,task->border_attr,task==sys_focus_task);
    TextRect(task->win_left,task->win_right,
             task->win_top,task->win_bottom,task->text_attr<<8);
    if (task==sys_winmgr_task)
    {
      if (gr.fp_wall_paper)
        (*gr.fp_wall_paper)(task);
    }
    else if (!(task->win_inhibit&WIF_SELF_DOC))
      DocUpdateTaskDocs(task);
    if (TaskValidate(task))
    {
      if (task->draw_it)
      {
        dc=DCAlias(gr.dc2,task);
        (*task->draw_it)(task,dc);
        DCDel(dc);
      }
      if (TaskValidate(task))
      {
        WinScrollNull(task,&saved_scroll);
        DrawCtrls(task);
        WinScrollRestore(task,&saved_scroll);
      }
    }
  }
  catch
  {
    if (task!=Fs && TaskValidate(task))
    {
      LBtr(&task->display_flags,DISPLAYf_SHOW);
      "Exception in WinMgr: Update Task Win\n";
      PutExcept;
      Sleep(3000);
      VGAFlush;
    }
  }
  sys_task_being_scrn_updated=NULL;
}

U0 GrUpdateTasks()
{//Only called by WinMgr
  I64 i;
  CTask *task,*task1;
  try
  {
    winmgr.ode_time=0;
    if (Bt(&sys_semas[SEMA_UPDATE_WIN_Z_BUF],0))
      WinZBufUpdate;
    task1=task=sys_winmgr_task;
    do   //Loop through Core0 tasks.
    {
      if (!TaskValidate(task)) break;
      if (Bt(&task->display_flags,DISPLAYf_SHOW) &&
          Bt(gr.win_uncovered_bitmap,task->win_z_num))
        GrUpdateTaskWin(task);
      if (!TaskValidate(task)) break;
      task=task->next_task;
    }
    while (task!=task1);
    for (i=0; i<mp_cnt; i++) //Loop through all cores.
    {
      task1=task=cpu_structs[i].seth_task;
      do
      {
        if (!TaskValidate(task)) break;
        GrUpdateTaskODEs(task);
        if (!TaskValidate(task)) break;
        task=task->next_task;
      }
      while (task!=task1);
    }
  }
  catch
  {
    PutExcept(FALSE);
    Dbg("Exception in WinMgr");
  }
  winmgr.last_ode_time=winmgr.ode_time;
  ode_alloced_factor=LowPass1(0.1,ode_alloced_factor,
                              Clamp(Gs->idle_factor-0.1,0.2,0.8),1/winmgr.fps);
  sys_task_being_scrn_updated=NULL;
}

U0 GrUpdateTextBG()
{
  I64 reg RSI *dst=gr.dc2->body,reg R13 c,row,col,
               num_rows=TEXT_ROWS,num_cols=TEXT_COLS,i,j,cur_ch,
               reg R12 w1=gr.dc2->width_internal,w2=-7*w1+8,w3=7*w1,w4=0;
  U32 *src=gr.text_base;
  Bool blink_flag=Blink;
  U8 *dst2=dst;
  if (gr.pan_text_x||gr.hide_col)
  {
    gr.pan_text_x=ClampI64(gr.pan_text_x,-7,7);
    j=AbsI64(gr.pan_text_x)/FONT_WIDTH+1;
    num_cols-=j;
    if (gr.pan_text_x<0)
    {
      src+=j;
      i=FONT_WIDTH*j+gr.pan_text_x;
    }
    else
      i=gr.pan_text_x;
    dst2=dst(U8 *)+i;
    w4=j;
    w3+=j*FONT_WIDTH;
    j*=FONT_WIDTH;
    dst(U8 *)=gr.dc2->body;
    for (row=num_rows*FONT_HEIGHT; row--;)
    {
      for (col=i; col--;)
        *dst(U8 *)++=0;
      dst(U8 *)+=w1-i-j;
      for (col=j; col--;)
        *dst(U8 *)++=0;
    }
  }
  dst=dst2;
  if (gr.pan_text_y||gr.hide_row)
  {
    gr.pan_text_y=ClampI64(gr.pan_text_y,-7,7);
    j=AbsI64(gr.pan_text_y)/FONT_HEIGHT+1;
    num_rows-=j;
    if (gr.pan_text_y<0)
    {
      src+=w1/FONT_WIDTH*j;
      i=w1*(FONT_HEIGHT*j+gr.pan_text_y);
    }
    else
      i=w1*gr.pan_text_y;
    dst2=dst(U8 *)+i;
    j*=w1*FONT_HEIGHT;
    dst(U8 *)=gr.dc2->body;
    for (row=i; row--;)
      *dst(U8 *)++=0;
    dst(U8 *)=gr.dc2->body+TEXT_ROWS*TEXT_COLS*FONT_HEIGHT*FONT_WIDTH-j;
    for (row=j; row--;)
      *dst(U8 *)++=0;
  }
  dst=dst2;
  for (row=num_rows; row--;)
  {
    for (col=num_cols; col--;)
    {
      cur_ch=*src++;
      if (cur_ch & (ATTRF_SEL|ATTRF_INVERT|ATTRF_BLINK))
      {
        if (cur_ch & ATTRF_SEL)
          cur_ch.u8[1]=cur_ch.u8[1]^0xFF;
        if (cur_ch & ATTRF_INVERT)
          cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
        if (cur_ch & ATTRF_BLINK && blink_flag)
          cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      }
      c=gr.to_8_colors[cur_ch.u8[1]>>4];
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      ADD	RSI,R12
      MOV	U64 [RSI],R13
      dst(U8 *)+=w2;
    }
    src+=w4;
    dst(U8 *)+=w3;
  }
}

U0 GrUpdateTextFG()
{//See $LK,"TextBase Layer",A="HI:TextBase Layer"$.
  U32 *src=gr.text_base;
  I64 i,j,cur_ch,*dst=gr.dc2->body,
                  w1=gr.dc2->width_internal,w2=7*w1,w4=0,
                  num_rows=TEXT_ROWS,num_cols=TEXT_COLS,row,col;
  U8 *dst_start=gr.dc2->body,*dst_end=dst_start+w1*gr.dc2->height-7*w1-8;
  Bool blink_flag=Blink;
  if (gr.pan_text_x||gr.hide_col)
  {
    gr.pan_text_x=ClampI64(gr.pan_text_x,-7,7);
    j=AbsI64(gr.pan_text_x)/FONT_WIDTH+1;
    num_cols-=j;
    if (gr.pan_text_x<0)
    {
      src+=j;
      dst(U8 *)+=FONT_WIDTH*j;
    }
    w4=j;
    w2+=j*FONT_WIDTH;
  }
  if (gr.pan_text_y||gr.hide_row)
  {
    gr.pan_text_y=ClampI64(gr.pan_text_y,-7,7);
    j=AbsI64(gr.pan_text_y)/FONT_HEIGHT+1;
    num_rows-=j;
    if (gr.pan_text_y<0)
    {
      src+=w1/FONT_WIDTH*j;
      dst(U8 *)+=w1*FONT_HEIGHT*j;
    }
  }
  for (row=num_rows; row--;)
  {
    for (col=num_cols; col--;)
    {
      cur_ch=*src++;
      if (cur_ch & (ATTRF_UNDERLINE|ATTRF_SEL|ATTRF_INVERT|ATTRF_BLINK))
      {
        if (cur_ch & ATTRF_SEL)
          cur_ch.u8[1]=cur_ch.u8[1]^0xFF;
        if (cur_ch & ATTRF_INVERT)
          cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
        if (cur_ch & ATTRF_BLINK && blink_flag)
          cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      }
      if (i=cur_ch.u16[1]&0x3FF+gr.pan_text_x+gr.pan_text_y<<5)
      {
        j=i&0x1F;
        if (j&0x10) j|=~0x1F;
        i>>=5;
        if (i&0x10) i|=~0x1F;
        i=w1*i+j;
        if (dst_start<=dst(U8 *)+i<dst_end)
          GrRopEquU8NoClipping(cur_ch&(ATTRF_UNDERLINE+0xFFF),dst(U8 *)+i,w1);
      }
      else
        GrRopEquU8NoClipping(cur_ch&(ATTRF_UNDERLINE+0xFFF),dst,w1);
      dst(U8 *)+=8;
    }
    src+=w4;
    dst(U8 *)+=w2;
  }
}

U0 DCBlotColor8(CDC *dc,CDC *img)
{
  U8  *src=img->body,*b0=dc->body;
  I64 j,k,d0=img->width_internal*img->height;
  for (k=0; k<d0; k++)
  {
    j=*src++;
    if (j!=TRANSPARENT)
      *b0++=j;
    else
      b0++;
  }
}

U0 GrUpdateTextModeText()
{
  U32 *src=gr.text_base;
  I64 cur_ch,i=TEXT_COLS*TEXT_ROWS;
  U16 *dst=text.vga_text_alias,*dst2=gr.vga_text_cache;
  Bool blink_flag=Blink;
  if (LBtr(&sys_semas[SEMA_FLUSH_VGA_IMAGE],0))
  {
    while (i--)
    {
      cur_ch=*src++;
      if (cur_ch & ATTRF_SEL)
        cur_ch.u8[1]=cur_ch.u8[1]^0xFF;
      if (cur_ch & ATTRF_INVERT)
        cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      if (cur_ch & ATTRF_BLINK)
        if (blink_flag)
          cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      *dst++=*dst2++=cur_ch&0x7FFF;
    }
  }
  else
  {
    while (i--)
    {
      cur_ch=*src++;
      if (cur_ch & ATTRF_SEL)
        cur_ch.u8[1]=cur_ch.u8[1]^0xFF;
      if (cur_ch & ATTRF_INVERT)
        cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      if (cur_ch & ATTRF_BLINK)
        if (blink_flag)
          cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      cur_ch&=0x7FFF;
      if (*dst2!=cur_ch)
        *dst++=*dst2++=cur_ch;
      else
      {
        dst++;
        dst2++;
      }
    }
  }
}


U0 GrPartialUpdate()
{
  U16 *screen = gr.dc2->body, *last_screen = gr.screen_cache;
  I64 i, *dst = text.fb_alias, diffs_size = GR_WIDTH * GR_HEIGHT / 2;
  for (i = 0; i < diffs_size; i++)
  {
    if (screen[i] != last_screen[i])
    {
      last_screen[i] = screen[i];
      dst[i] = gr_palette[screen[i].u8[0]] | gr_palette[screen[i].u8[1]] << 32;
    }
  }
}

U0 GrDoFinalScale()
{
  I64 i,j,k,l,dst_row=0;
  U32 *src, *dst, *src2;
  src=text.raw_scrn_image;
  for (i=0; i<GR_HEIGHT; i++)
  {
    k=HEIGHT_SCALE;
    while (k--)
    {
      dst=text.fb_alias+dst_row*FB_WIDTH;
      src2=src;
      for (l=0; l<GR_WIDTH; l++)
      {
        for(j=0; j<WIDTH_SCALE-1; j++)
        {
          *dst++=*src2;
        }
        *dst++=*src2++;
      }
      dst_row++;
    }
    src+=GR_WIDTH;
  }
}

U0 GrUpdateVGAGraphics()
{
  U64 size, *dst = text.raw_scrn_image;
  U8 *src;
  if (gr.scrn_zoom == 1)
  {
    if (LBtr(&sys_semas[SEMA_FLUSH_VGA_IMAGE],0) || DO_SCALING)
    {
      src = gr.dc2->body;
      size = src + gr.dc2->height * gr.dc2->width_internal;
      while (src < size)
        *dst++ = gr_palette[*src++ & 0xFF] | gr_palette[*src++ & 0xFF] << 32;
      MemCpy(gr.screen_cache,gr.dc2->body, text.buffer_size/4);
      if (DO_SCALING)
        GrDoFinalScale;
      else
        MemCpy(text.fb_alias, text.raw_scrn_image, text.buffer_size);
    }
    else
      GrPartialUpdate;
  }
  else
  {
    GrZoomInScrn;
    src = gr.zoomed_dc->body;
    size = src + gr.dc2->height * gr.dc2->width_internal;
    while (src < size)
      *dst++ = gr_palette[*src++ & 0xFF] | gr_palette[*src++ & 0xFF] << 32;
    MemCpy(gr.screen_cache,gr.zoomed_dc->body, text.buffer_size/4);
    if (DO_SCALING)
      GrDoFinalScale;
    else
      MemCpy(text.fb_alias, text.raw_scrn_image, text.buffer_size);
    VGAFlush;
  }
}

U0 DCBlotColor8Seth()
{
  while (TRUE)
  {
    while (!seth_gr_sema)
    {
      SleepUntil(cnts.jiffies+JIFFY_FREQ/4000);
      if (seth_gfx_flag == 0)
      {
        lock
        {
          seth_gr_task=NULL;
        }
        goto blot8_exit;
      }
    }
    DCBlotColor8(gr.dc2,gr.dc);
    lock
    {
      seth_gr_sema--;
    }
  }
blot8_exit:
}

U0 GrUpdateScrn0()
{//Called by the Window Manager HERE, 30 times a second.
  CDC *dc;
  if (!Bt(&sys_run_level,RLf_VGA)) //if text mode
    GrUpdateTasks;
  else
  {
    GrUpdateTextBG;
    GrUpdateTextFG;
    GrUpdateTasks;
    DCBlotColor8(gr.dc2,gr.dc);
  }
  dc=DCAlias(gr.dc2,Fs);
  dc->flags|=DCF_ON_TOP;
  if (gr.fp_final_scrn_update)
    (*gr.fp_final_scrn_update)(dc);
  DCDel(dc);
  if (!Bt(&sys_run_level,RLf_VGA)) //if text mode
    GrUpdateTextModeText;
  else
  {
    GrUpdateVGAGraphics;
  }
}

U0 GrUpdateScrnSeth()
{
  CDC *dc;
  if (seth_gr_sema>0)
  {
    while (seth_gr_sema)
    {
      SleepUntil(cnts.jiffies+JIFFY_FREQ/4000);
    }
  }
  GrUpdateTextBG;
  GrUpdateTextFG;
  GrUpdateTasks;
  // Notify Seth of more work
  lock
  {
    seth_gr_sema++;
  }
  while (seth_gr_sema)
  {
    SleepUntil(cnts.jiffies+JIFFY_FREQ/4000);
  }
  dc=DCAlias(gr.dc2,Fs);
  dc->flags|=DCF_ON_TOP;
  if (gr.fp_final_scrn_update)
    (*gr.fp_final_scrn_update)(dc);
  DCDel(dc);
  if (!Bt(&sys_run_level,RLf_VGA)) //if text mode
    GrUpdateTextModeText;
  else
  {
    GrUpdateVGAGraphics;
  }
}

U0 GrUpdateScrn()
{//Called by the Window Manager $LK,"HERE",A="FF:::/Adam/WinMgr.HC,GrUpdateScrn"$, 30 times a second.
  if (mp_cnt<=1||seth_gfx_flag==0)
  {
    GrUpdateScrn0;
    return;
  }
  else if (!TaskValidate(seth_gr_task))
  {
    lock
    {
      seth_gr_sema=0;
    }
    lock
    {
      seth_gr_task = Spawn(&DCBlotColor8Seth, NULL, "Seth GFX Helper Blot8", 1);
    }
    GrUpdateScrn0;
    return;
  }
  GrUpdateScrnSeth;
}

public U0 ToggleBlink()
{// Toggles blinking
  blink_master_flag^=1;
}

public U0 ToggleScroll()
{// Toggles scrolling
  scroll_master_flag^=1;
}

public U0 EnableSethGfx()
{
  lock
  {
    seth_gfx_flag=1;
  }
}

public U0 SetFPS(I64 new_fps)
{// Sets target frame rate
  if (new_fps<1)
  {
    lock
    {
      fps_master=1;
    }
  }
  else if (new_fps>99)
  {
    lock
    {
      fps_master=99;
    }
  }
  else
  {
    lock
    {
      fps_master=new_fps;
    }
  }
}