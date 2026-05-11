# Player Profiles

Le systeme `PlayerProfile` doit rester la source de verite pour l'identite visuelle et les informations publiques des joueurs.

Chaque joueur doit avoir :

- `id`
- `display_name`
- `portrait`
- `character_model`
- `color_primary`
- `color_secondary`
- `color_accent`

Les couleurs joueur doivent alimenter :

- le HUD ;
- les effets ;
- la tenue ;
- la raquette ;
- les elements visuels futurs.

Eviter les noms et couleurs codes en dur. Les ecrans, effets et composants de presentation doivent lire les donnees du `PlayerProfile` quand l'information concerne un joueur.

## Compatibilite personnages VRoid

Chaque joueur jouable doit pointer vers un profil `VroidAvatarProfile`.
Le personnage charge en match doit utiliser un avatar VRoid compatible avec les os `J_Bip_*`, puis recevoir les animations DeepMotion par le pont d'animation.

Si un joueur n'a pas encore son skin final, il doit utiliser un profil VRoid existant compatible. Le jeu ne doit plus retomber sur l'ancien personnage de base.
