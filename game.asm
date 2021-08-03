#####################################################################
#
# CSC258 Summer 2021 Assembly Final Project
# University of Toronto
#
# Student: Name, Student Number, UTorID
#	Stanley Bryan Z. Hua, 1005977267, huastanl
#	Jun Ni Du, 1006217130, dujun1
#
# Bitmap Display Configuration:
# - Unit width in pixels: 4
# - Unit height in pixels: 4
# - Display width in pixels: 1024
# - Display height in pixels: 1024
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1 (choose the one that applies)
#
# Which approved features have been implemented for milestone 3?
# (See the assignment handout for the list of additional features)
# 1. (fill in the feature, if any)
# 2. (fill in the feature, if any)
# 3. (fill in the feature, if any)
# ... (add more if necessary)
#
# Link to video demonstration for final submission:
# - (insert YouTube / MyMedia / other URL here). Make sure we can view it!
#
# Are you OK with us sharing the video with people outside course staff?
# - yes / no / yes, and please share this project github link as well!
#
# Any additional information that the TA needs to know:
# - (write here, if any)
#
#####################################################################
#_________________________________________________________________________________________________________________________
# ==CONSTANTS==:
.eqv UNIT_WIDTH 4
.eqv UNIT_HEIGHT 4

.eqv column_increment 4			# 4 memory addressess will always refer to 1 unit (32 bits or 4 bytes)
.eqv row_increment 1024			# [(display_row) / UNIT_HEIGHT] * column_increment

.eqv column_max 1024			# column_increment * (display_column) / UNIT_WIDTH			# NOTE: Always equal to row_increment
.eqv row_max 262144			# row_increment * (display_row) / UNIT_HEIGHT

.eqv plane_center 15360			# offset for center of plane. = 15 bytes * row_increment

.eqv display_base_address 0x10008000		# display base address
.eqv object_base_address 0x1000C82C		# starting point for all objects and plane
#___________________________________________________________________________________________________________________________
# ==VARIABLES==:
.data
displayAddress: 	.word 0x10008000
obstacle_positions: 	.word 10:20	# assume we have max. 20 obstacles at the same time
#___________________________________________________________________________________________________________________________
.text
# ==MACROS==:
	# MACRO: Store mem. address difference of unit's row from the center
		# used in in LOOP_PLANE_ROWS
	.macro set_row_incr(%y)
		# temporarily store row_increment and y-unit value
		addi $t8, $0, row_increment
		addi $t9, $0, %y
		mult $t8, $t9
		mflo $t5				# $t5 = %y * row_increment		(lower 32 bits)
	.end_macro
	# MACRO: Check whether to color normally or black. Update $t1 accordingly.
		# $t1: contains color to be painted
		# $a1: boolean to determine if color $t1 or black.
		# NOTE: $t1 == $t1 if $a1 == 1. Otherwise, $t1 == 0.
	.macro check_color
		mult $a1, $t1
		mflo $t1
	.end_macro
	# MACRO:
	.macro setup_object_paint (%color, %offset)
		addi $t1, $0, %color			# change current color to dark gray
    		check_color			        # updates color (in $t1) according to func. param. $a1
		add $t2, $0, $0				# reinitialize temporary address store
		addi $t2, $a0, %offset			# add address offset to base address
		sw $t1, ($t2)				# paint pixel value
	.end_macro
	# MACRO: Push / Store value in register $reg to stack
	.macro push_reg_to_stack ($reg)
		addi $sp, $sp, -4			# decrement by 4
		sw $reg, ($sp)				# store register at stack pointer
	.end_macro
	# MACRO: Pop / Load value from stack to register $reg
	.macro pop_reg_from_stack ($reg)
		lw $reg, ($sp)				# load stored value from register
		addi $sp, $sp, 4			# de-allocate space;	increment by 4
	.end_macro

	# MACRO:  Get column and row index from current base address
		# Registers Used
			# $s1-2: for temporary operations
			# $col_store: to store column index
			# $row_store: to store row index
	.macro calculate_indices ($address, $col_store, $row_store)
		# Store curr. $s0-1 values in stack.
		push_reg_to_stack ($s1)
		push_reg_to_stack ($s2)

		# Calculate indices
		subi $s1, $address, display_base_address	# subtract base display address (0x10008000)
		addi $s2, $zero, row_increment
		div $s1, $s2				# divide by row increment
		mflo $row_store				# quotient = row index
		
		addi $s2, $zero, column_increment
		mfhi $s1				# store remainder back in $s1. NOTE: remainder = column_increment * column index
		div $s1, $s2				# divide by column increment
		mflo $col_store				# quotient = column index
		

		# Restore $s0-1 values from stack.
		pop_reg_from_stack ($s2)
		pop_reg_from_stack ($s1)
	.end_macro
#___________________________________________________________________________________________________________________________
# ==INITIALIZATION==:
INITIALIZE:

