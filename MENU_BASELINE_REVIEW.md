# Valutazione della base menu originale

## Esito

Il progetto era un buon prototipo di menu desktop: ha schermata splash, transizioni, navigazione
con focus e i primi controlli audio/display. Non era però ancora adatto come base innestabile in
nuovi giochi senza interventi ripetuti.

## Problemi rilevati

- `main_menu.tscn` incorpora lo script e percorsi `res://` specifici: non offre punti di
  integrazione riusabili.
- `Global` e `GameController` condividono responsabilità di impostazioni e display, con logica
  duplicata. Il menu non può essere usato senza quell'autoload e quella gerarchia di scena.
- `setting_menu.gd` collega gli stessi segnali anche nel codice, già collegati dalla scena: in
  esecuzione possono quindi essere richiamati due volte.
- Le risoluzioni sono un elenco fisso, la modalità esclusiva/non-windowed evita l'applicazione di
  una risoluzione e non è prevista una strategia web.
- Il pulsante Continue non verifica né espone la presenza di un salvataggio; non esiste un
  contratto per collegarlo alla logica del gioco.
- La cartella `UI-Tutorial-Repo-1.10` duplica gran parte del progetto e aumenta il rischio di
  modificare la copia sbagliata.

## Architettura introdotta

`addons/flexible_menu/` non usa autoload né conosce scene del gioco. `FlexibleMainMenu` espone
checkbox nell'Inspector e segnali per i casi specifici. `FlexibleMenuSettingsStore` gestisce la
persistenza delle preferenze e `FlexibleMenuSaveRepository` i file JSON degli slot. Le scene di
gioco restano opzionali nei campi Inspector.

Il renderer Forward+ è stato conservato perché il progetto è PC-first. Per un export web, il
progetto ospite deve usare Compatibility; l'addon evita perciò le API desktop per risoluzione e
fullscreen nel browser.

## Passi di integrazione

1. Abilita **Flexible Menu** in `Project Settings > Plugins`.
2. Istanzia `FlexibleMainMenu` (oppure usa la scena fornita) e scegli le voci dall'Inspector.
3. Definisci le Input Map del gioco e collega i segnali di nuova partita/caricamento.
4. Nel gioco salva il payload con `FlexibleMenuSaveRepository.save_slot`.
