# Porta il menu in un nuovo progetto

1. Copia `addons/flexible_menu` nel nuovo progetto Godot 4.7+.
2. Importa `addons/flexible_menu/menu.csv` (FileSystem > tasto destro > **Reimport**) e aggiungi
   `menu.it.translation`, `menu.en.translation` e `menu.es.translation` da **Project Settings >
   Localization > Translations**. Rimuovi le lingue che non userai.
3. In **Audio > Bus Layout**, crea i bus `Music` e `Effect` (entrambi inviati a `Master`), oppure
   cambia i nomi nell'Inspector del menu per abbinarli ai tuoi bus.
4. Crea una scena `Control`, istanzia `res://addons/flexible_menu/flexible_main_menu.tscn`, quindi
   imposta titolo, voci e lingue supportate nell'Inspector.
5. Collega i segnali del menu al gioco, imposta la scena come principale e premi **Play**.

Facoltativo: abilita **Flexible Menu** in **Project > Project Settings > Plugins** per aggiungerlo
dal pannello **Create Node**. Seleziona i file `.translation` generati dall'importazione del CSV;
non copiare i file `.translation` di questo progetto, perché devono essere rigenerati nel progetto
di destinazione.