# ==PARAMETERS==
addi $s7, $zero, 0				# counter for how many main loop the game has looped
addi $s6, $zero, 3				# max. obstacles at once
addi $s0, $0, 3					# starting number of hearts

# Paint Border
jal PAINT_BORDER
# Paint Health
jal UPDATE_HEALTH
# Paint Plane
addi $a1, $zero, 1				# set to paint
addi $a0, $0, object_base_address		# start painting plane from top-left border
addi $a0, $a0, 96256				# center plane in 
push_reg_to_stack ($a0)				# store current plane address in stack
jal PAINT_PLANE					# paint plane at $a0



GENERATE_OBSTACLES:
	# Used Registers
		# $a0, $a1, $a2: PAINT_OBJECT parameters
		# $t0: temporarily stores memory address word increment (4). Also used in multiplication
		# $t1: holds current object base address
		# $s4: for loop indexer over the number of obstacles
		# $s6: total number of obstacles
	addi $s4, $zero, 0		# i = 0		# initialize for loop indexer

	obstacle_gen_loop:	bge $s4, $s6, end_loop			# exit loop when i >= 3
			jal RANDOM_OFFSET			# store random address offset in $v0
			addi $a0, $0, object_base_address	# PAINT_OBJECT param. Load default object_base_address
			addi $a1, $zero, 1			# PAINT_OBJECT param. Set to paint
			addi $a2, $v0, 0			# PAINT_OBJECT param. Random address offset
			jal PAINT_OBJECT

			# Store current obstacle address to memory
			add $t1, $a0, $a2			# store current object base address (default + random offset)
			addi $t0, $0, 4				# initialize $t0
			mult $s4, $t0				# multiply current for loop index by increment to get memory address ofsset
			mflo $t0				# store memory address offset in $t0
			sw $t1, obstacle_positions($t0)		# save obstacle address into the array
			
			# Update loop
			addi $s4, $s4, 1			# i += 1
			j obstacle_gen_loop

	end_loop:

pop_reg_from_stack ($a0)			# restore current plane address from stack

# main game loop
MAIN_LOOP:

	AVATAR_MOVE:
		jal check_key_press		# check for keyboard input and redraw avatar accordingly
		add $s1, $a0, $0		# temporarily store plane's base address

	OBSTACLE_MOVE:
		la $s5, obstacle_positions	# $s5 holds the address of obstacle_positions
		addi $s4, $zero, 0		# i = 0

	obstacle_move_loop:				# move each obstacle one pixel left in a loop
		bge $s4, $s6, end_move_loop		# exit loop when i >= 3

		add $s2, $a0, 0			# save avatar address to $s2 (temp.)
		lw $a0, 0($s5)			# load the address of the current obstacle into $a0
		jal MOVE_OBJECT
		sw $a0, ($s5)
		add $s5, $s5, 4   		# increment array address pointer by 4

		add $a0, $s2, 0			# set $a0 back to avatar address
		addi $s4, $s4, 1		# i++
		j obstacle_move_loop

	end_move_loop:

	j MAIN_LOOP				# repeat loop
	
END_SCREEN_LOOP:
	jal CLEAR_SCREEN			# reset to black screen
	# jal PAINT_GAME_OVER			# create game over screen
	# Monitor p or q key press

# Tells OS the program ends
EXIT:	li $v0, 10
	syscall

#___________________________________________________________________________________________________________________________
# ==FUNCTIONS==:
# FUNCTION: PAINT PLANE
	# Inputs
		# $a0: stores base address for plane
		# $a1: If 0, paint plane in black. Elif 1, paint plane in normal colors.
	# Registers Used
		# $t1: stores current color value
		# $t2: temporary memory address storage for current unit (in bitmap)
		# $t3: column index for 'for loop' LOOP_PLANE_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $t4: row index for 'for loop' LOOP_PLANE_ROWS
		# $t5: parameter for subfunction LOOP_PLANE_ROWS. Will store # rows to paint from the center row outwards
		# $t8-9: used for multiplication operations
