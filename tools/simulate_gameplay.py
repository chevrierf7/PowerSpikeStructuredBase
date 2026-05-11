import csv
import math
import random
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


COURT_LENGTH = 13.40
COURT_WIDTH = 6.10
SINGLES_WIDTH = 5.18
SHORT_SERVICE_DISTANCE = 1.98
DOUBLES_LONG_SERVICE_DISTANCE = 5.94
SIDE_MARGIN = 0.35
PLAYER_RUNOFF = 0.50
PLAYER_SPEED = 6.4
OPPONENT_SPEED = 3.85
AI_REACTION_PHASE = 0.28
HIT_REACH_FORWARD = 1.90
HIT_REACH_BACKWARD = 0.70
HIT_REACH_RACKET_SIDE = 1.35
HIT_REACH_BACKHAND_SIDE = 0.85
RECEPTION_MOVEMENT_GRACE = 0.20
RECOVERY_REACTION_PHASE = 0.18

DIFFICULTIES = {
    "loisir": {"label": "Loisir", "reach_bias": -0.35, "net_fault": 0.120, "out_error": 0.160, "service_fault": 0.115, "service_net_share": 0.62, "service_out_share": 0.30, "late_penalty": 0.35, "smash_bias": 0.10},
    "club": {"label": "Club", "reach_bias": -0.18, "net_fault": 0.075, "out_error": 0.110, "service_fault": 0.055, "service_net_share": 0.52, "service_out_share": 0.43, "late_penalty": 0.24, "smash_bias": 0.06},
    "elite": {"label": "Elite", "reach_bias": -0.02, "net_fault": 0.045, "out_error": 0.060, "service_fault": 0.020, "service_net_share": 0.40, "service_out_share": 0.58, "late_penalty": 0.14, "smash_bias": 0.01},
}


SHOT_PROFILES = {
    "drive": {"duration": 0.72},
    "drop": {"duration": 1.0},
    "smash": {"duration": 0.56},
    "serve_short": {"duration": 0.86},
    "serve_drive": {"duration": 0.84},
    "serve_lob": {"duration": 2.0},
    "lob": {"duration": 1.65},
}


@dataclass
class RallyResult:
    winner: str
    reason: str
    hits: int
    service_fault: bool
    service_fault_type: str = ""


@dataclass
class HitRecord:
    rally: int
    hit: int
    hitter: str
    kind: str
    animation: str
    target_x: float
    target_z: float
    receiver: str
    receiver_x: float
    receiver_z: float
    distance_to_center: float
    distance_to_sideline: float
    distance_to_backline: float


@dataclass
class RecoveryRecord:
    rally: int
    hit: int
    hitter: str
    kind: str
    start_x: float
    start_z: float
    target_x: float
    target_z: float
    end_x: float
    end_z: float
    moved: float
    remaining: float


def active_half_width(mode: str) -> float:
    return (COURT_WIDTH if mode == "doubles" else SINGLES_WIDTH) * 0.5


def service_long_limit(mode: str) -> float:
    return DOUBLES_LONG_SERVICE_DISTANCE if mode == "doubles" else COURT_LENGTH * 0.5


def service_server_lane(score: int, mode: str) -> float:
    lane_sign = 1.0 if score % 2 == 0 else -1.0
    return lane_sign * min(0.62, active_half_width(mode) * 0.30)


def service_receiver_lane(score: int, mode: str) -> float:
    return -service_server_lane(score, mode)


def pre_serve_position(side: str, server: str, player_score: int, opponent_score: int, mode: str) -> list[float]:
    score = player_score if server == "player" else opponent_score
    lane = service_server_lane(score, mode) if side == server else service_receiver_lane(score, mode)
    side_sign = -1.0 if side == "player" else 1.0
    distance = SHORT_SERVICE_DISTANCE + (0.72 if side == server else 0.38)
    return [side_sign * distance, lane]


