# Power Spike Structured Base

Nouvelle base Godot structuree a partir du prototype Power Spike Badminton.

## Objectif

Conserver ce qui fonctionne dans le prototype original:

- terrain 3D de badminton avec lignes officielles principales;
- joueur Kai contre IA Mina;
- volant arcade semi-guide;
- services court, tendu et lobe;
- coups lob, amorti et smash;
- regles de score 21 points, 2 points d'ecart, cap a 30;
- service pair/impair en diagonale;
- modes simple et double;
- camera terrain / camera joueur;
- controles clavier, souris, manette et tactile.

Et separer le code pour pouvoir continuer le developpement sans tout modifier dans un seul fichier.

## Structure

- `scenes/main.tscn`: scene principale minimale.
- `scripts/game/Game.gd`: chef d'orchestre de la partie.
- `scripts/game/MatchState.gd`: score, service, regles simple/double, zones valides.
- `scripts/entities/PlayerCharacter.gd`: personnage, deplacement, modele 3D, animation, raquette.
- `scripts/entities/Shuttle.gd`: volant et trajectoire semi-guidee.
- `scripts/world/CourtBuilder.gd`: terrain, lignes et filet.
- `scripts/ui/GameHud.gd`: score, textes, boutons et controles tactiles.
- `scripts/config/GameConfig.gd`: constantes partagees et profils de coups.
- `characters/player/`: modeles, textures, animations et raquette recuperes du prototype.

## Commandes

- `ZQSD`: deplacement.
- `Espace`: servir ou passer au set suivant.
- Clic gauche: lob.
- Clic droit: amorti.
- Clic molette ou `E`: smash.
- `Tab`: changer simple/double hors rally.
- `C`: changer de camera.

## Suite conseillee

1. Ouvrir ce dossier comme nouveau projet Godot.
2. Lancer `scenes/main.tscn`.
3. Tester l'affichage, la camera, le service et les trois coups.
4. Ajuster les sensations du volant dans `GameConfig.shot_profile`.
5. Ameliorer progressivement l'IA dans `Game.gd` ou creer ensuite un vrai `AIController.gd`.

Le prototype original n'a pas ete modifie.