PAINT_PLANE:
	# Store used registers to stack
	# Store current state of used registers
	push_reg_to_stack ($t1)
	push_reg_to_stack ($t2)
	push_reg_to_stack ($t3)
	push_reg_to_stack ($t4)
	push_reg_to_stack ($t5)
	push_reg_to_stack ($t8)
	push_reg_to_stack ($t9)

	# Initialize registers
	add $t1, $0, $0				# initialize current color to black
	add $t2, $0, $0				# holds temporary memory address
	add $t3, $0, $0				# holds 'column for loop' indexer
	add $t4, $0, $0				# holds 'row for loop' indexer

	# FOR LOOP (through the bitmap columns)
	LOOP_PLANE_COLS: bge $t3, 112, EXIT_PLANE_PAINT	# repeat loop until column index = column 28 (112)
		add $t4, $0, $0			# reinitialize t4; index for LOOP_PLANE_ROWS

		# SWITCH CASES: paint in row based on column value
		beq $t3, 0, PLANE_COL_0
		beq $t3, 4, PLANE_COL_1_2
		beq $t3, 8, PLANE_COL_1_2
		beq $t3, 12, PLANE_COL_3
		beq $t3, 16, PLANE_COL_4_7
		beq $t3, 20, PLANE_COL_4_7
		beq $t3, 24, PLANE_COL_4_7
		beq $t3, 28, PLANE_COL_4_7
		beq $t3, 32, PLANE_COL_8_13
		beq $t3, 36, PLANE_COL_8_13
		beq $t3, 40, PLANE_COL_8_13
		beq $t3, 44, PLANE_COL_8_13
		beq $t3, 48, PLANE_COL_8_13
		beq $t3, 52, PLANE_COL_8_13
		beq $t3, 56, PLANE_COL_14
		beq $t3, 60, PLANE_COL_15_18
		beq $t3, 64, PLANE_COL_15_18
		beq $t3, 68, PLANE_COL_15_18
		beq $t3, 72, PLANE_COL_15_18
		beq $t3, 76, PLANE_COL_19_21
		beq $t3, 80, PLANE_COL_19_21
		beq $t3, 84, PLANE_COL_19_21
		beq $t3, 88, PLANE_COL_22_24
		beq $t3, 92, PLANE_COL_22_24
		beq $t3, 96, PLANE_COL_22_24
		beq $t3, 100, PLANE_COL_25
		beq $t3, 104, PLANE_COL_26
		beq $t3, 108, PLANE_COL_27

		# If not of specified rows, end iteration without doing anything.
		j UPDATE_COL


		PLANE_COL_0:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color			# updates color according to func. param. $a1
	                add $t2, $a0, $t3		# update to specific column from base address
	            	addi $t2, $t2, plane_center	# update to specified center axis
	           	sw $t1, ($t2)			# paint at center axis
	           	j UPDATE_COL			# end iteration
		PLANE_COL_1_2:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (6)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_3:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (4)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_4_7:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (2)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_8_13:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (3)		# update row for column
    			j LOOP_PLANE_ROWS		# paint in row
                	j UPDATE_COL			# end iteration
		PLANE_COL_14:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (8)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
        	        j UPDATE_COL			# end iteration
		PLANE_COL_15_18:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (16)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_19_21:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (3)		# update row for column
	            	j LOOP_PLANE_ROWS		# paint in row
	            	j UPDATE_COL			# end iteration
		PLANE_COL_22_24:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
			set_row_incr (2)		# update row for column
			j LOOP_PLANE_ROWS		# paint in row
			j UPDATE_COL			# end iteration
		PLANE_COL_25:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
			add $t2, $0, $0			# reinitialize temporary address store
			add $t2, $a0, $t3		# update to specific column from base address
			addi $t2, $t2, plane_center	# update to specified center axis
			sw $t1, ($t2)			# paint at center axis
			j UPDATE_COL			# end iteration
		PLANE_COL_26:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color			# updates color according to func. param. $a1
			set_row_incr (2)		# update row for column
			j LOOP_PLANE_ROWS		# paint in row
			j UPDATE_COL			# end iteration
		PLANE_COL_27:
			addi $t1, $0, 0x803635		# change current color to dark red
			check_color			# updates color according to func. param. $a1
			add $t2, $0, $0			# reinitialize temporary address store
			add $t2, $a0, $t3		# update to specific column from base address
			addi $t2, $t2, plane_center	# update to specified center axis
			sw $t1, ($t2)			# paint at center axis
			j UPDATE_COL			# end iteration

		UPDATE_COL: addi $t3, $t3, column_increment	# add 4 bits (1 byte) to refer to memory address for next row row
			j LOOP_PLANE_COLS		# repeats LOOP_PLANE_COLS

	EXIT_PLANE_PAINT:
		# Restore registers from stack
		pop_reg_from_stack ($t9)
		pop_reg_from_stack ($t8)
		pop_reg_from_stack ($t5)
		pop_reg_from_stack ($t4)
		pop_reg_from_stack ($t3)
		pop_reg_from_stack ($t2)
		pop_reg_from_stack ($t1)
		jr $ra					# return to previous instruction before PAINT_PLANE was called.

	# FOR LOOP: (through row)
	# Paints in symmetric row at given column (stored in t2) 	# from center using row (stored in $t5)
	LOOP_PLANE_ROWS: bge $t4, $t5, UPDATE_COL	# returns to LOOP_PLANE_COLS when index (stored in $t4) >= (number of rows to paint in) /2
		add $t2, $0, $0				# Reinitialize t2; temporary address store
		add $t2, $a0, $t3			# update to specific column from base address
		addi $t2, $t2, plane_center		# update to specified center axis

		add $t2, $t2, $t4			# update to positive (delta) row
		sw $t1, ($t2)				# paint at positive (delta) row

		sub $t2, $t2, $t4			# update back to specified center axis
		sub $t2, $t2, $t4			# update to negative (delta) row
		sw $t1, ($t2)				# paint at negative (delta) row

		# Updates for loop index
		addi $t4, $t4, row_increment		# t4 += row_increment
		j LOOP_PLANE_ROWS			# repeats LOOP_PLANE_ROWS