def service_target(server: str, kind: str, score: int, mode: str) -> tuple[float, float]:
    attacking_positive = server == "player"
    long_limit = service_long_limit(mode)
    distance = long_limit - 0.72
    if kind == "serve_short":
        distance = SHORT_SERVICE_DISTANCE + 0.22
    elif kind == "serve_drive":
        distance = long_limit - 1.40
    lane = clamp(service_receiver_lane(score, mode) + random.uniform(-0.14, 0.14), -active_half_width(mode) + 0.55, active_half_width(mode) - 0.55)
    return (distance if attacking_positive else -distance, lane)


def shot_target(hitter: str, kind: str, hitter_z: float, mode: str) -> tuple[float, float]:
    attacking_positive = hitter == "player"
    lane = sample_impact_lane(hitter_z, hitter, kind, mode)
    x = sample_impact_depth(hitter, kind)
    if kind == "drop":
        x = sample_short_depth(attacking_positive, hitter)
    elif kind == "smash":
        x = sample_smash_depth(attacking_positive, hitter)
    x = clamp_depth_inside(x, attacking_positive, 0.38)
    lane = clamp_lane_inside(lane, mode, 0.32)
    return x, lane


def net_fault_chance(kind: str, difficulty: dict) -> float:
    base = difficulty["net_fault"]
    if kind == "smash":
        return base * 1.25
    if kind in ("drive", "serve_drive"):
        return base * 1.15
    if kind == "drop":
        return base
    if kind == "serve_short":
        return base * 0.65
    return base * 0.25


def sample_impact_lane(source_lane: float, hitter: str, kind: str, mode: str) -> float:
    half_width = active_half_width(mode)
    roll = random.random()
    lane = source_lane
    if roll < 0.22:
        side_sign = 1.0 if random.random() < 0.5 else -1.0
        lane = side_sign * random.uniform(half_width - 0.70, half_width - 0.28)
    elif roll < 0.42:
        lane = random.uniform(-0.55, 0.55)
    else:
        spread = 1.15 if hitter == "player" else 0.85
        lane += random.uniform(-spread, spread)
    if kind == "smash":
        lane += random.uniform(-0.45, 0.45)
    return clamp_lane_inside(lane, mode, 0.28)


def sample_impact_depth(hitter: str, kind: str) -> float:
    attacking_positive = hitter == "player"
    roll = random.random()
    if roll < 0.22:
        depth = random.uniform(COURT_LENGTH * 0.5 - 1.25, COURT_LENGTH * 0.5 - 0.38)
    elif roll < 0.42:
        depth = random.uniform(SIDE_MARGIN + 0.55, 2.45)
    else:
        depth = random.uniform(3.0, COURT_LENGTH * 0.5 - 1.15)
    return depth if attacking_positive else -depth


def sample_short_depth(attacking_positive: bool, hitter: str) -> float:
    easy_for_player = hitter == "opponent"
    near_net_max = 2.35 if easy_for_player else 1.75
    depth = random.uniform(SIDE_MARGIN + 0.55, near_net_max)
    return depth if attacking_positive else -depth


def sample_smash_depth(attacking_positive: bool, hitter: str) -> float:
    easy_for_player = hitter == "opponent"
    depth = random.uniform(2.15, 3.35 if easy_for_player else 4.05)
    return depth if attacking_positive else -depth


def clamp_lane_inside(lane: float, mode: str, margin: float) -> float:
    return clamp(lane, -active_half_width(mode) + margin, active_half_width(mode) - margin)


def clamp_depth_inside(x: float, attacking_positive: bool, margin: float) -> float:
    if attacking_positive:
        return clamp(x, SIDE_MARGIN + margin, COURT_LENGTH * 0.5 - margin)
    return clamp(x, -COURT_LENGTH * 0.5 + margin, -SIDE_MARGIN - margin)


