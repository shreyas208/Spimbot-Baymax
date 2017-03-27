# syscall constants
PRINT_STRING = 4
PRINT_CHAR   = 11
PRINT_INT    = 1

# debug constants
PRINT_INT_ADDR   = 0xffff0080
PRINT_FLOAT_ADDR = 0xffff0084
PRINT_HEX_ADDR   = 0xffff0088

# spimbot constants
VELOCITY       = 0xffff0010
ANGLE          = 0xffff0014
ANGLE_CONTROL  = 0xffff0018
BOT_X          = 0xffff0020
BOT_Y          = 0xffff0024
OTHER_BOT_X    = 0xffff00a0
OTHER_BOT_Y    = 0xffff00a4
TIMER          = 0xffff001c
SCORES_REQUEST = 0xffff1018

TILE_SCAN       = 0xffff0024
SEED_TILE       = 0xffff0054
WATER_TILE      = 0xffff002c
MAX_GROWTH_TILE = 0xffff0030
HARVEST_TILE    = 0xffff0020
BURN_TILE       = 0xffff0058
GET_FIRE_LOC    = 0xffff0028
PUT_OUT_FIRE    = 0xffff0040

GET_NUM_WATER_DROPS   = 0xffff0044
GET_NUM_SEEDS         = 0xffff0048
GET_NUM_FIRE_STARTERS = 0xffff004c
SET_RESOURCE_TYPE     = 0xffff00dc
REQUEST_PUZZLE        = 0xffff00d0
SUBMIT_SOLUTION       = 0xffff00d4

# interrupt constants
BONK_MASK               = 0x1000
BONK_ACK                = 0xffff0060
TIMER_MASK              = 0x8000
TIMER_ACK               = 0xffff006c
ON_FIRE_MASK            = 0x400
ON_FIRE_ACK             = 0xffff0050
MAX_GROWTH_ACK          = 0xffff005c
MAX_GROWTH_INT_MASK     = 0x2000
REQUEST_PUZZLE_ACK      = 0xffff00d8
REQUEST_PUZZLE_INT_MASK = 0x800

.data
# data things go here
tile_array: .space 1600				# Plant tiles: 1,600 bytes

unsolved_puzzle1: .space 4096			# Puzzle: 4,096 bytes
solved_puzzle1: .space 328			# Solved puzzle: 328 bytes

#unsolved_puzzle2: .space 4096			# Puzzle: 4,096 bytes
#solved_puzzle2: .space 328			# Solved puzzle: 328 bytes

unsolved_puzzle3: .space 4096			# Puzzle: 4,096 bytes
solved_puzzle3: .space 328			# Solved puzzle: 328 bytes

unsolved_puzzle4: .space 4096			# Puzzle: 4,096 bytes
solved_puzzle4: .space 328			# Solved puzzle: 328 bytes

.text
main:
	# enable interrupts
	li	$s0, BONK_MASK				# bonk interrupt enable
	or	$s0, $s0, REQUEST_PUZZLE_INT_MASK	# request puzzle interrupt enable
	or	$s0, $s0, 1				# global interrupt enable
	mtc0	$s0, $12				# set interrupt mask (Status register)

	# request 4 puzzles immediately	- all water initially
    	sw  	$0, SET_RESOURCE_TYPE

    	la  	$s0, unsolved_puzzle1
    	sw  	$s0, REQUEST_PUZZLE

	# la  	$s0, unsolved_puzzle2
 	# sw  	$s0, REQUEST_PUZZLE

	la  	$s0, unsolved_puzzle3
	sw  	$s0, REQUEST_PUZZLE

	la  	$s0, unsolved_puzzle4
	sw  	$s0, REQUEST_PUZZLE

	li 	$s0, 10
	sw	$s0, VELOCITY

	li	$a0, 75
	li	$a1, 75

	li 	$t2, 1		# value for ANGLE_CONTROL

    	lw     	$t0, BOT_X      # t3 = bot x-pos
    	sub    	$t0, $a0, $t0   # t3 = dest x-pos - bot x-pos
    	li     	$t1, 0          # absolute angle = 0 (right)
    	bge    	$t0, $0, im_x_cont
    	li     	$t1, 180        # absolute angle = 180 (left)
im_x_cont:
    	sw     	$t1, ANGLE      # set ANGLE
    	sw     	$t2, ANGLE_CONTROL  # set ANGLE_CONTROL to absolute
