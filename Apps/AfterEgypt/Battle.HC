$BG,14$









	$SP,"<1>",BI=1$










	$SP,"<2>",BI=2$










	$SP,"<3>",BI=3$







	$SP,"<4>",BI=4$
$BG$
F64 t0,xx,t_last;
Bool held_up;

#define HACK_PERIOD	0.25
#define SPACING			45

U0 DrawBattle(CTask *task,CDC *dc)
{
  I64 cx=task->pix_width>>1,
        cy=task->pix_height>>1;
  U8 *tmps;
  F64 tt;
  if (held_up)
    tt=0;
  else {
    tt=(tS-t0)/2;
    tt*=tt;
    tt*=tt;
    if (tt>1.0) tt=1.0;
  }
  tmps=SpriteInterpolate(tt,$IB,"<3>",BI=3$,$IB,"<4>",BI=4$);
  Sprite3(dc,cx,cy+SPACING,0,tmps);
  Free(tmps);

  if (t_last) {
    if (tt<0.5)
      xx-=50.0*(tS-t_last);
    else
      xx+=50.0*(tS-t_last);
  }

  tt=Saw(tS+0.0*HACK_PERIOD,HACK_PERIOD);
  tt*=2; if (tt>1.0) tt=2.0-tt;
  tmps=SpriteInterpolate(tt,$IB,"<1>",BI=1$,$IB,"<2>",BI=2$);
  Sprite3(dc,xx+cx+SPACING,cy-SPACING,0,tmps);
  Free(tmps);

  tt=Saw(tS+0.333*HACK_PERIOD,HACK_PERIOD);
  tt*=2; if (tt>1.0) tt=2.0-tt;
  tmps=SpriteInterpolate(tt,$IB,"<1>",BI=1$,$IB,"<2>",BI=2$);
  Sprite3(dc,xx+cx+2*SPACING,cy-SPACING,0,tmps);
  Free(tmps);

  tt=Saw(tS+0.666*HACK_PERIOD,HACK_PERIOD);
  tt*=2; if (tt>1.0) tt=2.0-tt;
  tmps=SpriteInterpolate(tt,$IB,"<1>",BI=1$,$IB,"<2>",BI=2$);
  Sprite3(dc,xx+cx+SPACING,cy-2*SPACING,0,tmps);
  Free(tmps);

  t_last=tS;
}

U0 Battle()
{
  I64 msg_code,ch,sc;

  SettingsPush(Fs,TSF_SAME_SONG); //See $LK,"SettingsPush",A="MN:SettingsPush"$
  try {
    Fs->text_attr=YELLOW<<4+BLUE;
    DocClear;
    "$$BG,YELLOW$$";

    BibleVerse(,"Exodus,17:11",8);
    "\n$$BK,1$$Hold <SPACE>$$BK,0$$\n";

    held_up=FALSE;
    t0=tS;
    t_last=0;
    xx=0;
    Fs->draw_it=&DrawBattle;
    do {
      msg_code=GetMsg(&ch,&sc,1<<MSG_KEY_DOWN|1<<MSG_KEY_UP);
      if (ch==CH_SPACE) {
        if (msg_code==MSG_KEY_DOWN)
	  held_up=TRUE;
        else if (msg_code==MSG_KEY_UP) {
	  held_up=FALSE;
	  t0=tS;
        }
      }
    } while (msg_code!=MSG_KEY_DOWN || ch!=CH_SHIFT_ESC && ch!=CH_ESC);
    GetMsg(,,1<<MSG_KEY_UP);
  } catch
    PutExcept;
  DocClear;
  SettingsPop(Fs,TSF_SAME_SONG);
}

        �         
��������   ����
   ����   ����
   ����       
          ����
����������������
   ����	   ����
   ������������
   ����   ����

   ����   ����
   ����   ����
����������������
����������������
   ����(   ����        �         
��������   ����
   ����   ����
   ����       
          ����
����������������
   ����	   ����
   ������������
   ����   ����

   ����   ����
   ����   ����
����������������
����������������
   ����"              �        
����           
        ��������
����������������
����������������
��������   ����
    ������������
   ����   ����
    ����   ����
   ����      
����������������
����������������
   ������������
��������   ����
   ����   ����
   ����   ����
   ������������
����������������
����������������
��������   ����
    ������������
��������   ����
��������   ����
��������   ����
����������������
����������������        �        
����   ����    
����������������
����������������
����������������
��������   ����
����������������
   ����   ����
    ����   ����
   ����   ����
����������������
����������������
    ������������
����������������
��������   ����
   ������������
����������������
����������������
����������������
��������    ����
    ������������
��������    ����
��������   ����
��������    ����
����������������
���������������� 