# Flexible Menu

Menu iniziale riutilizzabile per progetti Godot 4.7. L'addon vive interamente in
`addons/flexible_menu`: non richiede autoload, plugin obbligatorio, asset esterni o modifiche
al progetto ospitante. Il plugin aggiunge il tipo rapido `FlexibleMainMenu` all'editor; in
alternativa puoi istanziare la scena direttamente.

## Installazione rapida

1. Copia la cartella `addons/flexible_menu` nel progetto Godot 4.7+ di destinazione.
2. Reimporta `addons/flexible_menu/menu.csv`, poi aggiungi le traduzioni generate in
   **Project Settings > Localization > Translations**.
3. Crea i bus audio `Music` e `Effect` in **Audio > Bus Layout**, oppure cambia i nomi nell'Inspector.
4. Crea una scena `Control`, istanzia `res://addons/flexible_menu/flexible_main_menu.tscn` e
   configura titolo, voci e lingue supportate nell'Inspector.
5. Collega i segnali, imposta la scena come principale e avvia il gioco.

Puoi abilitare **Flexible Menu** da **Project > Project Settings > Plugins** per aggiungere il
nodo dal pannello **Create Node**. Le traduzioni binarie vanno rigenerate nel progetto host dal CSV.

Per aggiornare il componente, sostituisci `addons/flexible_menu` con la versione nuova; il
progetto non deve modificare `project.godot` per ricevere gli aggiornamenti. Copia la cartella
intera, comprese le traduzioni e i file `.uid`.

## Collegare il gioco

Collega i segnali `new_game_requested`, `continue_requested(save_data)`,
`load_game_requested(save_data)`, `settings_requested`, `credits_requested`, `quit_requested` e
`accessibility_changed(values)` dall'Inspector o via codice. `new_game_scene` e `after_load_scene`
sono scorciatoie facoltative per cambiare scena dopo l'emissione dei segnali.

Il sistema slot integrato salva i dizionari del gioco tramite
`FlexibleMenuSaveRepository.save_slot("slot_1", {"level": 4}, "Capitolo 4")`. Per un flusso di
salvataggio personalizzato disabilita **Enable Save System** e gestisci i segnali nel gioco.
Le impostazioni del menu sono memorizzate in `user://flexible_menu_settings.cfg`; gli slot sono in
`user://saves/`.

## Impostazioni e localizzazione

- Configura gli eventi rimappabili in **Project Settings > Input Map**; inserisci in
  `remappable_actions` solo le azioni che vuoi esporre. Vuoto significa tutte le azioni non `ui_`.
- Bus audio predefiniti: `Master`, `Music`, `Effect`. Cambia i nomi nell'Inspector oppure disabilita
  **Enable Audio Settings** se quei controlli non sono adatti al gioco.
- Le traduzioni `it`, `en` ed `es` sono incluse. Importa `menu.csv` nel progetto host e aggiungi
  i `.translation` generati a **Project Settings > Localization > Translations** per usare il
  selettore lingua. Il selettore usa le traduzioni già caricate dal progetto.
- `accessibility_changed(values)` consegna preferenze come testo grande, contrasto elevato,
  riduzione movimento e sottotitoli: il gioco decide come applicarle.
- Il fullscreen e la risoluzione vengono omessi in web export.

## Demo e struttura

Apri `res://addons/flexible_menu/demo/demo.tscn` nel progetto di esempio per vedere il menu
configurato. Il nodo è una scena `Control` standard; i servizi per impostazioni e salvataggi sono
script interni caricati con `preload`, senza nomi globali o autoload che possano collidere con il
progetto host.
