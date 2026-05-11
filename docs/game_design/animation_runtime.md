# Animation Runtime

Ce document decrit la couche runtime qui relie gameplay, animation, timings d'impact et trajectoires du volant.

## Flux d'un coup

1. Le gameplay valide qu'un joueur peut frapper.
2. Le coup est associe a un `ShotData`.
3. La machine d'etat joueur entre en `PrepareShot`, puis `Swing`.
4. Avant l'impact, un recalage arcade discret peut rapprocher legerement le joueur du volant.
5. A `impact_time`, le callback `on_shot_impact()` declenche le vrai lancement du volant.
6. La machine passe en `Recovery`, puis en `Reposition`.
7. Le gameplay reprend le controle normal du deplacement.

## Role de ShotData

`ShotData` est une `Resource` qui decrit un coup sans imposer une scene ou une animation importee.

Elle contient :

- l'identifiant du coup ;
- le nom d'animation cible ;
- le timing d'impact ;
- le temps de recovery ;
- une echelle de vitesse de recalage ;
- des valeurs temporaires de vitesse, arc et spin du volant ;
- les flags `can_jump` et `is_attack`.

Ces valeurs restent la reference gameplay. Les animations DeepMotion doivent se synchroniser avec elles, pas les remplacer silencieusement.

## Role de la machine d'etat

`PlayerShotStateMachine` separe les intentions de gameplay du rendu animation.

Etats minimum :

- `Idle`
- `Move`
- `PrepareShot`
- `Swing`
- `Impact`
- `Recovery`
- `Reposition`

La machine n'impose pas le deplacement complet du joueur. Le gameplay garde la priorite, et la machine fournit les moments ou jouer une animation, declencher un impact ou sortir de recovery.

## Role de impact_time

`impact_time` empeche le volant de partir immediatement au moment ou le joueur appuie.

Le joueur commence son animation de frappe, puis le volant est lance seulement quand la machine emet `shot_impact`. Cela permettra plus tard de synchroniser les vraies animations, les sons, les effets visuels et le contact raquette/volant sans dependance a une collision physique stricte.

## Callbacks prepares

Callbacks runtime :

- `on_shot_impact()`
- `on_recovery_start()`
- `on_recovery_end()`

Ces callbacks sont portes par la state machine. Les clips DeepMotion servent au rendu visuel et doivent rester synchronises avec `impact_time`.
