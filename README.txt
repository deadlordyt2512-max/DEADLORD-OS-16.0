DEADLORD OS 16.0 · INSTALACIÓN INDEPENDIENTE

INCLUYE
- index.html: sitio adaptado para funcionar sin Claude.
- config.js: aquí se configura el proyecto Supabase.
- schema.sql: tablas, políticas y funciones SQL.
- media/: coloca aquí la canción original en formato MP3.

1) CREAR BASE DE DATOS
- Entra a https://supabase.com y crea un proyecto gratuito.
- Abre Project Settings > API (o Connect) y copia Project URL y la clave anon/publishable.
- Edita config.js y sustituye TU-PROYECTO y TU_CLAVE_ANON_O_PUBLISHABLE.
- En Supabase abre SQL Editor, pega TODO schema.sql y ejecútalo.
- En Authentication > Providers deja Email habilitado para la cuenta administradora.

2) CREAR ADMINISTRADOR
- En Supabase > Authentication > Users crea/invita tu cuenta de administrador.
- Copia el UUID de esa cuenta.
- En SQL Editor ejecuta, sustituyendo el UUID:

  update auth.users
  set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
  where id = 'UUID-DE-TU-CUENTA';

- Inicia sesión en el sitio con ROOT LOGIN, usando ese correo y contraseña.
- No compartas esa cuenta. Nunca pongas la service_role key en config.js.

3) SUBIR GRATIS
- En https://app.netlify.com/drop puedes arrastrar la carpeta completa del sitio (o su ZIP descomprimido).
- El archivo principal debe llamarse index.html. Netlify te dará un enlace público.
- Si vuelves a editar archivos, vuelve a desplegar la carpeta.

4) MÚSICA
- El HTML original apuntaba a una ruta interna de Claude que no funciona fuera de Claude.
- Coloca el archivo de la canción como media/el-siguiente-ciclo.mp3.
- Si no tienes el MP3 original, el reproductor mostrará un error hasta añadirlo.

5) PRUEBAS ANTES DE COMPARTIR
- Abre el enlace en una ventana privada y en otro dispositivo.
- Registra dos nombres diferentes y confirma que ambos aparecen en la lista.
- Intenta registrar el mismo nombre con mayúsculas/minúsculas distintas: debe rechazarlo.
- Confirma asistencia y comprueba que cambia en el otro dispositivo.
- Cierra y vuelve a abrir el sitio: el registro debe seguir ahí.
- Prueba ROOT LOGIN y verifica que solo la cuenta con rol admin ve el panel.

NOTAS IMPORTANTES
- El sitio es público: cualquier persona con el enlace puede ver los nombres y estados de asistencia.
- La lista y los anuncios son compartidos en tiempo real.
- Los nombres WBC son únicos sin distinguir mayúsculas/minúsculas y espacios repetidos.
- El registro se protege con una restricción UNIQUE en PostgreSQL, no con una comprobación solo del navegador.
- La clave anon/publishable está diseñada para estar en el frontend; la seguridad depende de RLS y las funciones SQL.
- No se ha publicado ni probado contra un proyecto real porque todavía faltan tus credenciales Supabase y la canción MP3.