#___________________________________________________________________________________________________________________________

check_key_press:	lw $t8, 0xffff0000		# load the value at this address into $t8
			bne $t8, 1, EXIT_KEY_PRESS	# if $t8 != 1, then no key was pressed, exit the function
			lw $t4, 0xffff0004		# load the ascii value of the key that was pressed

check_border:		la $t0, ($a0)			# load ___ base address to $t0
			calculate_indices ($t0, $t5, $t6)	# calculate column and row index

			beq $t4, 0x61, respond_to_a 	# ASCII code of 'a' is 0x61 or 97 in decimal
			beq $t4, 0x77, respond_to_w	# ASCII code of 'w'
			beq $t4, 0x73, respond_to_s	# ASCII code of 's'
			beq $t4, 0x64, respond_to_d	# ASCII code of 'd'
			beq $t4, 0x70, respond_to_p	# restart game when 'p' is pressed
			beq $t4, 0x71, respond_to_q	# exit game when 'q' is pressed
			j OBSTACLE_MOVE			# invalid key, exit the input checking stage

respond_to_a:		ble $t5, 11, EXIT_KEY_PRESS	# the avatar is on left of screen, cannot move up
			subu $t0, $t0, column_increment	# set base position 1 pixel left
			j draw_new_avatar
respond_to_w:		ble $t6, 18, EXIT_KEY_PRESS	# the avatar is on top of screen, cannot move up
			subu $t0, $t0, row_increment	# set base position 1 pixel up
			j draw_new_avatar
respond_to_s:		bgt $t6, 206, EXIT_KEY_PRESS
			addu $t0, $t0, row_increment	# set base position 1 pixel down
			j draw_new_avatar
respond_to_d:		bgt $t5, 216, EXIT_KEY_PRESS
			addu $t0, $t0, column_increment	# set base position 1 pixel right
			j draw_new_avatar

draw_new_avatar:	addi $a1, $zero, 0		# set $a1 as 0
			jal PAINT_PLANE			# (erase plane) paint plane black

			la $a0, ($t0)			# load new base address to $a0
			addi $a1, $zero, 1		# set $a1 as 1
			jal PAINT_PLANE			# paint plane at new location
			j EXIT_KEY_PRESS

respond_to_p:		jal erase_everything
			j INITIALIZE

respond_to_q:		jal erase_everything
			j EXIT

erase_everything:	jr $ra



EXIT_KEY_PRESS:		j AVATAR_MOVE			# avatar finished moving, move to next stage
#___________________________________________________________________________________________________________________________
# FUNCTION: Create random address offset
	# Used Registers
		# $a0: used to create random integer via syscall
		# $a1: used to create random integer via syscall
		# $v0: used to create random integer via syscall
		# $s0: used to hold column/row offset
		# $s1: used to hold column/row offset
		# $s2: accumulator of random offset from column and height
	# Outputs:
		# $v0: stores return value for random address offset
RANDOM_OFFSET:
	# Store used registers to stack
	push_reg_to_stack ($a0)
	push_reg_to_stack ($a1)
	push_reg_to_stack ($s0)
	push_reg_to_stack ($s1)
	push_reg_to_stack ($s2)
	
	# Randomly generate row value
	li $v0, 42 		# Specify random integer
	li $a0, 0 		# from 0
	li $a1, 220 		# to 220
	syscall 		# generate and store random integer in $a0

	addi $s0, $0, row_increment	# store row increment in $s0
	mult $a0, $s0			# multiply row index to row increment
	mflo $s2			# store result in $s2

	# Randomly generate col value
	li $v0, 42 		# Specify random integer
	li $a0, 0 		# from 0
	li $a1, 220 		# to 220
	syscall 		# Generate and store random integer in $a0

	addi $s0, $0, column_increment	# store column increment in $s0
	mult $a0, $s0			# multiply column index to column increment
	mflo $s1			# store result in t9
	add $s2, $s2, $s1		# add column address offset to base address

	add $v0, $s2, $0		# store return value (address offset) in $v0
	
	# Restore used registers from stack
	pop_reg_from_stack ($s2)
	pop_reg_from_stack ($s1)
	pop_reg_from_stack ($s0)
	pop_reg_from_stack ($a1)
	pop_reg_from_stack ($a0)
	jr $ra			# return to previous instruction
#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT OBJECT
	# Inputs
		# $a0: object base address
		# $a1: If 0, paint in black. Elif 1, paint in color specified otherwise.
		# $a2: random address offset
	# Registers Used
		# $t1: stores current color value
		# $t2: temporary memory address storage for current unit (in bitmap)
		# $t3: column index for 'for loop' LOOP_OBJ_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $t4: row index for 'for loop' LOOP_OBJ_ROWS
		# $t5: parameter for subfunction LOOP_OBJ_ROWS. Will store # rows to paint from the center row outwards
		# $t8-9: used for multiplication operations
