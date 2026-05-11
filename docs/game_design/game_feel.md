# Game Feel

Principes de sensation de jeu pour Shuttle Rush.

- Priorite au plaisir arcade.
- Favoriser les echanges fluides.
- Utiliser une assistance discrete de placement.
- Eviter une simulation realiste lourde.
- Garder des trajectoires lisibles.
- Rendre les impacts visibles et sonores.
- Ajouter un mini feedback a chaque frappe.
- Assumer un style manga/anime sportif.

## Hit Feedback Rules

- Le hit stop doit rester tres court.
- Le feedback varie selon le coup : smash lourd, drive sec, clear ample, net shot doux, defense reactive.
- La priorite reste la lisibilite du volant.
- Le feedback ne doit jamais nuire au controle joueur.
- Ne pas empiler plusieurs freezes.
- Les valeurs doivent rester configurables via `ShotData`.
- Si le freeze devient clairement visible, il est trop long.
