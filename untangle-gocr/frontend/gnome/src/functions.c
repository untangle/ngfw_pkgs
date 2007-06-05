/* file functions.h
 * Author : Dany De Bontridder
 * $Revision: 1.6 $
 * 
 * contains all the button functions
 */

#include <gtk/gtk.h>
#include <glib.h>
#include <stdio.h>
#include <stdlib.h>
gchar INITFILE[]=".gtk_ocr";

#include "common.h"
GtkWidget *spin_GreyLevel;
GtkWidget *spin_DustSize;
GtkWidget *spin_Space;
GtkWidget *TxtViewer;
GtkWidget *TxtPath;

guint nSpace=0,nGrey=160,nDust=10;
gchar Viewer[200]="display";
gchar *Path=NULL;
/*!
 * \brief Parse the init file
 * \param the gchar pointer to a line read from 
 * the init file
 * \warning change global variable
 */
void Parse(char *l)
{
  char *q;
  q=strchr(l, '\n');
  if (q != NULL) *q='\0';

  if (strstr(l,"DUST=\0")!=NULL)
    {
      nDust=atoi(l+5);
    }
  else if ( strstr(l,"GREY=\0")!=NULL)
    {
      nGrey=atoi(l+5);
    }
  else if ( strstr(l,"SPACE=\0")!=NULL)
    {
      nSpace=atoi(l+6);
    }
  else if ( strstr(l,"PATH=\0")!=NULL)
    {
      Path=g_malloc(strlen(l)-4);
      sprintf(Path,"%s",l+5);
    }
  else if ( strstr(l,"VIEWER=\0")!=NULL)
    {
      sprintf(Viewer,l+7);
    }

      
}    
/*!
 * ViewFile (GtkWidget , gpointer)
 * \brief display a file in the viewer
 * \par 
 * Find the viewer name
 *\par
 * compose a string
 * \par
 * make a goal system
 */
void ViewFile(GtkWidget *wid, gpointer Data)
{
  char cmd[2048];
  gchar *Name;
  if (nSelectedRow==-1)     return;

  gtk_clist_get_text(list_file,nSelectedRow,0,&Name);
  sprintf(cmd,"%s %s &",Viewer,Name);

  system (cmd);
}

/**
 * @brief Close the file selection and destroy the dialog box
 * @param GtkWidget is the button cancel
 * @param gpointer Data is the dial.box
 * @return Nothing
 */
void destroy_fileSel(GtkWidget *wid,gpointer data)
{
#ifdef DEBUG
  g_print("\nDestroy object");
#endif
  gtk_widget_destroy( GTK_WIDGET (data));
}
/**
 * @brief Close the application
 * @param Widget ref
 * @param gpointer
 * @return nothing
 */
void Close(GtkWidget *widget,gpointer Data)
{
  gtk_exit(0);  
}

void OkSetting(GtkWidget *widget,gpointer Data)
{
  nSpace= gtk_spin_button_get_value_as_int((GtkSpinButton *)spin_Space);
  nDust= gtk_spin_button_get_value_as_int((GtkSpinButton *)spin_DustSize);
  nGrey= gtk_spin_button_get_value_as_int((GtkSpinButton *)spin_GreyLevel);

#ifdef DEBUG
  g_print("\nGrey %d\nSpace %d\nDust %d",nGrey,
	  nSpace,nDust);
#endif

  strcpy(&Viewer[0],gtk_entry_get_text((GtkEntry *) TxtViewer));
  if ( Path != NULL)
    free(Path);
  Path=g_malloc(strlen(gtk_entry_get_text((GtkEntry *) TxtPath)+1));
#ifdef DEBUG
	g_print("Path = %s length = %d",
	       Path,
	       strlen(gtk_entry_get_text((GtkEntry *) TxtPath)));
#endif
  strcpy(&Path[0],gtk_entry_get_text((GtkEntry *) TxtPath));
  gtk_widget_destroy(GTK_WIDGET (Data));
}