PAINT_OBJECT:
	# Store used registers to stack
	push_reg_to_stack ($t1)
	push_reg_to_stack ($t2)
	push_reg_to_stack ($t3)
	push_reg_to_stack ($t4)
	push_reg_to_stack ($t5)
	push_reg_to_stack ($t8)
	push_reg_to_stack ($t9)
	# Initialize registers
	add $t1, $0, $0				# initialize current color to black
	add $t2, $0, $0				# holds temporary memory address
	add $t3, $0, $0				# holds 'column for loop' indexer
	add $t4, $0, $0				# holds 'row for loop' indexer

	addi $t1, $0, 0xFFFFFF			# change current color to white
	check_color				# updates color according to func. param. $a1

	# FOR LOOP: (through col)
	LOOP_OBJ_COLS: bge $t3, 24, EXIT_PAINT_OBJECT
		set_row_incr (6)		# update row for column
		j LOOP_OBJ_ROWS			# paint in row
	UPDATE_OBJ_COL:				# Update column value
		addi $t3, $t3, column_increment	# add 4 bits (1 byte) to refer to memory address for next row
		add $t4, $0, $0			# reinitialize index for LOOP_OBJ_ROWS
		j LOOP_OBJ_COLS
	EXIT_PAINT_OBJECT:
		# Restore used registers from stack
		pop_reg_from_stack ($t9)
		pop_reg_from_stack ($t8)
		pop_reg_from_stack ($t5)
		pop_reg_from_stack ($t4)
		pop_reg_from_stack ($t3)
		pop_reg_from_stack ($t2)
		pop_reg_from_stack ($t1)
		jr $ra				# return to previous instruction

	# FOR LOOP: (through row)
	# Paints in symmetrically from center at given column
	LOOP_OBJ_ROWS: bge $t4, $t5, UPDATE_OBJ_COL	# returns when row index (stored in $t4) >= (number of rows to paint in) /2
		add $t2, $a0, $0			# start from base address
		add $t2, $t2, $t3			# update to specific column
		add $t2, $t2, $t4			# update to specific row
		add $t2, $t2, $a2			# update to random offset
		sw $t1, ($t2)				# paint

		# Updates for loop index
		addi $t4, $t4, row_increment		# t4 += row_increment
		j LOOP_OBJ_ROWS				# repeats LOOP_OBJ_ROWS
#___________________________________________________________________________________________________________________________
MOVE_OBJECT:
	addi $a1, $0, 0
	jal PAINT_OBJECT
	subu $a0, $a0, column_increment
	addi $a1, $0, 1
	jal PAINT_OBJECT
	jr $ra
#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT BORDER
	# Registers Used
		# $t1: parameter for LOOP_BORDER_ROWS. Stores color value
		# $t2: temporary memory address storage for current unit (in bitmap)
		# $t3: column index for 'for loop' LOOP_BORDER_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $t4: beginning row index for 'for loop' LOOP_BORDER_ROWS
		# $t5: parameter for LOOP_BORDER_ROWS. Stores row index for last row to be painted in
		# $t6: parameter for LOOP_BORDER_ROWS. Stores # rows to paint from top to bottom
		# $t7: stores result from logical operations
		# $t8-9: used for logical operations