im_x_check:
    	lw     	$t0, BOT_X      # t3 = bot x-pos
    	sub    	$t0, $a0, $t0   # t3 = fire x-pos - bot x-pos
    	beq    	$t0, $0, im_y # when x coords match, start y process
    	j      	im_x_check
im_y:
    	lw     	$t0, BOT_Y      # t3 = bot y-pos
    	sub    	$t0, $a1, $t0   # t3 = dest y-pos - bot y-pos
    	li     	$t1, 90          # absolute angle = 90 (up)
    	bge    	$t0, $0, im_y_cont
    	li     	$t1, 270        # absolute angle = 270 (down)
im_y_cont:
    	sw     	$t1, ANGLE      # set ANGLE
    	sw     	$t2, ANGLE_CONTROL  # set ANGLE_CONTROL to absolute
im_y_check:
	lw	$t0, BOT_Y
	sub 	$t0, $a1, $t0
	beq	$t0, $0, im_done
    	j      	im_y_check

im_done:
	li	$t0, 135
	sw	$t0, ANGLE
	sw	$t2, ANGLE_CONTROL

main_loop:
	# load spimbot location (0-300)
	lw	$s1, BOT_X		# s1 = BOT_X
	lw	$s2, BOT_Y		# s2 = BOT_Y

	div 	$s1, $s1, 30
	div 	$s2, $s2, 30		# 0 - 10

	mul	$s3, $s2, 10
	add	$s3, $s3, $s1
	sll	$s3, $s3, 4

	la	$s0, tile_array
	add	$s3, $s3, $s0		# s3 = tile struct address

	# refresh tile data
	la	$s0, tile_array
	sw	$s0, TILE_SCAN

	# struct TileInfo {
	#     // Either 0 for EMPTY, 1 for GROWING
	#     int state;
	#     // 0 for owned by current bot, 1 for owned by other bot
	#     int owning_bot;
	#     int growth;
	#     int water;
	# };

	# check tile owning_bot
	lw	$s4, 4($s3)
	li	$s5, 1
	beq	$s4, $s5, skip_tile

	# check tile state
	lw	$s4, 0($s3)				# t4 = state of current tile: 0 -> empty; 1 -> growing
	bne	$s4, $0, skip_planting 			# if current tile is empty, plant seed

	# plant - check if we have seeds
	lw	$s4, GET_NUM_SEEDS			# t0 = num seeds
	beq	$s4, $0, skip_planting			# if we don't have seeds, then skip to planting

	sw	$0, SEED_TILE				# plant a seed

skip_planting:
	# check growth
	lw	$s4, 8($s3)
	li	$s5, 128				# max is 512
	ble	$s4, $s5, skip_harvest			# not ready to harvest

	# harvest
	sw 	$0, HARVEST_TILE			# harvest!

skip_harvest:
	# check water level
	lw	$s4, 12($s3)				# current water level
	sub	$s4, $s4, 10
	beq	$s4, $0, skip_watering			# fully watered already
	sub	$s4, $0, $s4

	sw  	$s4, WATER_TILE

skip_watering:
	# solve any available puzzles
	jal 	solve_puzzle

skip_tile:
	j	main_loop

# -----------------------------------------------------------------------
# solve_puzzle - solves the puzzle stored at the address of unsolved_puzzle
# 		 and writes the solution to the address of solved_puzzle.
# 	       - solve puzzle also requests a new puzzle
# -----------------------------------------------------------------------
solve_puzzle:
	# save callee-saved registers
	sub	$sp, $sp, 12
	sw	$ra, 0($sp)
	sw 	$s0, 4($sp)
	sw 	$s1, 8($sp)

	##########  SOLVING PUZZLE 1  ##########
	la	$s0, solved_puzzle1
	la 	$s1, unsolved_puzzle1

	# if the fourth word in unsolved_puzzle is 0, assume all of it is
	# -> no puzzle is ready to solve yet
	lw	$t0, 16($s1)
	beq	$t0, $0, skip_puzzle_1

	# zero out the solution
	li	$t0, 0
solve_puzzle_loop_1:
	beq 	$t0, 328, solve_puzzle_cont0_1
	add 	$t1, $t0, $s0
	sw 	$0, 0($t1)
	add 	$t0, $t0, 4
	j 	solve_puzzle_loop_1

