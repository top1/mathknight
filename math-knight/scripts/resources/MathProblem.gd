class_name MathProblem
extends RefCounted

var operand_a: int = 0
var operand_b: int = 0
var operand_c: int = 0
var operator_symbol: String = "+"
var operator_symbol_2: String = ""
var is_three_operand: bool = false
var correct_answer: int = 0
var choices: Array[int] = []
var question_text: String = ""

## Curriculum metadata (L1..L6)
var curriculum_level: int = 0
var curriculum_subtype: int = 0
## Didactic feedback / explanation for training mode or visual aids
var hint_text: String = ""
## Auxiliary display (e.g. repeated addition "3 + 3 + 3 + 3" or inverse "3 × 4 = 12")
var display_note: String = ""

## In RESULT_TO_EQUATION mode: -1 = completely open, 0 = operand_a is pre-given, 1 = operand_b is pre-given
var given_operand_index: int = -1


func is_completely_open() -> bool:
	return given_operand_index == -1


func get_missing_operands() -> Array[int]:
	if is_three_operand:
		if given_operand_index == 0:
			var res: Array[int] = [operand_b, operand_c]
			return res
		elif given_operand_index == 1:
			var res: Array[int] = [operand_a, operand_c]
			return res
		elif given_operand_index == 2:
			var res: Array[int] = [operand_a, operand_b]
			return res
		else:
			var res: Array[int] = [operand_a, operand_b, operand_c]
			return res
	else:
		if given_operand_index == 0:
			var res: Array[int] = [operand_b]
			return res
		elif given_operand_index == 1:
			var res: Array[int] = [operand_a]
			return res
		else:
			var res: Array[int] = [operand_a, operand_b]
			return res


func get_formatted_equation() -> String:
	if is_three_operand:
		var a_str: String = str(operand_a) if given_operand_index == 0 else "?"
		var b_str: String = str(operand_b) if given_operand_index == 1 else "?"
		var c_str: String = str(operand_c) if given_operand_index == 2 else "?"
		return "%s %s %s %s %s = %d" % [a_str, operator_symbol, b_str, operator_symbol_2, c_str, correct_answer]
	else:
		var a_str: String = str(operand_a) if given_operand_index == 0 else "?"
		var b_str: String = str(operand_b) if given_operand_index == 1 else "?"
		return "%s %s %s = %d" % [a_str, operator_symbol, b_str, correct_answer]
