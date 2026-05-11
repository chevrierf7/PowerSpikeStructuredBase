# Animation Pipeline

Regles de production animation pour garder un pipeline stable entre les joueurs, le gameplay et les futurs assets.

- Utiliser des avatars VRoid compatibles avec les os `J_Bip_*`.
- Partir de la meme T-pose ou A-pose source.
- Conserver des noms d'os compatibles VRoid.
- Conserver les memes orientations.
- Produire des animations stylisees anime/arcade.
- Declencher l'impact par timing, pas par collision stricte.
- Chaque animation de frappe doit avoir un `impact_time`.
- Chaque animation doit avoir une recovery lisible.
- Le gameplay garde le controle du deplacement.
- L'animation donne le rendu visuel, pas toute la logique.