def can_reach(character: str, character_pos: tuple[float, float], landing: tuple[float, float], speed: float, duration: float, difficulty: dict) -> bool:
	reaction_time = duration * AI_REACTION_PHASE
	travel_time = max(duration - reaction_time, 0.05)
	available_distance = speed * travel_time + RECEPTION_MOVEMENT_GRACE + difficulty["reach_bias"] - late_or_stretched_penalty(character_pos, landing, duration, difficulty)
	court_forward_x = 1.0 if character == "player" else -1.0
	racket_side_z = 1.0 if character == "player" else -1.0
	min_x = landing[0] - HIT_REACH_FORWARD * court_forward_x
	max_x = landing[0] + HIT_REACH_BACKWARD * court_forward_x
	min_z = landing[1] - HIT_REACH_RACKET_SIDE * racket_side_z
	max_z = landing[1] + HIT_REACH_BACKHAND_SIDE * racket_side_z
	closest_x = clamp(character_pos[0], min(min_x, max_x), max(min_x, max_x))
	closest_z = clamp(character_pos[1], min(min_z, max_z), max(min_z, max_z))
	return distance(character_pos, (closest_x, closest_z)) <= available_distance


def late_or_stretched_penalty(character_pos: tuple[float, float], landing: tuple[float, float], duration: float, difficulty: dict) -> float:
    penalty = 0.0
    if duration < 0.75:
        penalty += difficulty["late_penalty"]
    if distance(character_pos, landing) > 3.2:
        penalty += difficulty["late_penalty"]
    return penalty


def animation_for(hitter: str, kind: str, hitter_z: float, shuttle_z: float) -> str:
    if kind == "serve_short":
        return "serve_short"
    if kind == "serve_drive":
        return "forehand_drive"
    if kind == "serve_lob":
        return "serve_long"
    racket_side_z = 1.0 if hitter == "player" else -1.0
    backhand = (shuttle_z - hitter_z) * racket_side_z < -0.12
    if backhand:
        if kind == "drop":
            return "backhand_high_drop"
        if kind == "drive":
            return "backhand_drive"
        return "backhand_high_clear"
    if kind == "drop":
        return "forehand_high_drop"
    if kind == "smash":
        return "forehand_high_smash"
    if kind == "drive":
        return "forehand_drive"
    return "forehand_high_clear"


def impact_record(rally_id: int, hit: int, hitter: str, kind: str, animation: str, target: tuple[float, float], receiver: str, receiver_pos: list[float], mode: str) -> HitRecord:
    half_width = active_half_width(mode)
    receiver_backline = -COURT_LENGTH * 0.5 if receiver == "player" else COURT_LENGTH * 0.5
    return HitRecord(
        rally=rally_id,
        hit=hit,
        hitter=hitter,
        kind=kind,
        animation=animation,
        target_x=target[0],
        target_z=target[1],
        receiver=receiver,
        receiver_x=receiver_pos[0],
        receiver_z=receiver_pos[1],
        distance_to_center=abs(target[z_index()]),
        distance_to_sideline=half_width - abs(target[1]),
        distance_to_backline=abs(receiver_backline - target[0]),
    )


def z_index() -> int:
    return 1