PAINT_BORDER:
	# Push $ra to stack
	push_reg_to_stack ($ra)

	# Initialize registers
	add $t1, $0, $0				# initialize current color to black
	add $t2, $0, $0				# holds temporary memory address
	add $t3, $0, $0				# 'column for loop' indexer
	add $t4, $0, $0				# 'row for loop' indexer
	add $t5, $0, $0				# last row index to paint in

	LOOP_BORDER_COLS: bge $t3, column_max, EXIT_BORDER_PAINT
		# Boolean Expressions: Paint in border piece based on column index
		BORDER_COND:
			# BORDER_OUTER
			sle $t8, $t3, 36
			sge $t9, $t3, 24
			and $t7, $t8, $t9		# 6 <= col index <= 9

			sle $t8, $t3, 996
			sge $t9, $t3, 984
			and $t9, $t8, $t9		# 246 <= col index <= 249

			or $t7, $t7, $t9		# if 6 <= col index <= 9 	|	246 <= col index <= 249
			beq $t7, 1, BORDER_OUTER

			# BORDER_OUTERMOST
			sle $t8, $t3, 20
			sge $t9, $t3, 1000
			or $t7, $t8, $t9		# if col <= 5 OR col index >= 250
			beq $t7, 1, BORDER_OUTERMOST

			# BORDER_INNER
			seq $t8, $t3, 40
			seq $t9, $t3, 980
			or $t7, $t8, $t9		# if col == 10 OR == 245
			beq $t7, 1, BORDER_INNER

			# BORDER_OUTER
			sge $t9, $t3, 44
			sle $t8, $t3, 976
			or $t7, $t8, $t9		# if col <= 11 OR col index >= 244
			beq $t7, 1, BORDER_INNERMOST

		# Paint Settings
		BORDER_OUTERMOST:
			addi $t1, $0, 0x868686		# change current color to dark gray
			add $t4, $0, $0			# paint in from top to bottom
			addi $t5, $0, row_max
	    		jal LOOP_BORDER_ROWS		# paint in column
	                j UPDATE_BORDER_COL		# end iteration
		BORDER_OUTER:
			# Paint dark gray section
			addi $t1, $0, 0x868686		# change current color to dark gray
			add $t4, $0, $0			# paint starting from row ___
			addi $t5, $0, 13312		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint light gray section
	    		addi $t1, $0, 0xC3C3C3		# change current color to light gray
			addi $t4, $0, 13312		# paint starting from row ___
			addi $t5, $0, 248832		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
			# Paint dark gray section
			addi $t1, $0, 0x868686		# change current color to dark gray
			addi $t4, $0, 248832		# paint starting from row ___
			addi $t5, $0, row_max		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	                j UPDATE_BORDER_COL		# end iteration
		BORDER_INNER:
			# Paint dark gray section
			addi $t1, $0, 0x868686		# change current color to dark gray
			add $t4, $0, $0			# paint starting from row ___
			addi $t5, $0, 13312		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint light gray section
	    		addi $t1, $0, 0xC3C3C3		# change current color to light gray
			addi $t4, $0, 13312		# paint starting from row ___
			addi $t5, $0, 17408		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint white section
	    		addi $t1, $0, 0xFFFFFF		# change current color to white
			addi $t4, $0, 17408		# paint starting from row ___
			addi $t5, $0, 244736		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint light gray section
	    		addi $t1, $0, 0xC3C3C3		# change current color to light gray
			addi $t4, $0, 244736		# paint starting from row ___
			addi $t5, $0, 248832		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
			# Paint dark gray section
			addi $t1, $0, 0x868686		# change current color to dark gray
			addi $t4, $0, 248832		# paint starting from row ___
			addi $t5, $0, row_max		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column

	                j UPDATE_BORDER_COL		# end iteration
		BORDER_INNERMOST:
			# Paint dark gray section
			addi $t1, $0, 0x868686		# change current color to dark gray
			add $t4, $0, $0			# paint starting from row ___
			addi $t5, $0, 13312		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint light gray section
	    		addi $t1, $0, 0xC3C3C3		# change current color to light gray
			addi $t4, $0, 13312		# paint starting from row ___
			addi $t5, $0, 17408		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint white section
	    		addi $t1, $0, 0xFFFFFF		# change current color to white
			addi $t4, $0, 17408		# paint starting from row ___
			addi $t5, $0, 18432		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint black selection
	    		addi $t1, $0, 0			# change current color to black
			addi $t4, $0, 18432		# paint starting from row ___
			addi $t5, $0, 243712		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint white section
	    		addi $t1, $0, 0xFFFFFF		# change current color to white
			addi $t4, $0, 243712		# paint starting from row ___
			addi $t5, $0, 244736		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint light gray section
	    		addi $t1, $0, 0xC3C3C3		# change current color to light gray
			addi $t4, $0, 244736		# paint starting from row ___
			addi $t5, $0, 248832		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
			# Paint dark gray section
			addi $t1, $0, 0x868686		# change current color to dark gray
			addi $t4, $0, 248832		# paint starting from row ___
			addi $t5, $0, row_max		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column

	                j UPDATE_BORDER_COL		# end iteration

	UPDATE_BORDER_COL:				# Update column value
		addi $t3, $t3, column_increment		# add 4 bits (1 byte) to refer to memory address for next row
		j LOOP_BORDER_COLS

	# EXIT FUNCTION
	EXIT_BORDER_PAINT:
		# Restore $t registers
		pop_reg_from_stack ($ra)
		jr $ra						# return to previous instruction

	# FOR LOOP: (through row)
	# Paints in row from $t4 to $t5 at some column
	LOOP_BORDER_ROWS: bge $t4, $t5, EXIT_LOOP_BORDER_ROWS	# branch to UPDATE_BORDER_COL; if row index >= last row index to paint
		addi $t2, $0, display_base_address			# Reinitialize t2; temporary address store
		add $t2, $t2, $t3				# update to specific column from base address
		add $t2, $t2, $t4				# update to specific row
		sw $t1, ($t2)					# paint in value

		# Updates for loop index
		addi $t4, $t4, row_increment			# t4 += row_increment
		j LOOP_BORDER_ROWS				# repeats LOOP_BORDER_ROWS
	EXIT_LOOP_BORDER_ROWS:
		jr $ra
