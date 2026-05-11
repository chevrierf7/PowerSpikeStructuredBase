# Combat Shots

Base interne des actions de match, animations attendues, timings d'impact et roles gameplay pour Shuttle Rush.

| Coup / Action | Animation | Vitesse | Sol / Saut | Type | Impact conseille | Role gameplay |
|---|---|---|---|---|---|---|
| Idle pret | idle_ready | lente | sol | posture | - | attente active |
| Split step | split_step | rapide | sol | deplacement | - | depart reactif |
| Course avant | move_forward | moyenne | sol | deplacement | - | aller au filet |
| Course arriere | move_backward | moyenne | sol | deplacement | - | replacement fond |
| Course laterale | move_side | moyenne | sol | deplacement | - | couvrir le terrain |
| Freinage | move_stop | rapide | sol | deplacement | - | arret credible |
| Degage coup droit | clear_forehand | moyenne | sol | neutre | 0.32 s | repousser au fond |
| Degage revers | clear_backhand | moyenne | sol | neutre | 0.34 s | defense fond revers |
| Smash coup droit | smash_forehand | rapide | sol/saut | attaque | 0.28 s | finir le point |
| Smash saute | jump_smash | tres rapide | saut | attaque | 0.36 s | attaque forte |
| Drive coup droit | drive_forehand | tres rapide | sol | attaque | 0.22 s | frappe tendue |
| Drive revers | drive_backhand | tres rapide | sol | attaque | 0.23 s | frappe tendue revers |
| Amorti filet | net_shot | lente | sol | finesse | 0.24 s | poser court |
| Lift | lift_forehand | moyenne | sol | defense | 0.30 s | relever le volant |
| Bloc defense | defense_block | rapide | sol | defense | 0.18 s | contrer smash |
| Defense lift | defense_lift | moyenne | sol | defense | 0.26 s | sauver bas/fond |
| Coup tardif | late_shot | rapide | sol | urgence | 0.16 s | rattrapage arcade |
| Plongeon defense | dive_defense | tres rapide | sol | urgence | 0.24 s | sauvetage spectaculaire |
| Recovery | recovery | moyenne | sol | transition | - | retour controle |
| Victoire point | point_win | lente | sol | reaction | - | feedback joueur |
| Perte point | point_lose | lente | sol | reaction | - | feedback joueur |

## Priorites animation

| Priorite | Animations |
|---|---|
| 1 | idle_ready, split_step, move_forward, move_backward, move_side, move_stop |
| 2 | clear_forehand, smash_forehand, drive_forehand, net_shot, lift_forehand, defense_block |
| 3 | clear_backhand, drive_backhand, defense_lift, late_shot |
| 4 | jump_smash, dive_defense, point_win, point_lose |
