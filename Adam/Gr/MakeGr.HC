Cd(__DIR__);;

#include "GrInitA"
#include "Gr.HH"
#include "GrExt"
#include "GrGlbls"
#include "GrPalette"
#include "GrDC"
#include "GrInitB"
#include "GrMath"
#include "GrScrn"
if (mp_cnt>1)
  EnableSethGfx;
#include "GrBitMap"
#include "GrPrimatives"
#include "GrComposites"
#include "ScrnCast"

#define SPE_ABORT	(-1)
#define SPE_EXIT	0
#define SPE_CONT	1
#include "SpriteNew"
#include "GrSpritePlot"
#include "SpriteMesh"
#include "SpriteBitMap"
#include "SpriteCode"
#include "SpriteSideBar"
#include "SpriteEd"
#include "SpriteMain"

#include "GrEnd"

Cd("..");;