solve_puzzle_cont0_1:
	# solve puzzle
	move 	$a0, $s0
	move 	$a1, $s1
	jal	recursive_backtracking

	# submit solution
	sw	$s0, SUBMIT_SOLUTION

	# zero out 16 offset of unsolved puzzle to check against later
	sw 	$0, 16($s1)

	# request water
	sw  	$0, SET_RESOURCE_TYPE
	sw	$s1, REQUEST_PUZZLE

skip_puzzle_1:
# 	##########  SOLVING PUZZLE 2  ##########
# 	la	$s0, solved_puzzle2
# 	la 	$s1, unsolved_puzzle2
#
# 	# if the fourth word in unsolved_puzzle is 0, assume all of it is
# 	# -> no puzzle is ready to solve yet
# 	lw	$t0, 16($s1)
# 	beq	$t0, $0, skip_puzzle_2
#
# 	# zero out the solution
# 	li	$t0, 0
# solve_puzzle_loop_2:
# 	beq 	$t0, 328, solve_puzzle_cont0_2
# 	add 	$t1, $t0, $s0
# 	sw 	$0, 0($t1)
# 	add 	$t0, $t0, 4
# 	j 	solve_puzzle_loop_2
#
# solve_puzzle_cont0_2:
# 	# solve the puzzle
# 	move 	$a0, $s0
# 	move 	$a1, $s1
# 	jal	recursive_backtracking
#
# 	# submit solution
# 	sw	$s0, SUBMIT_SOLUTION
#
# 	# zero out 16 offset of unsolved puzzle to check against later
# 	sw 	$0, 16($s1)
#
# 	# request water
# 	sw  	$0, SET_RESOURCE_TYPE
# 	sw	$s1, REQUEST_PUZZLE
#
# skip_puzzle_2:
	##########  SOLVING PUZZLE 3  ##########
	la	$s0, solved_puzzle3
	la 	$s1, unsolved_puzzle3

	# if the fourth word in unsolved_puzzle is 0, assume all of it is
	# -> no puzzle is ready to solve yet
	lw	$t0, 16($s1)
	beq	$t0, $0, skip_puzzle_3

	# zero out the solution struct
	li	$t0, 0
solve_puzzle_loop_3:
	beq 	$t0, 328, solve_puzzle_cont0_3
	add 	$t1, $t0, $s0
	sw 	$0, 0($t1)
	add 	$t0, $t0, 4
	j 	solve_puzzle_loop_3

solve_puzzle_cont0_3:
	# solve puzzle
	move 	$a0, $s0
	move 	$a1, $s1
	jal	recursive_backtracking

	# submit solution
	sw	$s0, SUBMIT_SOLUTION

	# zero out 16 offset of unsolved puzzle to check against later
	sw 	$0, 16($s1)

	# request water
	sw  	$0, SET_RESOURCE_TYPE
	sw	$s1, REQUEST_PUZZLE

skip_puzzle_3:
	##########  SOLVING PUZZLE 4  ##########
	la	$s0, solved_puzzle4
	la 	$s1, unsolved_puzzle4

	# if the fourth word in unsolved_puzzle is 0, assume all of it is
	# -> no puzzle is ready to solve yet
	lw	$t0, 16($s1)
	beq	$t0, $0, skip_puzzle_4

	# zero out the solution struct
	li	$t0, 0
solve_puzzle_loop_4:
	beq 	$t0, 328, solve_puzzle_cont0_4
	add 	$t1, $t0, $s0
	sw 	$0, 0($t1)
	add 	$t0, $t0, 4
	j 	solve_puzzle_loop_4

solve_puzzle_cont0_4:
	# solve puzzle
	move 	$a0, $s0
	move 	$a1, $s1
	jal	recursive_backtracking

	# submit solution
	sw	$s0, SUBMIT_SOLUTION

	# zero out 16 offset of unsolved puzzle to check against later
	sw 	$0, 16($s1)

	# request seeds
	li	$t1, 1
	sw  	$t1, SET_RESOURCE_TYPE
	sw	$s1, REQUEST_PUZZLE

skip_puzzle_4:
	# restore callee-saved registers
	lw	$ra, 0($sp)
	lw 	$s0, 4($sp)
	lw 	$s1, 8($sp)
	add	$sp, $sp, 12

	jr	$ra


