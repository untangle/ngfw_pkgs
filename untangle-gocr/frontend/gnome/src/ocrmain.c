/*
 * ocrmain.c
 * 
 * purpose : Main file
 *
 * $Revision: 1.4 $
 * $Author: danydb $
 *
 *
 */
#include <gtk/gtk.h>
#include <glib.h>
#include <stdio.h>

#include "common.h"

GtkWidget *button_Remove;

GtkWidget *MainWindow;
GtkCList *list_file;
GtkTable *Table;
GtkWidget *button_Add;
GtkWidget *button_Close;
GtkWidget *button_Setting;
GtkWidget *button_View;
GtkWidget *button_Convert;
GtkWidget *bar_status;
GtkWidget *FileSelection;

/**
 * Selected file
 */
int nFileSelected=0;


GtkWidget *MainWindow;
/*!
 * \var Current Selected Row
 */

gint nSelectedRow=-1;
void SelectRow(GtkWidget *wid,
	       gint row,
	       gint col,
	       GdkEventButton *event,
	       gpointer Data)
{

  nSelectedRow=row;
  
}

void unSelectRow(GtkWidget *wid,
	       gint row,
	       gint col,
	       GdkEventButton *event,
	       gpointer Data)
{
 nSelectedRow=-1;
}

void Test(GtkWidget *widget,gpointer data)
{
  g_print("\nClicked");
}
/**
 * 
 * Description : Quit cleanly 
 *
 * @param : None
 *
 * @return : none
 *
 */

void delete_event(GtkWidget *Widget,
		  GdkEvent *event,
		  gpointer Data)
{
  gtk_main_quit();
}

/**
 * CreateMainWindow
 * \brief  Create the main Window and all of the
 * object contained in that Window.
 * Open also the init file and create it if 
 * it doens't exist
 * \par it means the button widgets and their
 * signal connection
 * 
 *
 * @param  None
 *
 * @return  none
 *
 */

void CreateMainWindow()
{
  GtkWidget *scrolled_window;
  gchar *FileToConvert[]={"Files To convert","\0"};
  MainWindow=gtk_window_new(GTK_WINDOW_TOPLEVEL);

  gtk_window_set_title(GTK_WINDOW (MainWindow)," gtk-ocr ");
  
  gtk_signal_connect(GTK_OBJECT (MainWindow) ,"delete_event",
		     GTK_SIGNAL_FUNC(delete_event),NULL);
 
  Table = (GtkTable *) gtk_table_new(6,5 ,TRUE);

  gtk_table_set_row_spacings(Table,2);
  gtk_table_set_col_spacings(Table,1);

  gtk_container_add(GTK_CONTAINER (MainWindow),GTK_WIDGET (Table));

  /* button creation*/
  button_Add=gtk_button_new_with_label("Add");
  button_Close=gtk_button_new_with_label("Close");
  button_Setting=gtk_button_new_with_label("Setting");
  button_Convert=gtk_button_new_with_label("Convert");
  button_Remove=gtk_button_new_with_label("Remove");
  button_View=gtk_button_new_with_label("View");

  gtk_signal_connect(GTK_OBJECT (button_Add),"clicked",
		     GTK_SIGNAL_FUNC(Browse),"Add");

  gtk_signal_connect(GTK_OBJECT (button_Convert),"clicked",
		     GTK_SIGNAL_FUNC(Convert),"Convert");

  gtk_signal_connect(GTK_OBJECT (button_Setting),"clicked",
		     GTK_SIGNAL_FUNC(Setting),"Setting");

  gtk_signal_connect(GTK_OBJECT (button_Close),"clicked",
		     GTK_SIGNAL_FUNC(Close),"Close");

  gtk_signal_connect(GTK_OBJECT (button_Remove),"clicked",
		     GTK_SIGNAL_FUNC(RemoveFile),"RemoveFile");

  gtk_signal_connect(GTK_OBJECT (button_View),"clicked",
		     GTK_SIGNAL_FUNC(ViewFile),"ViewFile");

  gtk_table_attach_defaults(Table,button_Add,0,1,0,1);
  gtk_table_attach_defaults(Table,button_Remove,0,1,1,2);
  gtk_table_attach_defaults(Table,button_Convert,0,1,2,3);
  gtk_table_attach_defaults(Table,button_View,0,1,3,4);
  gtk_table_attach_defaults(Table,button_Setting,0,1,4,5);
  gtk_table_attach_defaults(Table,button_Close,0,1,5,6);

  /* List Creation */
  scrolled_window=gtk_scrolled_window_new(NULL,NULL);
  gtk_widget_set_usize(scrolled_window,250,150);

  gtk_table_attach_defaults(Table,scrolled_window,1,5,0,6);
  gtk_scrolled_window_set_policy((GtkScrolledWindow*) scrolled_window,
				 (GtkPolicyType) GTK_POLICY_AUTOMATIC,
				 (GtkPolicyType) GTK_POLICY_AUTOMATIC);
					


  list_file=(GtkCList *) gtk_clist_new_with_titles(1,FileToConvert);

  gtk_clist_set_selection_mode(list_file,GTK_SELECTION_MULTIPLE);

  gtk_clist_set_shadow_type(list_file,GTK_SHADOW_ETCHED_IN);
  gtk_scrolled_window_add_with_viewport(
					GTK_SCROLLED_WINDOW (scrolled_window),
					GTK_WIDGET (list_file));
  gtk_clist_set_column_auto_resize(list_file,
				   0,
				   TRUE);

  gtk_signal_connect(GTK_OBJECT (list_file),
		     "select-row",
		     GTK_SIGNAL_FUNC (SelectRow),
		     NULL);

  gtk_signal_connect(GTK_OBJECT (list_file),
		     "unselect-row",
		     GTK_SIGNAL_FUNC (unSelectRow),
		     NULL);
  ReadSetting();
  /* Show everything */
  gtk_widget_show(GTK_WIDGET (list_file));
  gtk_widget_show(GTK_WIDGET ( button_Add));
  gtk_widget_show(GTK_WIDGET (button_Setting));
  gtk_widget_show(GTK_WIDGET (button_Close));
  gtk_widget_show(GTK_WIDGET (scrolled_window));
  gtk_widget_show(GTK_WIDGET (Table));
 
  gtk_widget_show(MainWindow);

}

gint main(int argc, char **argv)
{

  gtk_init(&argc,&argv);
  
  CreateMainWindow();


  gtk_main();

  return 0;
}
