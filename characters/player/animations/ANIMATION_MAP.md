# Animation Map

Les FBX ont ete copies depuis `C:/Users/aho7/Desktop/jeu bad/animation` avec des noms simples pour Godot.

- `idle_wait.fbx`: attente principale.
- `idle.fbx`: idle alternatif.
- `move_forward.fbx`: deplacement avant.
- `move_backward.fbx`: deplacement arriere.
- `move_left.fbx`: deplacement lateral gauche.
- `move_right.fbx`: deplacement lateral droite.
- `serve_short.fbx`: service court.
- `serve_long.fbx`: service long.
- `forehand_low_drop_block.fbx`: coup droit bas amorti / bloc court.
- `forehand_low_lift_clear.fbx`: coup droit bas lift / degage defensif.
- `forehand_drive.fbx`: coup droit drive.
- `forehand_high_drop.fbx`: coup droit haut amorti.
- `forehand_high_clear.fbx`: coup droit haut degage.
- `smashJeuBad.fbx`: coup droit haut smash / frappe tendue utilisee par le jeu.
- `forehand_high_smash.fbx`: ancienne animation de smash conservee en reference.
- `forehand_tense_hit.fbx`: frappe tendue historique.
- `backhand_low_drop_block.fbx`: revers bas amorti / bloc court.
- `backhand_low_lift.fbx`: revers bas lift.
- `backhand_drive.fbx`: revers drive.
- `backhand_high_drop.fbx`: revers haut amorti.
- `backhand_high_clear.fbx`: revers haut degage.

Pour generer le GLB anime complet, lancer depuis Blender:

```powershell
blender --background --python tools/build_animated_player.py
```