# -----------------------------------------------------------------------
# solve_puzzle functions all in-lined
# -----------------------------------------------------------------------
recursive_backtracking:
sub   $sp, $sp, 680
sw    $ra, 0($sp)
sw    $a0, 4($sp)     # solution
sw    $a1, 8($sp)     # puzzle
sw    $s0, 12($sp)    # position
sw    $s1, 16($sp)    # val
sw    $s2, 20($sp)    # 0x1 << (val - 1)
# sizeof(Puzzle) = 8
# sizeof(Cell [81]) = 648
lw    $t0, 0($a0)       # solution->size
lw    $t1, 0($a1)       # puzzle->size
mul   $t1, $t1, $t1     # puzzle->size * puzzle->size
move  $v0, $0
seq   $v0, $t0, $t1
bne   $v0, $0, recursive_backtracking_return_one
lw    $a0, 4($sp)     # solution
lw    $a1, 8($sp)     # puzzle
li    $v0, 0            # unassigned_pos = 0
lw    $t0, 0($a1)       # puzzle->size
mul  $t0, $t0, $t0     # puzzle->size * puzzle->size
add   $t1, $a0, 4       # &solution->assignment[0]
get_unassigned_position_for_begin:
bge   $v0, $t0, get_unassigned_position_return  # if (unassigned_pos < puzzle->size * puzzle->size)
mul  $t2, $v0, 4
add   $t2, $t1, $t2     # &solution->assignment[unassigned_pos]
lw    $t2, 0($t2)       # solution->assignment[unassigned_pos]
beq   $t2, 0, get_unassigned_position_return  # if (solution->assignment[unassigned_pos] == 0)
add   $v0, $v0, 1       # unassigned_pos++
j   get_unassigned_position_for_begin
get_unassigned_position_return:
move  $s0, $v0        # position
li    $s1, 1          # val = 1
recursive_backtracking_for_loop:
lw    $a0, 4($sp)     # solution
lw    $a1, 8($sp)     # puzzle
lw    $t0, 0($a1)     # puzzle->size
add   $t1, $t0, 1     # puzzle->size + 1
bge   $s1, $t1, recursive_backtracking_return_zero  # val < puzzle->size + 1
lw    $t1, 4($a1)     # puzzle->grid
mul   $t4, $s0, 8     # sizeof(Cell) = 8
add   $t1, $t1, $t4   # &puzzle->grid[position]
lw    $t1, 0($t1)     # puzzle->grid[position].domain
sub   $t4, $s1, 1     # val - 1
li    $t5, 1
sll   $s2, $t5, $t4   # 0x1 << (val - 1)
and   $t1, $t1, $s2   # puzzle->grid[position].domain & (0x1 << (val - 1))
beq   $t1, $0, recursive_backtracking_for_loop_continue # if (domain & (0x1 << (val - 1)))
mul   $t0, $s0, 4     # position * 4
add   $t0, $t0, $a0
add   $t0, $t0, 4     # &solution->assignment[position]
sw    $s1, 0($t0)     # solution->assignment[position] = val
lw    $t0, 0($a0)     # solution->size
add   $t0, $t0, 1
sw    $t0, 0($a0)     # solution->size++
add   $t0, $sp, 32    # &grid_copy
sw    $t0, 28($sp)    # puzzle_copy.grid = grid_copy !!!
move  $a0, $a1        # &puzzle
add   $a1, $sp, 24    # &puzzle_copy
lw  $t0, 0($a0)
sw  $t0, 0($a1)
mul $t0, $t0, $t0
mul $t0, $t0, 2 # two words in one grid
lw  $t1, 4($a0) # &puzzle(ori).grid
lw  $t2, 4($a1) # &puzzle(clone).grid
li  $t3, 0 # i = 0;
clone_for_loop:
bge  $t3, $t0, clone_for_loop_end
sll $t4, $t3, 2 # i * 4
add $t5, $t1, $t4 # puzzle(ori).grid ith word
lw   $t6, 0($t5)
add $t5, $t2, $t4 # puzzle(clone).grid ith word
sw   $t6, 0($t5)
addi $t3, $t3, 1 # i++
j    clone_for_loop
clone_for_loop_end:
mul   $t0, $s0, 8     # !!! grid size 8
lw    $t1, 28($sp)
add   $t1, $t1, $t0   # &puzzle_copy.grid[position]
sw    $s2, 0($t1)     # puzzle_copy.grid[position].domain = 0x1 << (val - 1);
move  $a0, $s0
add   $a1, $sp, 24
sub   $sp, $sp, 24
sw    $ra, 0($sp)
sw    $a0, 4($sp)
sw    $a1, 8($sp)
sw    $s0, 12($sp)
sw    $s1, 16($sp)
sw    $s2, 20($sp)
lw    $t0, 0($a1)     # size
li    $t1, 0          # col = 0
fc_for_col:
bge   $t1, $t0, fc_end_for_col  # col < size
div   $a0, $t0
mfhi  $t2             # position % size
mflo  $t3             # position / size
beq   $t1, $t2, fc_for_col_continue    # if (col != position % size)
mul   $t4, $t3, $t0
add   $t4, $t4, $t1   # position / size * size + col
mul   $t4, $t4, 8
lw    $t5, 4($a1) # puzzle->grid
add   $t4, $t4, $t5   # &puzzle->grid[position / size * size + col].domain
mul   $t2, $a0, 8   # position * 8
add   $t2, $t5, $t2 # puzzle->grid[position]
lw    $t2, 0($t2) # puzzle -> grid[position].domain
not   $t2, $t2        # ~puzzle->grid[position].domain
lw    $t3, 0($t4) #
and   $t3, $t3, $t2
sw    $t3, 0($t4)
beq   $t3, $0, fc_return_zero # if (!puzzle->grid[position / size * size + col].domain)
fc_for_col_continue:
add   $t1, $t1, 1     # col++
j     fc_for_col
fc_end_for_col:
li    $t1, 0          # row = 0
fc_for_row:
bge   $t1, $t0, fc_end_for_row  # row < size
div   $a0, $t0
mflo  $t2             # position / size
mfhi  $t3             # position % size
beq   $t1, $t2, fc_for_row_continue
lw    $t2, 4($a1)     # puzzle->grid
mul   $t4, $t1, $t0
add   $t4, $t4, $t3
mul   $t4, $t4, 8
add   $t4, $t2, $t4   # &puzzle->grid[row * size + position % size]
lw    $t6, 0($t4)
mul   $t5, $a0, 8
add   $t5, $t2, $t5
lw    $t5, 0($t5)     # puzzle->grid[position].domain
not   $t5, $t5
and   $t5, $t6, $t5
sw    $t5, 0($t4)
beq   $t5, $0, fc_return_zero
fc_for_row_continue:
add   $t1, $t1, 1     # row++
j     fc_for_row
fc_end_for_row:
li    $s0, 0          # i = 0
fc_for_i:
lw    $t2, 4($a1)
mul   $t3, $a0, 8
add   $t2, $t2, $t3
lw    $t2, 4($t2)     # &puzzle->grid[position].cage
lw    $t3, 8($t2)     # puzzle->grid[position].cage->num_cell
bge   $s0, $t3, fc_return_one
lw    $t3, 12($t2)    # puzzle->grid[position].cage->positions
mul   $s1, $s0, 4
add   $t3, $t3, $s1
lw    $t3, 0($t3)     # pos
lw    $s1, 4($a1)
mul   $s2, $t3, 8
add   $s2, $s1, $s2   # &puzzle->grid[pos].domain
lw    $s1, 0($s2)
move  $a0, $t3
sub $sp, $sp, 36
sw $ra, 0($sp)
sw $s0, 4($sp)
sw $s1, 8($sp)
sw $s2, 12($sp)
sw $s3, 16($sp)
sw $s4, 20($sp)
sw $s5, 24($sp)
sw $s6, 28($sp)
sw $s7, 32($sp)
li $t0, 0 # valid_domain
lw $t1, 4($a1) # puzzle->grid (t1 free)
sll $t2, $a0, 3 # position*8 (actual offset) (t2 free)
add $t3, $t1, $t2 # &puzzle->grid[position]
lw  $t4, 4($t3) # &puzzle->grid[position].cage
lw  $t5, 0($t4) # puzzle->grid[posiition].cage->operation
lw $t2, 4($t4) # puzzle->grid[position].cage->target
move $s0, $t2   # remain_target = $s0  *!*!
lw $s1, 8($t4) # remain_cell = $s1 = puzzle->grid[position].cage->num_cell
lw $s2, 0($t3) # domain_union = $s2 = puzzle->grid[position].domain
move $s3, $t4 # puzzle->grid[position].cage
li $s4, 0   # i = 0
move $s5, $t1 # $s5 = puzzle->grid
move $s6, $a0 # $s6 = position
# move $s7, $s2 # $s7 = puzzle->grid[position].domain
bne $t5, 0, gdfc_check_else_if
li $t1, 1
sub $t2, $t2, $t1 # (puzzle->grid[position].cage->target-1)
sll $v0, $t1, $t2 # valid_domain = 0x1 << (prev line comment)
j gdfc_end # somewhere!!!!!!!!
gdfc_check_else_if:
bne $t5, '+', gdfc_check_else
gdfc_else_if_loop:
lw $t5, 8($s3) # puzzle->grid[position].cage->num_cell
bge $s4, $t5, gdfc_for_end # branch if i >= puzzle->grid[position].cage->num_cell
sll $t1, $s4, 2 # i*4
lw $t6, 12($s3) # puzzle->grid[position].cage->positions
add $t1, $t6, $t1 # &puzzle->grid[position].cage->positions[i]
lw $t1, 0($t1) # pos = puzzle->grid[position].cage->positions[i]
add $s4, $s4, 1 # i++
sll $t2, $t1, 3 # pos * 8
add $s7, $s5, $t2 # &puzzle->grid[pos]
lw  $s7, 0($s7) # puzzle->grid[pos].domain
beq $t1, $s6 gdfc_else_if_else # branch if pos == position
move $a0, $s7 # $a0 = puzzle->grid[pos].domain
beq    $a0, $0, isvd_zero     # return 0 if domain == 0
sub    $t0, $a0, 1            # (domain - 1)
and    $t0, $t0, $a0          # (domain & (domain - 1))
bne    $t0, $0, isvd_zero     # return 0 if (domain & (domain - 1)) != 0
li     $v0, 1
j 	isvd_done
isvd_zero:
li     $v0, 0
isvd_done:
bne $v0, 1 gdfc_else_if_else # branch if !is_single_value_domain()
move $a0, $s7
move  $v0, $0             # result = 0
chbti_loop:
beq   $a0, $0, chbti_end
add   $v0, $v0, 1         # result ++
sra   $a0, $a0, 1         # domain >>= 1
j     chbti_loop
chbti_end:
sub $s0, $s0, $v0 # remain_target -= convert_highest_bit_to_int
addi $s1, $s1, -1 # remain_cell -= 1
j gdfc_else_if_loop
gdfc_else_if_else:
or $s2, $s2, $s7 # domain_union |= puzzle->grid[pos].domain
j gdfc_else_if_loop
gdfc_for_end:
move $a0, $s0
move $a1, $s1
move $a2, $s2
sub    $sp, $sp, 20
sw     $ra, 0($sp)
sw     $s0, 4($sp)
sw     $s1, 8($sp)
sw     $s2, 12($sp)
sw     $s3, 16($sp)
move   $s0, $a0                     # s0 = target
move   $s1, $a1                     # s1 = num_cell
move   $s2, $a2                     # s2 = domain
move   $a0, $a2
move  $v0, $0             # result = 0
chbti_loop_2:
beq   $a0, $0, chbti_end_2
add   $v0, $v0, 1         # result ++
sra   $a0, $a0, 1         # domain >>= 1
j     chbti_loop_2
chbti_end_2:
move   $s3, $v0                     # s3 = upper_bound
sub    $a0, $0, $s2                 # -domain
and    $a0, $a0, $s2                # domain & (-domain)
move  $v0, $0             # result = 0
chbti_loop_3:
beq   $a0, $0, chbti_end_3
add   $v0, $v0, 1         # result ++
sra   $a0, $a0, 1         # domain >>= 1
j     chbti_loop_3
chbti_end_3:
sub    $t0, $s1, 1                  # num_cell - 1
mul    $t0, $t0, $v0                # (num_cell - 1) * lower_bound
sub    $t0, $s0, $t0                # t0 = high_bits
bge    $t0, 0, gdfa_skip0
li     $t0, 0
gdfa_skip0:
bge    $t0, $s3, gdfa_skip1
li     $t1, 1
sll    $t0, $t1, $t0                # 1 << high_bits
sub    $t0, $t0, 1                  # (1 << high_bits) - 1
and    $s2, $s2, $t0                # domain & ((1 << high_bits) - 1)
gdfa_skip1:
sub    $t0, $s1, 1                  # num_cell - 1
mul    $t0, $t0, $s3                # (num_cell - 1) * upper_bound
sub    $t0, $s0, $t0                # t0 = low_bits
ble    $t0, $0, gdfa_skip2
sub    $t0, $t0, 1                  # low_bits - 1
sra    $s2, $s2, $t0                # domain >> (low_bits - 1)
sll    $s2, $s2, $t0                # domain >> (low_bits - 1) << (low_bits - 1)
gdfa_skip2:
move   $v0, $s2                     # return domain
lw     $ra, 0($sp)
lw     $s0, 4($sp)
lw     $s1, 8($sp)
lw     $s2, 12($sp)
lw     $s3, 16($sp)
add    $sp, $sp, 20
j gdfc_end
gdfc_check_else:
lw $t3, 12($s3) # puzzle->grid[position].cage->positions
lw $t0, 0($t3) # puzzle->grid[position].cage->positions[0]
lw $t1, 4($t3) # puzzle->grid[position].cage->positions[1]
xor $t0, $t0, $t1
xor $t0, $t0, $s6 # other_pos = $t0 = $t0 ^ position
lw $a0, 4($s3) # puzzle->grid[position].cage->target
sll $t2, $s6, 3 # position * 8
add $a1, $s5, $t2 # &puzzle->grid[position]
lw  $a1, 0($a1) # puzzle->grid[position].domain
# move $a1, $s7
sll $t1, $t0, 3 # other_pos*8 (actual offset)
add $t3, $s5, $t1 # &puzzle->grid[other_pos]
lw $a2, 0($t3)  # puzzle->grid[other_pos].domian
li     $t0, 1
li     $t1, 2
mul    $t1, $t1, $a0            # target * 2
sll    $t1, $t0, $t1            # 1 << (target * 2)
or     $t0, $t0, $t1            # t0 = base_mask
li     $t1, 0                   # t1 = mask
gdfs_loop:
beq    $a2, $0, gdfs_loop_end
and    $t2, $a2, 1              # other_domain & 1
beq    $t2, $0, gdfs_if_end
sra    $t2, $t0, $a0            # base_mask >> target
or     $t1, $t1, $t2            # mask |= (base_mask >> target)
gdfs_if_end:
sll    $t0, $t0, 1              # base_mask <<= 1
sra    $a2, $a2, 1              # other_domain >>= 1
j      gdfs_loop
gdfs_loop_end:
and    $v0, $a1, $t1            # domain & mask
# j gdfc_end
gdfc_end:
# restore registers
lw $ra, 0($sp)
lw $s0, 4($sp)
lw $s1, 8($sp)
lw $s2, 12($sp)
lw $s3, 16($sp)
lw $s4, 20($sp)
lw $s5, 24($sp)
lw $s6, 28($sp)
lw $s7, 32($sp)
add $sp, $sp, 36
lw    $a0, 4($sp)
lw    $a1, 8($sp)
and   $s1, $s1, $v0
sw    $s1, 0($s2)     # puzzle->grid[pos].domain &= get_domain_for_cell(pos, puzzle)
beq   $s1, $0, fc_return_zero
fc_for_i_continue:
add   $s0, $s0, 1     # i++
j     fc_for_i
fc_return_one:
li    $v0, 1
j     fc_return
fc_return_zero:
li    $v0, 0
fc_return:
lw    $ra, 0($sp)
lw    $a0, 4($sp)
lw    $a1, 8($sp)
lw    $s0, 12($sp)
lw    $s1, 16($sp)
lw    $s2, 20($sp)
add   $sp, $sp, 24
beq   $v0, $0, recursive_backtracking_skip
lw    $a0, 4($sp)     # solution
add   $a1, $sp, 24    # &puzzle_copy
jal   recursive_backtracking
beq   $v0, $0, recursive_backtracking_skip
j     recursive_backtracking_return_one # if (recursive_backtracking(solution, &puzzle_copy))
recursive_backtracking_skip:
lw    $a0, 4($sp)     # solution
mul   $t0, $s0, 4
add   $t1, $a0, 4
add   $t1, $t1, $t0
sw    $0, 0($t1)      # solution->assignment[position] = 0
lw    $t0, 0($a0)
sub   $t0, $t0, 1
sw    $t0, 0($a0)     # solution->size -= 1
recursive_backtracking_for_loop_continue:
add   $s1, $s1, 1     # val++
j     recursive_backtracking_for_loop
recursive_backtracking_return_zero:
li    $v0, 0
j     recursive_backtracking_return
recursive_backtracking_return_one:
li    $v0, 1
recursive_backtracking_return:
lw    $ra, 0($sp)
lw    $a0, 4($sp)
lw    $a1, 8($sp)
lw    $s0, 12($sp)
lw    $s1, 16($sp)
lw    $s2, 20($sp)
add   $sp, $sp, 680
jr    $ra


