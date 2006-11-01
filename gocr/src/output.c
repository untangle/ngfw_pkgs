/*
This is a Optical-Character-Recognition program
Copyright (C) 2000-2005  Joerg Schulenburg

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

 see README for EMAIL address
*/

#include <string.h>
#include "unicode.h"
#include "output.h"
#include "pcx.h"
#include "gocr.h"  /* extern job_t JOB; */

/* function is only for debugging and for developing
   it prints out a part of pixmap b at point x0,y0 to stderr
   using dots .,; if no pixel, and @xoO for pixels
   modify n_run and print out what would happen on 2nd, 3th loop!
   new: output original and copied pixmap in the same figure
 */
void out_b(struct box *px, pix *b, int x0, int y0, int dx, int dy, int cs ){
  int x,y,x2,y2,yy0,tx,ty,n1,i;
  char c1, c2;
  yy0=y0;
  if(px){ /* overwrite rest of arguments */
    if (!b) {
      b=px->p;
      x0=px->x0; dx=px->x1-px->x0+1;
      y0=px->y0; dy=px->y1-px->y0+1; yy0=y0;
    }
    if(cs==0) cs=JOB->cfg.cs;
    fprintf(stderr,"\n# list box dots=%d boxes=%d subboxes=%d c=%s mod=%s"
            " line=%d m= %d %d %d %d",
	  px->dots, px->num_boxes, px->num_subboxes, 
	  decode(px->c,ASCII), decode(px->modifier,ASCII), px->line,
	  px->m1 - px->y0, px->m2 - px->y0, px->m3 - px->y0, px->m4 - px->y0);
    fprintf(stderr,"\n# list box      x= %4d %4d d= %3d %3d r= %d %d"
                    " nrun=%d",
	  px->x0, px->y0, px->x1 - px->x0 + 1, px->y1 - px->y0 + 1,
	  px->x - px->x0, px->y - px->y0, JOB->tmp.n_run);
    if (px->num_frames) {
      int i,j,jo;
      fprintf(stderr,"\n# list box frames= %d (sumvects=%d)",px->num_frames,
         ((px->num_frames)?px->num_frame_vectors[px->num_frames-1]:-1));
      for (jo=j=i=0;i<px->num_frames; i++, jo=j) {
        fprintf(stderr,"\n#  frame %d  %2d vectors=",
                i,px->num_frame_vectors[i]-jo);
        /* print only the first vectors of each frame */
        for (;j<px->num_frame_vectors[i] && j<MaxFrameVectors; j++)
          fprintf(stderr,"  %d %d",px->frame_vector[j][0] - px->x0,
                                   px->frame_vector[j][1] - px->y0);
      }
    }
    if (px->num_ac){ /* output table of chars and its probabilities */
      fprintf(stderr,"\n# list box char: ");
      for(i=0;i<px->num_ac && i<NumAlt;i++)
      /* output the (xml-)string (picture position, barcodes, glyphs, ...) */
        if (px->tas[i])
         fprintf(stderr," %s(%d)",       px->tas[i]       ,px->wac[i]);
        else
         fprintf(stderr," %s(%d)",decode(px->tac[i],ASCII),px->wac[i]);
    }
    fprintf(stderr,"\n");
    if (px->dots && px->m2 && px->m1<y0) { yy0=px->m1; dy=px->y1-yy0+1; }
  }
  tx=dx/80+1;
  ty=dy/40+1; // step, usually 1, but greater on large maps 
  fprintf(stderr,"# list pattern x= %4d %4d d= %3d %3d t= %d %d\n",
                 x0,y0,dx,dy,tx,ty);
  if (dx>0)
  for(y=yy0;y<yy0+dy;y+=ty) { /* reduce the output to max 78x40 */
    /* first image is the copied and modified bitmap of the box */
    if (px)
    for(x=x0;x<x0+dx;x+=tx){  /* by merging sub-pixels */
      n1=0; c1='.';
      for(y2=y;y2<y+ty && y2<y0+dy;y2++) /* sub-pixels */
      for(x2=x;x2<x+tx && x2<x0+dx;x2++)
      {
        if((pixel(px->p,x2-x0+px->x0,
                        y2-y0+px->y0)<cs)) c1='@';
      }
      if (px->num_frames) { /* mark vectors */
        int i;
        if (c1!='$' && c1!='S') /* dont mark twice */
        for (i=0;i<px->num_frame_vectors[px->num_frames-1];i++)
          if ((px->frame_vector[i][0]-px->x0)/tx==(x-x0)/tx
           && (px->frame_vector[i][1]-px->y0)/ty==(y-y0)/ty)
              { c1=((c1=='@')?'$':'S'); break; }
      }
      fprintf(stderr,"%c", c1 );
    }

    /* 2nd image is the boxframe in the original bitmap */
    if (dx<40) fprintf(stderr,"  ");
    if (dx<40) /* do it only, if we have enough place */
    for(x=x0;x<x0+dx;x+=tx){  /* by merging sub-pixels */
      c1='.';
      for(y2=y;y2<y+ty && y2<y0+dy;y2++) /* sub-pixels */
      for(x2=x;x2<x+tx && x2<x0+dx;x2++)
        { if((pixel(b,x2,y2)<cs)) c1='@'; }
      fprintf(stderr,"%c", c1 );
    }

    c1=c2=' ';
    /* mark lines with < */
    if (px) if (y-y0+px->y0==px->m1 || y-y0+px->y0==px->m2
             || y-y0+px->y0==px->m3 || y-y0+px->y0==px->m4)  c1='<';
    if (y==y0 || y==yy0+dy-1)  c2='-';  /* boxmarks */
        
    fprintf(stderr,"%c%c\n",c1,c2);
  }
}