void SaveSetting(GtkWidget *widget,gpointer Data)
{
  FILE *pf_Setting;
  gchar *pHome;
  gchar *pInitFile;
  nSpace= gtk_spin_button_get_value_as_int((GtkSpinButton *)spin_Space);
  nDust= gtk_spin_button_get_value_as_int((GtkSpinButton *)spin_DustSize);
  nGrey= gtk_spin_button_get_value_as_int((GtkSpinButton *)spin_GreyLevel);

#ifdef DEBUG
  g_print("\nGrey %d\nSpace %d\nDust %d",nGrey,
	  nSpace,nDust);
#endif

  strcpy(&Viewer[0],gtk_entry_get_text((GtkEntry *) TxtViewer));

  if ( Path != NULL)
    g_free(Path);
  Path=g_malloc(strlen(gtk_entry_get_text((GtkEntry *) TxtPath)+1));

  strcpy(&Path[0],gtk_entry_get_text((GtkEntry *) TxtPath));

#ifdef DEBUG
	g_print("Path = %s length = %d",
	       Path,
	       strlen(gtk_entry_get_text((GtkEntry *) TxtPath)));
#endif

  pHome=getenv("HOME");
  pInitFile=g_malloc(strlen(pHome)+strlen(INITFILE)+2);
  sprintf(pInitFile,"%s/%s",
	  pHome,
	  INITFILE);

  if ( (pf_Setting=fopen(pInitFile,"w+")) == NULL)
	{
	  /* Error */
	  g_print("Cannot open it %s",
		  pInitFile);
	}
  else
	{
	  fprintf(pf_Setting,"GREY=%d\n"
		  "DUST=%d\n"
		  "SPACE=%d\n"
		  "VIEWER=%s\n"
		  "PATH=%s\n",
		  nGrey,
		  nDust,
		  nSpace,
		  Viewer,
		  Path);
	  fclose(pf_Setting);
	}
  
  gtk_widget_destroy( GTK_WIDGET  (Data));
}
void ReadSetting(void)
{
  FILE *pf_Setting;
  gchar *pHome;
  gchar *pInitFile;
  pHome=getenv("HOME");
  pInitFile=g_malloc(strlen(pHome)+strlen(INITFILE)+2);
  sprintf(pInitFile,"%s/%s",
	  pHome,
	  INITFILE);

  if ( (pf_Setting=fopen(pInitFile,"r")) == NULL)
	{
	    if ( (pf_Setting=fopen(pInitFile,"w+")) == NULL)
	      {
		/* Error */
		g_print("Cannot open it %s",
			pInitFile);
	      }
	    else
	      {
		fprintf(pf_Setting,"GREY=%d\n"
			"DUST=%d\n"
			"SPACE=%d\n"
			"VIEWER=%s\n"
			"PATH=/usr/bin/gocr\n",
			nGrey,
			nDust,
			nSpace,
			Viewer);

		fclose(pf_Setting);
	      }
	}
  else
	{
	  gchar l[256];
	  while(! feof (pf_Setting))
	    {
	      if (fgets (l,256,pf_Setting)!= NULL)
		{
		  Parse(l);
		}
	    }
	  fclose(pf_Setting);
	}
  
}
void CancelSetting(GtkWidget *widget,gpointer Data)
{
  gtk_widget_destroy(Data);
}
/**
 * @brief
 * @param Widget ref
 * @param gpointer
 * @return nothing
 */