def simulate_rally(rally_id: int = 0, mode: str = "singles", server: str = "player", player_score: int = 0, opponent_score: int = 0, max_hits: int = 32, records: list[HitRecord] | None = None, recoveries: list[RecoveryRecord] | None = None, difficulty: dict | None = None) -> RallyResult:
    if difficulty is None:
        difficulty = DIFFICULTIES["club"]
    player_pos = pre_serve_position("player", server, player_score, opponent_score, mode)
    opponent_pos = pre_serve_position("opponent", server, player_score, opponent_score, mode)
    side = server
    hits = 0
    receiver_aggressiveness = receiver_aggressiveness_for(server, player_pos, opponent_pos, mode)
    service_kind = choose_service_kind(receiver_aggressiveness)
    target = service_target(server, service_kind, player_score if server == "player" else opponent_score, mode)

    receiver = "opponent" if server == "player" else "player"
    service_fault_type = service_fault_type_for(difficulty)
    if service_fault_type:
        return RallyResult(receiver, "service_fault_" + service_fault_type, 1, True, service_fault_type)
    server_pos = player_pos if server == "player" else opponent_pos
    receiver_pos = opponent_pos if receiver == "opponent" else player_pos
    if records is not None:
        records.append(impact_record(rally_id, 1, server, service_kind, animation_for(server, service_kind, server_pos[1], target[1]), target, receiver, receiver_pos, mode))
    duration = SHOT_PROFILES[service_kind]["duration"]
    if not receiver_can_get(receiver, target, duration, player_pos, opponent_pos, difficulty):
        return RallyResult(server, "service_winner", 1, False)
    move_hitter_recovery(server, service_kind, target, duration, player_pos, opponent_pos, mode, rally_id, 1, recoveries)

    side = receiver
    hits = 1
    last_kind = service_kind
    while hits < max_hits:
        hitter_pos = player_pos if side == "player" else opponent_pos
        kind = choose_service_return(last_kind, receiver_aggressiveness) if hits == 1 else choose_rally_shot(difficulty)
        target = shot_target(side, kind, hitter_pos[1], mode)
        if random.random() < difficulty["out_error"] and not kind.startswith("serve"):
            target = miss_target_out(target, mode)
        duration = SHOT_PROFILES[kind]["duration"]
        receiver = "opponent" if side == "player" else "player"
        receiver_pos = opponent_pos if receiver == "opponent" else player_pos
        if records is not None:
            records.append(impact_record(rally_id, hits + 1, side, kind, animation_for(side, kind, hitter_pos[1], target[1]), target, receiver, receiver_pos, mode))
        if random.random() < net_fault_chance(kind, difficulty):
            return RallyResult(receiver, "net_fault", hits + 1, False)
        if not receiver_can_get(receiver, target, duration, player_pos, opponent_pos, difficulty):
            return RallyResult(side, "winner_or_late_receiver", hits + 1, False)
        move_hitter_recovery(side, kind, target, duration, player_pos, opponent_pos, mode, rally_id, hits + 1, recoveries)
        move_receiver(receiver, target, player_pos, opponent_pos)
        side = receiver
        last_kind = kind
        hits += 1
    return RallyResult("none", "max_hits", hits, False)


def service_fault_type_for(difficulty: dict) -> str:
    if random.random() > difficulty["service_fault"]:
        return ""
    roll = random.random()
    if roll < difficulty["service_net_share"]:
        return "net"
    if roll < difficulty["service_net_share"] + difficulty["service_out_share"]:
        return "out"
    return "technique"


def receiver_aggressiveness_for(server: str, player_pos: list[float], opponent_pos: list[float], mode: str) -> float:
    if server == "opponent":
        distance_from_net = abs(player_pos[0])
        neutral_line = SHORT_SERVICE_DISTANCE + 0.38
        return clamp(0.62 - (distance_from_net - neutral_line) * 0.38, 0.0, 1.0)
    return random.uniform(0.46, 0.74)


def choose_service_kind(receiver_aggressiveness: float) -> str:
    if receiver_aggressiveness > 0.75 and random.random() < 0.62:
        return "serve_drive"
    if receiver_aggressiveness < 0.35 and random.random() < 0.70:
        return "serve_short"
    roll = random.random()
    if roll < 0.55:
        return "serve_short"
    if roll < 0.85:
        return "serve_lob"
    return "serve_drive"


def choose_service_return(service_kind: str, receiver_aggressiveness: float) -> str:
    reaction_time = random.uniform(0.24, 0.58)
    if service_kind == "serve_short":
        roll = random.random()
        if receiver_aggressiveness > 0.68:
            return "drop" if roll < 0.52 else ("drive" if roll < 0.86 else "lob")
        return "drop" if roll < 0.36 else ("drive" if roll < 0.60 else "lob")
    if service_kind == "serve_lob":
        roll = random.random()
        return "lob" if roll < 0.40 else ("drop" if roll < 0.70 else "smash")
    if reaction_time > 0.45 or receiver_aggressiveness > 0.74:
        return "lob" if random.random() < 0.70 else "drop"
    roll = random.random()
    return "lob" if roll < 0.35 else ("smash" if roll < 0.70 else "drop")