#___________________________________________________________________________________________________________________________
# FUNCTION: CLEAR_SCREEN
	# Registers Used
		# $t1: stores current color value
		# $t2: temporary memory address storage for current unit (in bitmap)
		# $t3: column index for 'for loop' LOOP_OBJ_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $t4: row index for 'for loop' LOOP_OBJ_ROWS
		# $t5: parameter for subfunction LOOP_OBJ_ROWS. Will store # rows to paint from the center row outwards
		# $t8-9: used for multiplication operations
CLEAR_SCREEN:
	# Push $ra to stack
	push_reg_to_stack ($ra)

	# Initialize registers
	add $t1, $0, $0				# initialize current color to black
	add $t2, $0, $0				# holds temporary memory address
	add $t3, $0, $0				# 'column for loop' indexer
	add $t4, $0, $0				# 'row for loop' indexer
	add $t5, $0, $0				# last row index to paint in

	LOOP_CLEAR_COL: bge $t3, column_max, EXIT_BORDER_PAINT
		CLEAR_ALL:
			addi $t1, $0, 0x000000		# change current color to black
			add $t4, $0, $0			# paint in from top to bottom
			addi $t5, $0, row_max
	    		jal LOOP_CLEAR_ROW		# paint in column
		UPDATE_CLEAR_COL:				# Update column index value
			addi $t3, $t3, column_increment		
			j LOOP_CLEAR_COL

	# EXIT FUNCTION
	EXIT_CLEAR_PAINT:
		# Restore $t registers
		pop_reg_from_stack ($ra)
		jr $ra						# return to previous instruction

	# FOR LOOP: (through row)
	# Paints in row from $t4 to $t5 at some column
	LOOP_CLEAR_ROW: bge $t4, $t5, EXIT_LOOP_CLEAR_ROW	# branch to UPDATE_CLEAR_COL; if row index >= last row index to paint
		addi $t2, $0, display_base_address			# Reinitialize t2; temporary address store
		add $t2, $t2, $t3				# update to specific column from base address
		add $t2, $t2, $t4				# update to specific row
		sw $t1, ($t2)					# paint in value

		# Updates for loop index
		addi $t4, $t4, row_increment			# t4 += row_increment
		j LOOP_CLEAR_ROW				# repeats LOOP_CLEAR_ROWS
	EXIT_LOOP_CLEAR_ROW:
		jr $ra
#___________________________________________________________________________________________________________________________
# FUNCTION: UPDATE_HEALTH
	# Inputs:
		# $s0: Current number of health points (min = 0, max = 5)
	# Registers Used:
		# $a2: address offset
		# $a3: whether to paint in or erase heart
		# $t0: for loop indexer
		# $t1: used to store column_increment temporarily
		# $t2: temporary storage for manipulating number of health points
		
UPDATE_HEALTH:
	# Store current state of used registers
	push_reg_to_stack ($ra)
	push_reg_to_stack ($s0)
	push_reg_to_stack ($a2)
	push_reg_to_stack ($a3)
	push_reg_to_stack ($t0)
	push_reg_to_stack ($t1)
	push_reg_to_stack ($t2)
	push_reg_to_stack ($t3)
	push_reg_to_stack ($t4)
	push_reg_to_stack ($t5)
	push_reg_to_stack ($t8)
	push_reg_to_stack ($t9)
	
	# Initialize for loop indexer
	add $t0, $0, $0
	# Loop 5 times through all possible hearts. Subtract 1 from number of hearts each time.
	LOOP_HEART: beq $t0, 5, EXIT_UPDATE_HEALTH	# branch if $t0 = 5
		addi $t1, $0, column_increment	# store column increment temporarily
		addi $t2, $0, 12			
		mult $t1, $t2
		mflo $t1			
		mult $t0, $t1			# address offset = current index * (3 * column_increment)
		mflo $a2			# param. for helper function to add column offset
		
		add $t2, $s0, $0		# store number of hit points
		sub $t2, $t2, $t0		# subtract number of hit points by current indexer
		sge $a3, $t2, 1			# param. for helper function to paint/erase heart. If number of hearts > curr index, paint in heart. Otherwise, erase.		
		jal PAINT_HEART			# paint/erase heart
		
		# Update for loop indexer
		addi $t0, $t0, 1		# $t0 = $t0 + 1
		j LOOP_HEART
	# Restore previouos state of used registers
	EXIT_UPDATE_HEALTH:
		pop_reg_from_stack ($t9)
		pop_reg_from_stack ($t8)
		pop_reg_from_stack ($t5)
		pop_reg_from_stack ($t4)
		pop_reg_from_stack ($t3)
		pop_reg_from_stack ($t2)
		pop_reg_from_stack ($t1)
		pop_reg_from_stack ($t0)
		pop_reg_from_stack ($a3)
		pop_reg_from_stack ($a2)
		pop_reg_from_stack ($s0)
		pop_reg_from_stack ($ra)
		jr $ra