void Setting(GtkWidget *widget,gpointer Data)
{
  GtkWidget *Dialog;
  GtkTable *TableDialog;
  GtkWidget *label;
  GtkAdjustment *Adj;
  GtkWidget *but_ok;
  GtkWidget *but_cancel;
  GtkWidget *but_save;

  TableDialog=(GtkTable *) gtk_table_new(6,3,TRUE);

  Dialog=gtk_window_new(GTK_WINDOW_TOPLEVEL);
  
  gtk_window_set_title( GTK_WINDOW (Dialog),
			"Setting for jocr");

  gtk_container_add((GtkContainer *) Dialog,(GtkWidget *) TableDialog);
  
  gtk_signal_connect(GTK_OBJECT (Dialog),"delete_event",
		     GTK_SIGNAL_FUNC(destroy_fileSel)
		     ,NULL);
  /*
   * Grey level
   */
  label=gtk_label_new("Grey level");
  Adj=(GtkAdjustment *) gtk_adjustment_new((float) nGrey,
					   0.0,255.0,1.0,1.0,1.0);
  spin_GreyLevel=gtk_spin_button_new(Adj,0,0);

  gtk_table_attach_defaults(TableDialog,
			    label,
			    0,2,0,1);
  gtk_widget_show(label);
  gtk_table_attach_defaults(TableDialog,
			    spin_GreyLevel,
			    2,3,0,1);
  /*
   * Dust 
   */
  label=gtk_label_new("Dust Size");
  Adj=(GtkAdjustment *)gtk_adjustment_new((float) nDust,0.0,255.0,1.0,1.0,1.0);
  spin_DustSize=gtk_spin_button_new(Adj,0,0);

  gtk_table_attach_defaults(TableDialog,
			    label,
			    0,2,1,2);
  gtk_table_attach_defaults(TableDialog,
			    spin_DustSize,
			    2,3,1,2);

  /*
   * Space
   */
  label=gtk_label_new("Space Width (0= autodetect)");
  Adj=(GtkAdjustment *)gtk_adjustment_new((float) nSpace,0.0,255.0,1.0,1.0,1.0);
  spin_Space=gtk_spin_button_new(Adj,0,0);

  gtk_widget_show(label);
  gtk_table_attach_defaults(TableDialog,
			    label,
			    0,2,2,3);
  gtk_table_attach_defaults(TableDialog,
			    spin_Space,
			    2,3,2,3);

  /*
   * Text Entry -> Viewer 
   */
  label=gtk_label_new("Name of the viewer");
  gtk_table_attach_defaults(GTK_TABLE (TableDialog),
			    GTK_WIDGET (label),
			    0,2,3,4);
  gtk_widget_show ( GTK_WIDGET (label));

  TxtViewer=gtk_entry_new();
  gtk_entry_set_text((GtkEntry*)TxtViewer,
		     Viewer);
  gtk_table_attach_defaults(GTK_TABLE (TableDialog),
			    GTK_WIDGET (TxtViewer),
			    2,3,3,4);

  /*
   * Text Entry -> Path 
   */
  label=gtk_label_new("Path to ocr ");
  gtk_table_attach_defaults(GTK_TABLE (TableDialog),
			    GTK_WIDGET (label),
			    0,2,4,5);
  gtk_widget_show ( GTK_WIDGET (label));
  if ( Path == NULL)
    {
      Path = g_malloc(strlen("/usr/bin/gocr\0"+1));
      sprintf(Path,"/usr/bin/gocr");
    }

  TxtPath=gtk_entry_new();
  gtk_entry_set_text((GtkEntry*)TxtPath,
		     Path);
  gtk_table_attach_defaults(GTK_TABLE (TableDialog),
			    GTK_WIDGET (TxtPath),
			    2,3,4,5);


  /* 
   * Ok button
   */
  but_ok=gtk_button_new_with_label("Ok");
  gtk_table_attach_defaults(TableDialog,
			    but_ok,
			    0,1,5,6);
  gtk_signal_connect(GTK_OBJECT (but_ok),
		     "clicked",
		     OkSetting,
		     Dialog);
  
  /* 
   * Cancel button
   */
  but_cancel=gtk_button_new_with_label("Cancel");
  gtk_table_attach_defaults(TableDialog,
			    but_cancel,
			    1,2,5,6);
  gtk_signal_connect(GTK_OBJECT (but_cancel),
		     "clicked",
		     CancelSetting,
		     Dialog);
  /*
   * Save setting Button
   */
  but_save=gtk_button_new_with_label("Save");
  gtk_table_attach_defaults(TableDialog,
			    but_save,
			    2,3,5,6);
  gtk_signal_connect(GTK_OBJECT (but_save),
		     "clicked",
		     SaveSetting,
		     Dialog);

  /*
   * Show other object
   */

  gtk_widget_show( GTK_WIDGET (TableDialog));
  gtk_widget_show(Dialog);
  gtk_widget_show(spin_DustSize);
  gtk_widget_show(spin_Space);
  gtk_widget_show(but_ok);
  gtk_widget_show(but_save);
  gtk_widget_show(but_cancel);
  gtk_widget_show ( GTK_WIDGET (TxtViewer));
  gtk_widget_show ( GTK_WIDGET (TxtPath));
  gtk_widget_show(spin_GreyLevel);
}
/**
 * @brief
 * @param Widget ref to the ok_button
 * @param gpointer to the GtkWidget FileSelection
 * @return nothing
 */
 void AddFile(GtkWidget *widget,gpointer Data)
{
  gchar *list[2];

  if ( (list[0]=gtk_file_selection_get_filename(GTK_FILE_SELECTION(Data))) != NULL)
    {
      nFileSelected++;
  
      if (nFileSelected==1)
	{ 
	  gtk_widget_show(button_Remove);
	  gtk_widget_show(button_Convert);
	  gtk_widget_show(button_View);
	}
      gtk_clist_append(GTK_CLIST (list_file),list);
      gtk_clist_thaw( GTK_CLIST (list_file));
    }
  gtk_widget_destroy( GTK_WIDGET (Data));

}