def choose_rally_shot(difficulty: dict) -> str:
    roll = random.random()
    smash_bias = difficulty["smash_bias"]
    if roll < 0.46 - smash_bias:
        return "lob"
    if roll < 0.78 - smash_bias * 0.5:
        return "drop"
    return "smash"


def miss_target_out(target: tuple[float, float], mode: str) -> tuple[float, float]:
    if random.random() < 0.55:
        side = 1.0 if target[1] >= 0.0 else -1.0
        return target[0], side * (active_half_width(mode) + random.uniform(0.16, 0.55))
    depth = 1.0 if target[0] >= 0.0 else -1.0
    return depth * (COURT_LENGTH * 0.5 + random.uniform(0.12, 0.45)), target[1]


def receiver_can_get(receiver: str, target: tuple[float, float], duration: float, player_pos: list[float], opponent_pos: list[float], difficulty: dict) -> bool:
	if receiver == "player":
		return can_reach(receiver, tuple(player_pos), target, PLAYER_SPEED, duration, difficulty)
	return can_reach(receiver, tuple(opponent_pos), target, OPPONENT_SPEED, duration, difficulty)


def move_receiver(receiver: str, target: tuple[float, float], player_pos: list[float], opponent_pos: list[float]) -> None:
    if receiver == "player":
        player_pos[0] = target[0]
        player_pos[1] = target[1]
    else:
        opponent_pos[0] = target[0]
        opponent_pos[1] = target[1]


def move_hitter_recovery(hitter: str, kind: str, target: tuple[float, float], duration: float, player_pos: list[float], opponent_pos: list[float], mode: str, rally_id: int, hit: int, recoveries: list[RecoveryRecord] | None) -> None:
    position = player_pos if hitter == "player" else opponent_pos
    speed = PLAYER_SPEED if hitter == "player" else OPPONENT_SPEED
    start = (position[0], position[1])
    recovery = recovery_position(hitter, kind, tuple(position), target, mode)
    available_time = max(duration * (1.0 - RECOVERY_REACTION_PHASE), 0.05)
    max_step = speed * available_time * 0.42
    dx = recovery[0] - position[0]
    dz = recovery[1] - position[1]
    length = math.hypot(dx, dz)
    if length <= max_step or length <= 0.001:
        position[0], position[1] = recovery
        moved = distance(start, recovery)
        remaining = 0.0
        if recoveries is not None:
            recoveries.append(recovery_record(rally_id, hit, hitter, kind, start, recovery, tuple(position), moved, remaining))
        return
    position[0] += dx / length * max_step
    position[1] += dz / length * max_step
    end = (position[0], position[1])
    if recoveries is not None:
        recoveries.append(recovery_record(rally_id, hit, hitter, kind, start, recovery, end, distance(start, end), distance(end, recovery)))


def recovery_record(rally_id: int, hit: int, hitter: str, kind: str, start: tuple[float, float], target: tuple[float, float], end: tuple[float, float], moved: float, remaining: float) -> RecoveryRecord:
    return RecoveryRecord(
        rally=rally_id,
        hit=hit,
        hitter=hitter,
        kind=kind,
        start_x=start[0],
        start_z=start[1],
        target_x=target[0],
        target_z=target[1],
        end_x=end[0],
        end_z=end[1],
        moved=moved,
        remaining=remaining,
    )