#___________________________________________________________________________________________________________________________
# HELPER FUNCTION: PAINT_HEART
	# Inputs:
		# $a2: address offset 
		# $a3: whether to paint in or erase heart
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: column index for 'for loop' LOOP_OBJ_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $s3: starting row index for 'for loop' LOOP_OBJ_ROWS
		# $s4: ending row index for 'for loop' LOOP_OBJ_ROWS
		# $t8-9: used for multiplication operations

PAINT_HEART:
	    # Store used registers in the stack
	    push_reg_to_stack ($ra)
	    push_reg_to_stack ($s0)
	    push_reg_to_stack ($s1)
	    push_reg_to_stack ($s2)
	    push_reg_to_stack ($s3)
	    push_reg_to_stack ($s4)
    
	    # Initialize registers
	    add $s0, $0, $0				# initialize current color to black
	    add $s1, $0, $0				# holds temporary memory address
	    add $s2, $0, $0				# 'column for loop' indexer
	    add $s3, $0, $0				# 'row for loop' indexer
	    add $s4, $0, $0				# last row index to paint in

		LOOP_HEART_ROW: bge $s2, row_max, EXIT_PAINT_HEART
				# Boolean Expressions: Paint in based on row index
				HEART_COND:
						beq $s2, 0, HEART_ROW_0
						beq $s2, 1024, HEART_ROW_1
						beq $s2, 2048, HEART_ROW_2
						beq $s2, 3072, HEART_ROW_3
						beq $s2, 4096, HEART_ROW_4
						beq $s2, 5120, HEART_ROW_5
						beq $s2, 6144, HEART_ROW_6
						beq $s2, 7168, HEART_ROW_7
						beq $s2, 8192, HEART_ROW_8
						
						j UPDATE_HEART_ROW		# end iteration if not at specified index
				HEART_ROW_0:
						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x797979		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x4c4c4c		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x666666		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 16			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 16			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x6b6b6b		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x4c4c4c		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x747474		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_1:
						addi $s0, $0, 0x777777		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x6c2a2a		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xdc3131		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x9f1616		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 16			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x545353		# change current color
						addi $s3, $0, 16			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x900000		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xd80000		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x741e1e		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x737373		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_2:
						addi $s0, $0, 0x553131		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xed4343		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff4d4d		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff0000		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 16			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xcc0000		# change current color
						addi $s3, $0, 16			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xfb0000		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff0000		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xdb0000		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x502424		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_3:
						addi $s0, $0, 0x512424		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff3535		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff0000		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xe50000		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x4f1717		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_4:
						addi $s0, $0, 0x5f5050		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xc30000		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff0000		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xfa0000		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xb40000		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x564343		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_5:
						addi $s0, $0, 0x757575		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x701e1e		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xf80000		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff0000		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xfe0000		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xe50000		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x6c1717		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x707070		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_6:
						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x787878		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x671c1c		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff0000		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xe90000		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x651414		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x727272		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_7:
						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x7b7b7b		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x621c1c		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 16			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xe60000		# change current color
						addi $s3, $0, 16			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x611616		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x747474		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_8:
						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x7a7a7a		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 16			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x423333		# change current color
						addi $s3, $0, 16			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x747373		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW

    	UPDATE_HEART_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_HEART_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_HEART_COLUMN: bge $s3, $s4, EXIT_LOOP_HEART_COLUMN	# branch to UPDATE_HEART_COL; if column index >= last column index to paint
        		addi $s1, $0, display_base_address			# Reinitialize t2; temporary address store
        		
        		addi $s1, $s1, 250880				# shift row to bottom outermost border (row index 245)
        		addi $s1, $s1, 52				# shift column to column index 13
        		add $s1, $s1, $a2				# add offset from parameter $a2
        		
        		add $s1, $s1, $s2				# update to specific row from base address
        		add $s1, $s1, $s3				# update to specific column
        		
        		# If param. $a3 specifies to erase, then change color value stored in $s0
        		IF_ERASE: beq $a3, 1, PAINT_HEART_PIXEL
        			addi $s0, $0, 0x868686
        		
        		PAINT_HEART_PIXEL:	sw $s0, ($s1)				# paint in value
        		# Updates for loop index
        		addi $s3, $s3, column_increment			# t4 += row_increment
        		j LOOP_HEART_COLUMN				# repeats LOOP_HEART_ROW
	    EXIT_LOOP_HEART_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_HEART:
        		# Restore used registers
	    		pop_reg_from_stack ($s4)
	    		pop_reg_from_stack ($s3)
	    		pop_reg_from_stack ($s2)
	    		pop_reg_from_stack ($s1)
	    		pop_reg_from_stack ($s0)
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction

#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT_GAME_OVER
	# Registers Used
		# $t1: stores current color value
		# $t2: temporary memory address storage for current unit (in bitmap)
		# $t3: column index for 'for loop' LOOP_OBJ_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $t4: row index for 'for loop' LOOP_OBJ_ROWS
		# $t5: parameter for subfunction LOOP_OBJ_ROWS. Will store # rows to paint from the center row outwards
		# $t8-9: used for multiplication operations