/**
 * @brief
 * @param Widget ref
 * @param gpointer
 * @return nothing
 */
void Convert(GtkWidget *widget,gpointer Data)
{
  int nLoop=0;
  gchar *Name;
  gchar Command[2048];
  for (nLoop=0;nLoop<nFileSelected;  nLoop++)
    {
      gtk_clist_get_text(list_file,nLoop,0,&Name);
      sprintf(Command,"%s -l %d -d %d -s %d %s -o %s.txt &",
	      Path,
	      nGrey,nDust,nSpace,Name,Name);
#ifdef DEBUG
      
      g_print("\nCommande : %s",Command);
#endif
      system (Command);
    }
  gtk_clist_clear(list_file);
  gtk_widget_hide(button_Remove);
  gtk_widget_hide(button_View);
  gtk_widget_hide(button_Convert);
  nSelectedRow=0;
}

/**
 * @brief
 * @param Widget ref
 * @param gpointer
 * @return nothing
 */
void RemoveFile(GtkWidget *widget,gpointer Data)
{
  if (nSelectedRow != -1)
    {
      gtk_clist_remove(list_file,nSelectedRow);
      nFileSelected--;
    }
  if (nFileSelected==0)
    {
      gtk_widget_hide(button_Remove);
      gtk_widget_hide(button_View);
      gtk_widget_hide(button_Convert);
    }
}

/**
 * @brief
 * @param Widget ref
 * @param gpointer
 * @return nothing
 */
void Browse(GtkWidget *widget,gpointer Data)
{

  FileSelection=gtk_file_selection_new("Choose a file to convert");

  gtk_signal_connect(GTK_OBJECT(GTK_FILE_SELECTION (FileSelection) ->ok_button),
		     "clicked",GTK_SIGNAL_FUNC(AddFile),
		     FileSelection);

  
  gtk_signal_connect(GTK_OBJECT(GTK_FILE_SELECTION (FileSelection)->cancel_button),
		     "clicked",GTK_SIGNAL_FUNC(destroy_fileSel),
		     GTK_OBJECT (FileSelection));

  gtk_widget_show(FileSelection);
}