def recovery_position(hitter: str, kind: str, position: tuple[float, float], target: tuple[float, float], mode: str) -> tuple[float, float]:
    side_sign = -1.0 if hitter == "player" else 1.0
    quality = estimate_shot_quality(kind, target, mode)
    pressure = pressure_state(kind, quality, target)
    x = side_sign * 3.75
    family = recovery_family(kind)
    if family == "clear":
        x += side_sign * 0.35
    elif family == "smash":
        x -= side_sign * 0.35
    elif family in ("drop", "net"):
        x -= side_sign * 0.55
    elif family == "lob":
        x += side_sign * 0.70
    elif family == "drive":
        x -= side_sign * 0.05
    if quality < 0.40:
        x += side_sign * 0.45
    elif quality > 0.76 and pressure == "attack":
        x -= side_sign * 0.15
    if pressure == "defense":
        x += side_sign * 0.35
    elif pressure == "attack":
        x -= side_sign * 0.20
    z = recovery_lane_offset(position, target)
    z += random.uniform(-0.16, 0.16)
    x += side_sign * random.uniform(-0.10, 0.10)
    x_low = SIDE_MARGIN + 0.35
    x_high = COURT_LENGTH * 0.5 + PLAYER_RUNOFF
    if hitter == "player":
        x = clamp(x, -x_high, -x_low)
    else:
        x = clamp(x, x_low, x_high)
    z = clamp(z, -active_half_width(mode) - PLAYER_RUNOFF + 0.35, active_half_width(mode) + PLAYER_RUNOFF - 0.35)
    return x, z


def recovery_family(kind: str) -> str:
    if kind == "drop":
        return "drop"
    if kind == "smash":
        return "smash"
    if kind == "serve_short":
        return "net"
    if kind in ("serve_drive", "drive"):
        return "drive"
    if kind == "lob":
        return "clear"
    return "clear"


def estimate_shot_quality(kind: str, target: tuple[float, float], mode: str) -> float:
    half_width = active_half_width(mode)
    sideline_pressure = clamp(abs(target[1]) / max(half_width, 0.01), 0.0, 1.0)
    depth_pressure = clamp((abs(target[0]) - 2.0) / (COURT_LENGTH * 0.5 - 2.0), 0.0, 1.0)
    family = recovery_family(kind)
    quality = 0.55
    if family == "clear":
        quality = lerp(0.42, 0.88, depth_pressure)
    elif family == "smash":
        quality = lerp(0.48, 0.86, sideline_pressure)
    elif family in ("drop", "net"):
        net_pressure = 1.0 - clamp((abs(target[0]) - SIDE_MARGIN) / 2.4, 0.0, 1.0)
        quality = lerp(0.40, 0.86, max(net_pressure, sideline_pressure * 0.75))
    elif family == "drive":
        quality = lerp(0.45, 0.78, sideline_pressure)
    return clamp(quality + random.uniform(-0.12, 0.10), 0.0, 1.0)


def pressure_state(kind: str, quality: float, target: tuple[float, float]) -> str:
    family = recovery_family(kind)
    if quality < 0.38:
        return "defense"
    if family in ("smash", "drop", "net") and quality > 0.58:
        return "attack"
    if family == "clear" and abs(target[0]) < COURT_LENGTH * 0.5 - 1.0:
        return "defense"
    return "neutral"


def recovery_lane_offset(position: tuple[float, float], target: tuple[float, float]) -> float:
    target_side = sign(target[1])
    current_side = sign(position[1])
    offset = clamp(target[1] * 0.22, -0.58, 0.58)
    if abs(target[1] - position[1]) > 1.20 and target_side != 0.0 and target_side != current_side:
        offset += target_side * 0.34
    elif abs(target[1]) > 1.10:
        offset += target_side * 0.18
    return clamp(offset, -0.85, 0.85)