/* same as out_b, but for faster use, only a box as argument
 */
void out_x(struct box *px) {
  out_b(px,NULL,0, 0, 0, 0, JOB->cfg.cs);
}


/* print out two boxes side by side, for debugging comparision algos */
void out_x2(struct box *box1, struct box *box2){
  int x,y,i,tx,ty,dy;
  /*FIXME jb static*/static char *c1="OXXXXxx@.,,,,,,,";
  pix *b=&JOB->src.p;
  dy=(box1->y1-box1->y0+1);
  if(dy<box2->y1-box2->y0+1)dy=box2->y1-box2->y0+1;
  tx=(box1->x1-box1->x0)/40+1;
  ty=(box1->y1-box1->y0)/40+1; // step, usually 1, but greater on large maps 
  if(box2)fprintf(stderr,"\n# list 2 patterns");
  for(i=0;i<dy;i+=ty) { // reduce the output to max 78x40???
    fprintf(stderr,"\n"); y=box1->y0+i;
    for(x=box1->x0;x<=box1->x1;x+=tx) 
    fprintf(stderr,"%c", c1[ ((pixel(b,x,y)<JOB->cfg.cs)?0:8)+marked(b,x,y) ] );
    if(!box2) continue;
    fprintf(stderr,"  "); y=box2->y0+i;
    for(x=box2->x0;x<=box2->x1;x+=tx)
    fprintf(stderr,"%c", c1[ ((pixel(b,x,y)<JOB->cfg.cs)?0:8)+marked(b,x,y) ] );
  }
}


/* ---- list output ---- for debugging --- */
int output_list(job_t *job) {
  int i = 0, j, cs = JOB->cfg.cs;
  struct box *box2;
  pix  *pp = &job->src.p;
  char *lc = job->cfg.lc;

  fprintf(stderr,"\n# list shape for charlist %s",lc);
  for_each_data(&(JOB->res.boxlist)) {
    box2 = (struct box *) list_get_current(&(JOB->res.boxlist));
    for (j=0; j<box2->num_ac; j++) 
      if (!lc || (box2->tac[j] && strchr(lc, box2->tac[j]))
              || (box2->tas[j] && strstr(lc, box2->tas[j]))) break;
    if (j<box2->num_ac)
      fprintf(stderr,"\n#            box found in charlist");
    if (!lc || (strchr(lc, box2->c) && box2->c < 256 && box2->c)
            || (strchr(lc, '_') && box2->c==UNKNOWN) // for compability
            || j<box2->num_ac ){  // also list alternative chars
      if (!pp) pp=box2->p;
      fprintf(stderr,
	      "\n# list shape %3d x=%4d %4d d=%3d %3d h=%d o=%d dots=%d %04x %s",
	      i, box2->x0, box2->y0,
	      box2->x1 - box2->x0 + 1,
	      box2->y1 - box2->y0 + 1,
	      num_hole(box2->x0, box2->x1, box2->y0, box2->y1, pp, cs,NULL),
	      num_obj( box2->x0, box2->x1, box2->y0, box2->y1, pp, cs),
	      box2->dots, (int)box2->c,   /* wchar_t -> char ???? */
	      decode(box2->c,ASCII) );
      if (JOB->cfg.verbose & 4) {
	out_x(box2);
      }
    }
    i++;
  } end_for_each(&(JOB->res.boxlist));
  return 0;
}