# -----------------------------------------------------------------------
# END HELPER FUNCTIONS FOR solve_puzzle
# -----------------------------------------------------------------------
# BEGIN initialize_movement
# -----------------------------------------------------------------------

# initialize_movement:
# 	sub 	$sp, $sp, 20
# 	sw	$ra, 0($sp)
# 	sw 	$s0, 4($sp)
# 	sw 	$s1, 8($sp)
# 	sw 	$s2, 12($sp)
# 	sw 	$s3, 16($sp)

# 	li 	$s2, 1
# 	li 	$s3, 10

#     	lw     	$s0, BOT_X      # t3 = bot x-pos
#     	sub    	$s0, $a0, $s0   # t3 = dest x-pos - bot x-pos
#     	li     	$s1, 0          # absolute angle = 0 (right)
#     	bge    	$s0, $0, im_x_cont
#     	li     	$s1, 180        # absolute angle = 180 (left)
# im_x_cont:
#     	sw     	$s1, ANGLE      # set ANGLE
#     	sw     	$s2, ANGLE_CONTROL  # set ANGLE_CONTROL to absolute
#     	sw     	$s3, VELOCITY   # set VELOCITY
# im_x_check:
#     	lw     	$s0, BOT_X      # t3 = bot x-pos
#     	sub    	$s0, $a0, $s0   # t3 = fire x-pos - bot x-pos
#     	beq    	$s0, $0, im_y # when x coords match, start y process
#     	j      	im_x_check
# im_y:
#     	lw     	$s0, BOT_Y      # t3 = bot y-pos
#     	sub    	$s0, $a1, $s0   # t3 = dest y-pos - bot y-pos
#     	li     	$s1, 90          # absolute angle = 90 (up)
#     	bge    	$s0, $0, im_y_cont
#     	li     	$s1, 270        # absolute angle = 270 (down)
# im_y_cont:
#     	sw     	$s1, ANGLE      # set ANGLE
#     	sw     	$s2, ANGLE_CONTROL  # set ANGLE_CONTROL to absolute
#     	sw     	$s3, VELOCITY   # set VELOCITY
# im_y_check:
# 	lw	$s0, BOT_Y
# 	sub 	$s0, $a1, $s0
# 	beq	$s0, $0, im_done
#     	j      	im_y_check

