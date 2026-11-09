#include <glib.h>
#include <stdio.h>
int main(int argc,char**argv){gchar*data;gsize len;if(!g_file_get_contents(argv[1],&data,&len,NULL))return 1;
 const char*types[]={"a(aussasasu)","a(ausasu)","a(aussasu)","a(auss)",NULL};
 for(int t=0;types[t];t++){GVariant*v=g_variant_new_from_data(G_VARIANT_TYPE(types[t]),data,len,FALSE,NULL,NULL);
  if(!g_variant_is_normal_form(v)){g_variant_unref(v);continue;}
  fprintf(stderr,"type %s n=%zu\n",types[t],g_variant_n_children(v));
  gchar*s=g_variant_print(v,FALSE);fputs(s,stdout);return 0;}
 fprintf(stderr,"no type\n");return 2;}