def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def sign(value: float) -> float:
    if value > 0.0:
        return 1.0
    if value < 0.0:
        return -1.0
    return 0.0


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def run(count: int, seed: int = 7, save_csv: bool = True, difficulty_name: str = "club") -> None:
    random.seed(seed)
    difficulty = DIFFICULTIES[difficulty_name]
    records: list[HitRecord] = []
    recoveries: list[RecoveryRecord] = []
    results = [simulate_rally(rally_id=i + 1, server="player" if i % 2 == 0 else "opponent", records=records, recoveries=recoveries, difficulty=difficulty) for i in range(count)]
    service_faults = sum(1 for result in results if result.service_fault)
    service_fault_types = Counter(result.service_fault_type for result in results if result.service_fault_type)
    max_hits = sum(1 for result in results if result.reason == "max_hits")
    avg_hits = sum(result.hits for result in results) / len(results)
    sorted_hits = sorted(result.hits for result in results)
    p50 = sorted_hits[len(sorted_hits) // 2]
    p90 = sorted_hits[int(len(sorted_hits) * 0.9)]
    short = sum(1 for result in results if result.hits <= 2)
    print(f"difficulty={difficulty['label']}")
    print(f"rallies={count}")
    print(f"service_faults={service_faults} ({service_faults / count:.1%})")
    if service_faults > 0:
        print("service_fault_types:")
        for name, amount in sorted(service_fault_types.items()):
            print(f"  {name}: {amount} ({amount / service_faults:.1%})")
    print(f"avg_hits={avg_hits:.2f}")
    print(f"median_hits={p50}")
    print(f"p90_hits={p90}")
    print(f"short_rallies_<=2_hits={short} ({short / count:.1%})")
    print(f"reached_max_hits={max_hits} ({max_hits / count:.1%})")
    print()
    animation_counts = Counter(record.animation for record in records)
    shot_counts = Counter(record.kind for record in records)
    print("animations_used:")
    for name, amount in sorted(animation_counts.items()):
        print(f"  {name}: {amount} ({amount / len(records):.1%})")
    print("shot_kinds:")
    for name, amount in sorted(shot_counts.items()):
        print(f"  {name}: {amount} ({amount / len(records):.1%})")
    sideline_distances = [record.distance_to_sideline for record in records]
    center_distances = [record.distance_to_center for record in records]
    backline_distances = [record.distance_to_backline for record in records]
    print()
    print(f"impacts={len(records)}")
    print(f"avg_abs_z_from_center={mean(center_distances):.2f}m")
    print(f"avg_distance_to_sideline={mean(sideline_distances):.2f}m")
    print(f"min_distance_to_sideline={min(sideline_distances):.2f}m")
    print(f"avg_distance_to_backline={mean(backline_distances):.2f}m")
    print(f"near_sideline_<0.50m={ratio(sideline_distances, lambda value: value < 0.50):.1%}")
    print(f"near_center_<0.50m={ratio(center_distances, lambda value: value < 0.50):.1%}")
    print(f"deep_<1.00m_from_backline={ratio(backline_distances, lambda value: value < 1.00):.1%}")
    opponent_recoveries = [record for record in recoveries if record.hitter == "opponent"]
    if opponent_recoveries:
        moved = [record.moved for record in opponent_recoveries]
        remaining = [record.remaining for record in opponent_recoveries]
        lateral = [abs(record.end_z - record.start_z) for record in opponent_recoveries]
        depth = [abs(record.end_x - record.start_x) for record in opponent_recoveries]
        print()
        print("opponent_recovery:")
        print(f"  count={len(opponent_recoveries)}")
        print(f"  avg_moved={mean(moved):.2f}m")
        print(f"  avg_depth_move={mean(depth):.2f}m")
        print(f"  avg_lateral_move={mean(lateral):.2f}m")
        print(f"  stayed_under_0.20m={ratio(moved, lambda value: value < 0.20):.1%}")
        print(f"  avg_remaining_to_base={mean(remaining):.2f}m")
    if save_csv:
        path = Path("tools") / "simulation_impacts.csv"
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(HitRecord.__dataclass_fields__.keys()))
            writer.writeheader()
            for record in records:
                writer.writerow(record.__dict__)
        print(f"impact_csv={path}")
        recovery_path = Path("tools") / "simulation_recovery.csv"
        with recovery_path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(RecoveryRecord.__dataclass_fields__.keys()))
            writer.writeheader()
            for record in recoveries:
                writer.writerow(record.__dict__)
        print(f"recovery_csv={recovery_path}")


def mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def ratio(values: list[float], predicate) -> float:
    return sum(1 for value in values if predicate(value)) / len(values) if values else 0.0


if __name__ == "__main__":
    for name in ["loisir", "club", "elite"]:
        run(1000, difficulty_name=name, save_csv=(name == "club"))
        print()