# im_done:
# 	li	$s1, 135
# 	sw	$s1, ANGLE
# 	sw	$s2, ANGLE_CONTROL
# 	sw	$s3, VELOCITY
# 	lw	$ra, 0($sp)
# 	lw 	$s0, 4($sp)
# 	lw 	$s1, 8($sp)
# 	lw 	$s2, 12($sp)
# 	lw 	$s3, 16($sp)
# 	add 	$sp, $sp, 20

# 	jr	$ra
# -----------------------------------------------------------------------
# END initialize_movement
# -----------------------------------------------------------------------

.kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 8	# space for three registers

.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at		# Save $at
.set at
	la	$k0, chunkIH

	sw	$a0, 0($k0)		# Get some free registers
	sw	$a1, 4($k0)		# by storing them to a global variable

	mfc0	$k0, $13		# Get Cause register
	srl	$a0, $k0, 2
	and	$a0, $a0, 0xf		# ExcCode field
	bne	$a0, 0, done

interrupt_dispatch:
	mfc0	$k0, $13		# Get Cause register, again
	beq	$k0, 0, done		# handled all outstanding interrupts

	# is there a bonk interrupt?
	and	$a0, $k0, BONK_MASK
	bne	$a0, 0, bonk_interrupt

	# is there a puzzle ready to solve?
	and	$a0, $k0, REQUEST_PUZZLE_INT_MASK
	bne	$a0, 0, request_puzzle_interrupt

	# add dispatch for other interrupt types here.
	j	done

bonk_interrupt:
	# acknowledge the interrupt
	sw	$0, BONK_ACK

	# set angle to an offset of 180
	li	$a0, -90
	sw	$a0, ANGLE
	sw	$0, ANGLE_CONTROL		# relative to current

	# set velocity to full steam ahead
	li 	$a0, 10
	sw	$a0, VELOCITY			# set velocity to max

	j	interrupt_dispatch

request_puzzle_interrupt:
	# acknowledge the interrupt
	sw	$0, REQUEST_PUZZLE_ACK
	j 	interrupt_dispatch

done:
	la	$k0, chunkIH

	lw	$a0, 0($k0)		# Restore saved registers
	lw	$a1, 4($k0)

.set noat
	move	$at, $k1		# Restore $at
.set at
	eret
