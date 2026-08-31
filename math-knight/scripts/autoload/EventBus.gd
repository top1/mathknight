extends Node
## EventBus singleton — central signal dispatcher for all game systems.

# Problem & Input signals
signal problem_presented(problem: RefCounted)
signal answer_selected(value: int, method: String, bubble: Area2D, slice_dir: Vector2)
signal answer_correct(problem: RefCounted, chain_count: int)
signal answer_wrong(problem: RefCounted)
signal stroke_ended()

# Set / Wave & Countdown signals
signal set_started(set_number: int, bubble_pool: Array[int])
signal set_cleared(set_number: int)
signal countdown_tick(count_text: String)

# Combat/Enemy signals
signal enemy_defeated(enemy: Node2D)
signal enemy_reached_knight(enemy: Node2D)
signal enemy_attacks_knight(damage: float)

# Player/Knight signals
signal knight_damaged(current_hp: float, max_hp: float)
signal knight_died()
signal knight_attack_triggered(attack_type: String) # 'slash' or 'stab'

# Game state signals
signal score_changed(score: int)
signal combo_changed(count: int)
signal screen_shake_requested(trauma: float)
signal game_state_changed(new_state: String)
signal spawn_next_enemy()
signal stage_changed(current_stage: int, total_stages: int)
signal game_won(stats: Dictionary)

# === NEW: Roguelike Run signals ===

# Currency signals
signal gold_earned(amount: int, reason: String)
signal diamonds_earned(amount: int)
signal gold_changed(new_total: int)

# Chest & Loot signals
signal chest_collected(chest_data: Dictionary)
signal chest_opened(contents: Dictionary)

# Item & Artifact signals
signal artifact_acquired(artifact_id: String)
signal artifact_used(artifact_id: String)

# Cosmetic signals
signal cosmetic_unlocked(cosmetic_id: String)
signal cosmetic_equipped(cosmetic_id: String, slot: String)

# Knight RPG signals
signal knight_leveled_up(new_level: int)
signal knight_xp_gained(amount: int)
signal knight_stat_upgraded(stat_name: String, new_value: int)

# Boss signals
signal boss_spawned(boss_data: Dictionary)
signal boss_phase_changed(phase: int, total_phases: int)
signal boss_enraged()
signal boss_defeated(boss_data: Dictionary)

# Map signals
signal map_node_selected(node_data: Dictionary)
signal map_node_completed(node_data: Dictionary)
signal map_generated(map_data: Array)

# Run signals
signal run_started()
signal run_ended(stats: Dictionary)
signal run_node_entered(node_data: Dictionary)
signal run_node_exited(node_data: Dictionary)

# Flawless signals
signal flawless_set_achieved(set_number: int)