/* --- output of image incl. corored lines usefull for developers ---
 *  debugging
 *  bit 0+1 is used for color coding (optical marker)
 * color/gray:  0x01=red, 0x02=blue, 0x04=green???
 * opt: 1 - mark unknown boxes red       (first pass)
 *      2 - mark unknown boxes more red  (final pass)
 *      4 - mark lines blue
 *      8 - reset coloring (remove old marker)
 */
int debug_img(char *fname, struct job_s *job, int opt) {
  struct box *box2;
  int x, y, ic, dy, i, bits;
  unsigned char *np;
  pix *pp = &job->tmp.ppo;
  
  if( opt & 8 ) {		/* clear debug bits in image */
    for(y=0;y<pp->y;y++) {
      np=&pp->p[(pp->x)*y];
      for(x=0;x<pp->x;x++) {
        *np = *np & 0xF1;
        np++;
      }
    }
  }

  /* mark longest line which was used to estimate the rotation angle */
  if(job->cfg.verbose&32){
    for(x=0;x<pp->x;x++) {
      y=job->res.lines.ly+job->res.lines.dy*x/pp->x;
      np=&pp->p[x + (pp->x)*y];
      if (*np<160) continue;
      if((x&31)>23 && !(x&1))  /* dotted line */
        put(pp,x,y,255,8);
    }
  }

  if( opt & 4 )
  {
      struct tlines *lines = &job->res.lines;
      if (job->cfg.verbose)                                          
        fprintf(stderr, "# mark lines\n");   // or read from outside???
      dy = lines->dy;
      for (i = 0; i < lines->num; i++) {	// mark lines
	for (x = lines->x0[i]; x < lines->x1[i]; x++) {
	  y = lines->m1[i] + dy * x / pp->x;
          if (pp->p[x + (pp->x)*y]>=160)
	  if ((x &  7) <= 1) put(pp, x, y, 255, 8);
	  y = lines->m2[i] + dy * x / pp->x;
          if (pp->p[x + (pp->x)*y]>=160)
	  if ((x &  7) == 0) put(pp, x, y, 255, 8);
	  y = lines->m3[i] + dy * x / pp->x;
          if (pp->p[x + (pp->x)*y]>=160)
	  if ((x &  7) <  7) put(pp, x, y, 255, 8);
	  y = lines->m4[i] + dy * x / pp->x;
          if (pp->p[x + (pp->x)*y]>=160)
	  if ((x &  7) == 0) put(pp, x, y, 255, 8);
	}
      }
  }

  ic = ((opt & 2) ? 1 : 2);
  for_each_data(&(job->res.boxlist)) {
    box2 = (struct box *) list_get_current(&(job->res.boxlist));
    /* mark boxes in 32=0x40=blue */
    if (box2->c != ' ' && box2->c != '\n') {
      bits=4; /* green */
      /* mark unknown chars by 0x20=red frame */
      if (box2->c == UNKNOWN  && (opt & 3)) bits=2; /* red */
      for (y = box2->y0+2-ic; y <= box2->y1; y += 2) {
        np=&pp->p[box2->x0 + y * pp->x];
        if (*np>=160) *np=(*np & ~14) | bits; }
      for (y = box2->y0+2-ic; y <= box2->y1; y += 2) {
        np=&pp->p[box2->x1 + y * pp->x];
        if (*np>=160) *np=(*np & ~14) | bits; }
      for (x = box2->x0+2-ic; x <= box2->x1; x += 2) {
        np=&pp->p[x + box2->y0 * pp->x];
        if (*np>=160) *np=(*np & ~14) | bits; }
      for (x = box2->x0+2-ic; x <= box2->x1; x += 2) {
        np=&pp->p[x + box2->y1 * pp->x];
       if (*np>=160) *np=(*np & ~14) | bits; }
      /* mark pictures by blue cross */
      if (box2->c == PICTURE)
        for (x = 0; x < box2->x1-box2->x0+1; x++){
           y=(box2->y1-box2->y0+1)*x/(box2->x1-box2->x0+1);
	   pp->p[(box2->x0+x) + (box2->y0+y) * pp->x] |= 4;
	   pp->p[(box2->x1-x) + (box2->y0+y) * pp->x] |= 4;
	}
    }
  } end_for_each(&(job->res.boxlist));

  writeppm(fname, pp);
  return 0;
}
