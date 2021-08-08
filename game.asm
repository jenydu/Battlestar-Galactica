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
# - press 'g' to directly enter Game Over Loop
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
		# NOTE: $color_reg == $color_reg if $a1 == 1. Otherwise, $$color_reg == 0.
	.macro check_color ($color_reg)
		mult $a1, $color_reg
		mflo $color_reg
	.end_macro
	# MACRO: Updates $s0, $s3-4 for painting.
		# $s0: will hold %color
		# $s3: will hold start_idx
		# $s4: will hold end_idx
	.macro setup_general_paint (%color, %start_idx, %end_idx, %label)
		addi $s0, $0, %color		# change current color
		check_color ($s0)		# check if current parameter $a1 to paint/erase
		addi $s3, $0, %start_idx	# paint starting from column /row___
		addi $s4, $0, %end_idx		# ending at column/row ___
		jal %label			# jump to %label to paint
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

	# MACRO: Get column and row index from current base address
		# Inputs
			# $address: register containing address
			# $col_store: register to store column index
			# $row_store: register to store row index
		# Registers Used
			# $s1-2: for temporary operations
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
	
	# MACRO: Compute boolean if pixel indices stored in registers $col_index and $row_index are within the border.
		# Inputs
			# $col: register containing column index
			# $row: register containing row index
			# $bool_store: register to store boolean output
		# Registers Used
			# $s0-2: used in logical operations
	.macro within_borders($col, $row, $bool_store)
		# Store current values of $s0-2 to stack
		push_reg_to_stack ($s0)
		push_reg_to_stack ($s1)
		push_reg_to_stack ($s2)
		# Column index in (11, 216)
		sgt $s0, $col, 11
		slti $s1, $col, 245
		and $s2, $s0, $s1			# 11 < col < 216
		# Row index in (18, 238)
		sgt $s0, $row, 18
		slti $s1, $row, 238
		and $bool_store, $s0, $s1		# 18 < row < 238
		and $bool_store, $bool_store, $s2	# make sure both inequalities are true
		# Restore $s0-1 values from stack.
		pop_reg_from_stack ($s2)
		pop_reg_from_stack ($s1)
		pop_reg_from_stack ($s0)
	.end_macro
#___________________________________________________________________________________________________________________________
# ==INITIALIZATION==:
INITIALIZE:

# ==PARAMETERS==:
addi $s0, $0, 3					# starting number of hearts
addi $s1, $0, 0					# score counter
addi $s2, $0, 0					# stores current base address for coin
addi $s3, $0, 0					# stores current base address for heart
addi $a1, $0, 1

# ==SETUP==:
jal PAINT_BORDER		# Paint Border
jal UPDATE_HEALTH		# Paint Health Status
jal PAINT_BORDER_COIN		# Paint Score
# Paint Plane
addi $a0, $0, object_base_address		# start painting plane from top-left border
addi $a0, $a0, 96256				# center plane
push_reg_to_stack ($a0)				# store current plane address in stack
jal PAINT_PLANE					# paint plane at $a0

#---------------------------------------------------------------------------------------------------------------------------
GENERATE_OBSTACLES:
	# Used Registers:
		# $a0-2: parameters for painting obstacle
	# Outputs:
		# $s5: holds obstacle 1 base address
		# $s6: holds obstacle 2 base address
		# $s7: holds obstacle 3 base address
	# Obstacle 1
	jal generate_asteroid
	addi $s5, $a0, 0
	
	# Obstacle 2
	jal generate_asteroid
	addi $s6, $a0, 0
	
	# Obstacle 3
	jal generate_asteroid
	addi $s7, $a0, 0
	
	# coin
	jal generate_coin
	
	# heart
	jal generate_heart
#---------------------------------------------------------------------------------------------------------------------------
pop_reg_from_stack ($a0)			# restore current plane address from stack

# main game loop
MAIN_LOOP:

	AVATAR_MOVE:
		jal PAINT_PLANE
		jal check_key_press		# check for keyboard input and redraw avatar accordingly

	OBSTACLE_MOVE:
		push_reg_to_stack ($a0)	
	move_obs_1:
		addi $a0, $s5, 0			# PAINT_ASTEROID param. Load obstacle 1 base address
		addi $a1, $zero, 0			# PAINT_ASTEROID param. Set to erase
		jal PAINT_ASTEROID			
		
		calculate_indices ($s5, $t5, $t6)	# calculate column and row index
		ble $t5, 11, regen_obs_1
		
		subu $s5, $s5, 4			# shift obstacle 1 unit left
		add $a0, $s5, $0 			# PAINT_ASTEROID param. Load obstacle 1 new base address
		addi $a1, $zero, 1			# PAINT_ASTEROID param. Set to paint
		jal PAINT_ASTEROID  
	
	move_obs_2:
		addi $a0, $s6, 0			# PAINT_ASTEROID param. Load obstacle 1 base address
		addi $a1, $0, 0				# PAINT_ASTEROID param. Set to erase
		jal PAINT_ASTEROID			
		
		calculate_indices ($s6, $t5, $t6)	# calculate column and row index
		ble $t5, 11, regen_obs_2
		
		subu $s6, $s6, 4			# shift obstacle 1 unit left
		add $a0, $s6, $0 			# PAINT_ASTEROID param. Load obstacle 1 new base address
		addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
		jal PAINT_ASTEROID  
	
	move_obs_3:
		addi $a0, $s7, 0			# PAINT_ASTEROID param. Load obstacle 1 base address
		addi $a1, $0, 0				# PAINT_ASTEROID param. Set to erase
		jal PAINT_ASTEROID			
		
		calculate_indices ($s7, $t5, $t6)	# calculate column and row index
		ble $t5, 11, regen_obs_3
		
		subu $s7, $s7, 4			# shift obstacle 1 unit left
		add $a0, $s7, $0			# PAINT_ASTEROID param. Load obstacle 1 new base address
		addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
		jal PAINT_ASTEROID 
	
	move_heart:	
		addi $a0, $s3, 0			# PAINT_ASTEROID param. Load obstacle 1 base address
		addi $a1, $0, 0				# PAINT_ASTEROID param. Set to erase
		jal PAINT_PICKUP_HEART			
		
		calculate_indices ($s3, $t5, $t6)	# calculate column and row index
		ble $t5, 11, regen_heart
		
		subu $s3, $s3, 4			# shift obstacle 1 unit left
		add $a0, $s3, $0			# PAINT_ASTEROID param. Load obstacle 1 new base address
		addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
		jal PAINT_PICKUP_HEART 
	EXIT_OBSTACLE_MOVE:
			
	GENERATE_COIN:		
		# RE-DRAW the coin every loop so that it doesn't get erased when an obstacle flies over it
		add $a0, $s2, $0			# PAINT_PICKUP_COIN param. Load base address
		addi $a1, $0, 1				# PAINT_PICKUP_COIN param. Set to paint
		jal PAINT_PICKUP_COIN	
		
	CHECK_COLLISION:
		pop_reg_from_stack ($a0)			# restore $a0 to plane's address
		jal COLLISION_DETECTOR			# check if the plane's hitbox is overlapped with an object based on colour
	
	
	j MAIN_LOOP				# repeat loop
#---------------------------------------------------------------------------------------------------------------------------
# END GAME LOOP
END_SCREEN_LOOP:
	jal CLEAR_SCREEN			# reset to black screen
	jal PAINT_GAME_OVER			# create game over screen
	monitor_end_key:
		# Monitor p or q key press
		lw $t8, 0xffff0000		# load the value at this address into $t8
		lw $t4, 0xffff0004		# load the ascii value of the key that was pressed
		
		beq $t4, 0x70, respond_to_p	# restart game when 'p' is pressed
		beq $t4, 0x71, respond_to_q	# exit game when 'q' is pressed
		j monitor_end_key		# keep monitoring for key response until one is chosen

# Tells OS the program ends
EXIT:	li $v0, 10
	syscall
	
#___________________________________________________________________________________________________________________________	
generate_asteroid:
	# randomly generates an obstacle with address stored in $a0
	push_reg_to_stack ($ra)
	jal RANDOM_OFFSET			# create random address offset
	add $a0, $v0, object_base_address	# store obstacle address = object_base_address + random offset
	addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
	jal PAINT_ASTEROID
	pop_reg_from_stack ($ra)	
	jr $ra
	
	
	
# REGENERATE OBSTACLES
regen_obs_1:	
	jal generate_asteroid
	addi $s5, $a0, 0
	j move_obs_2
regen_obs_2:
	jal generate_asteroid
	addi $s6, $a0, 0
	j move_obs_3
regen_obs_3:	
	jal generate_asteroid
	addi $s7, $a0, 0
	j move_heart	

regen_heart:
	jal generate_heart
	addi $s3, $a0, 0
	j EXIT_OBSTACLE_MOVE
#___________________________________________________________________________________________________________________________
# FUNCTION: COLLISION_DETECTOR
	# Registers Used
		# $t0: for loop indexer for plane_hitbox_loop
		# $t1: plane_hitbox_loop param. Specifies number of rows to offset from center (above and below) to check pixels
		# $t2: used to store current color at pixel
		# $t3: used in address offset calculations
		# $t9: temporary memory address storage
	# Registers Updated
		# $s0: update global health points variable (if collision with heart)
		# $s1: update global score variable (if collision with coin) 
COLLISION_DETECTOR:
	# Save used registers to stack
        	push_reg_to_stack ($t0)
        	push_reg_to_stack ($t1)
        	push_reg_to_stack ($t2)
        	push_reg_to_stack ($t3)
        	push_reg_to_stack ($t9)
        	push_reg_to_stack ($ra)

        check_plane_hitbox:			# check specific columns of plane for collision
        	# Column 26
        	addi $t0, $0, 0			# initialize for loop indexer;	i = 0 
        	addi $t1, $0, 2			# plane_hitbox_loop param. check __ rows from the center
        	addi $t9, $0, 104		# specify column offset = (column index * 4)
        	addi $t9, $t9, plane_center	# begin from row center of plane
        	add $t9, $t9, $a0		# store memory address for pixel at column index and at the center of the plane
        	jal plane_hitbox_loop
        	# Column 1
        	addi $t0, $0, 0			# initialize for loop indexer;	i = 0 
        	addi $t1, $0, 6		# plane_hitbox_loop param. check __ rows from the center
        	addi $t9, $0, 4		# specify column offset = (column index * 4)
        	addi $t9, $t9, plane_center	# begin from row center of plane
        	add $t9, $t9, $a0		# store memory address for pixel at column index and at the center of the plane
        	jal plane_hitbox_loop
        	# Column 23
        	addi $t0, $0, 0			# initialize for loop indexer;	i = 0 
        	addi $t1, $0, 2			# plane_hitbox_loop param. check __ rows from the center
        	addi $t9, $0, 92		# specify column offset = (column index * 4)
        	addi $t9, $t9, plane_center	# begin from row center of plane
        	add $t9, $t9, $a0		# store memory address for pixel at column index and at the center of the plane
        	jal plane_hitbox_loop 	
        	# Column 20
        	addi $t0, $0, 0			# initialize for loop indexer;	i = 0 
        	addi $t1, $0, 3			# plane_hitbox_loop param. check __ rows from the center
        	addi $t9, $0, 80		# specify column offset = (column index * 4)
        	addi $t9, $t9, plane_center	# begin from row center of plane
        	add $t9, $t9, $a0		# store memory address for pixel at column index and at the center of the plane
        	jal plane_hitbox_loop 	
        	# Column 18
        	addi $t0, $0, 0			# initialize for loop indexer;	i = 0 
        	addi $t1, $0, 16		# plane_hitbox_loop param. check __ rows from the center
        	addi $t9, $0, 72		# specify column offset = (column index * 4)
        	addi $t9, $t9, plane_center	# begin from row center of plane
        	add $t9, $t9, $a0		# store memory address for pixel at column index and at the center of the plane
        	jal plane_hitbox_loop
        	# Column 15
        	addi $t0, $0, 0			# initialize for loop indexer;	i = 0 
        	addi $t1, $0, 16		# plane_hitbox_loop param. check __ rows from the center
        	addi $t9, $0, 60		# specify column offset = (column index * 4)
        	addi $t9, $t9, plane_center	# begin from row center of plane
        	add $t9, $t9, $a0		# store memory address for pixel at column index and at the center of the plane
        	jal plane_hitbox_loop
        	
        	j exit_check_plane_hitbox
        	
        plane_hitbox_loop:
        	bgt $t0, $t1, exit_plane_hitbox_loop	# if i > 32, exit loop
        	addi $t3, $t0, 0			# store current row index
        	sll $t3, $t3, 10			# calculate row offset = (1024 * row index)
        	
        	subu $t9, $t9, $t3			# check pixel $t0 rows above
        	lw $t2, ($t9)				# load pixel colour at the address
		# if incorrect pixel color found
        	beq $t2, 0x896e5d, deduct_health	# if the pixel has asteroid colour, deduct heart by 1
        	beq $t2, 0xff0000, add_health		# if pixel of heart pickup color, add heart by 1
        	beq $t2, 0xbaba00, add_score		# if pixel of coin pickup color, add score by 1
        	
        	add $t9, $t9, $t3			# reset back to center
        	add $t9, $t9, $t3			# check pixel $t0 rows below
        	lw $t2, ($t9)				# load pixel colour at the address
		# if incorrect pixel color found
        	beq $t2, 0x896e5d, deduct_health	# if the pixel has asteroid colour, deduct heart by 1
        	beq $t2, 0xff0000, add_health		# if pixel of heart pickup color, add heart by 1
        	beq $t2, 0xbaba00, add_score		# if pixel of coin pickup color, add score by 1
        	
        	# repeat loop
        	addi $t0, $t0, 1			# update for loop indexer;	i += 1
        	subu $t9, $t9, $t3			# reset back to center
        	j plane_hitbox_loop
        	
        	exit_plane_hitbox_loop:			# return to previous instruction
        		jr $ra
        		
        deduct_health:
        	subi $s0, $s0, 1			# health -= 1
        	jal UPDATE_HEALTH			# update health on border
        	beq $s0, 0, END_SCREEN_LOOP		# Go to game over screen if 0 health
   		push_reg_to_stack ($a0)
   		push_reg_to_stack ($a1)
        	jal check_asteroid_distances		# the address of the closest asteroid will be stored in $a0
		addi $a1, $0, 0				# PAINT_ASTEROID param. Set to erase
		jal PAINT_ASTEROID			# erase current asteroid
		pop_reg_from_stack($a1)
        	pop_reg_from_stack($a0)
        	j exit_check_plane_hitbox		# exit collision check

        add_health:
        	beq $s0, 5, skip_add_health		# maximum health points is 5
        	addi $s0, $s0, 1			# health += 1
        	jal UPDATE_HEALTH			# update health on border
        	
        	skip_add_health:
        	push_reg_to_stack ($a0)			# stores away plane address
        	push_reg_to_stack ($a1)
		add $a0, $s3, $0			# PAINT_PICKUP_COIN param. Load base address
		addi $a1, $0, 0				# PAINT_PICKUP_COIN param. Set to erase
		jal PAINT_PICKUP_HEART			# erase current heart
		jal generate_heart			# redraw new heart
		pop_reg_from_stack($a1)
		pop_reg_from_stack($a0)			# retrieve plane address
        	
        	j exit_check_plane_hitbox		# exit collision check

        add_score:
        	jal UPDATE_SCORE			# score += 1
        	
		push_reg_to_stack ($a0)			# stores away plane address
		add $a0, $s2, $0			# PAINT_PICKUP_COIN param. Load base address
		addi $a1, $0, 0				# PAINT_PICKUP_COIN param. Set to erase
		jal PAINT_PICKUP_COIN
		jal generate_coin
		pop_reg_from_stack($a0)			# retrieve plane address
        	
        	j exit_check_plane_hitbox
	
	exit_check_plane_hitbox:			# return to previous instruction
        	pop_reg_from_stack($ra)
        	pop_reg_from_stack($t9)
        	
        	pop_reg_from_stack($t3)
        	
        	pop_reg_from_stack($t2)
        	pop_reg_from_stack($t1)
        	pop_reg_from_stack($t0)
        	jr $ra
# -------------------------------------------------------------------------------------------------------------------------
check_asteroid_distances:
	# check the distance of each asteroid in comparison to $t9 (the pixel which collision happened)
	# $t5 = $s5 - $t9
	# $t6 = $s6 - $t9
	# $t7 = $s7 - $t9
	sub $t5, $s5, $t9
	abs $t5, $t5
	sub $t6, $s6, $t9
	abs $t6, $t6
	sub $t7, $s7, $t9
	abs $t7, $t7
	
	blt $t5, $t6, L0
	blt $t6, $t7, L1
	addi $a0, $s7, 0
	j exit_loop
	
	
L0:	blt $t5, $t7, L2
	addi $a0, $s7, 0
	j exit_loop
	
L1:	blt $t6, $t7, L3
	addi $a0, $s7, 0
	j exit_loop
L2:	addi $a0, $s5, 0
	j exit_loop
L3: 	addi $a0, $s6, 0
	j exit_loop

exit_loop: jr $ra
#___________________________________________________________________________________________________________________________
# REGENERATE PICKUPS
generate_coin:	
	push_reg_to_stack($ra)
	jal RANDOM_OFFSET			# create random address offset
	add $a0, $v0, object_base_address	# store pickup coin address
	add $s2, $a0, $0			# PAINT_PICKUP_COIN param. Load base address
	addi $a1, $0, 1				# PAINT_PICKUP_COIN param. Set to paint
	jal PAINT_PICKUP_COIN	
	pop_reg_from_stack($ra)		
	jr $ra

generate_heart:
	push_reg_to_stack($ra)
	jal RANDOM_OFFSET			# create random address offset
	add $s3, $v0, object_base_address	# store pickup heart address
	addi $a0, $s3, 0			# PAINT_PICKUP_COIN param. Load base address
	addi $a1, $0, 1				# PAINT_PICKUP_COIN param. Set to paint
	jal PAINT_PICKUP_HEART
	pop_reg_from_stack($ra)			
	jr $ra
#___________________________________________________________________________________________________________________________
# ==USER INPUT==
USER_INPUT:
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
				beq $t4, 0x67, respond_to_g	# if 'g', branch to END_SCREEN_LOOP
				j EXIT_KEY_PRESS		# invalid key, exit the input checking stage
	
	respond_to_a:		ble $t5, 11, EXIT_KEY_PRESS	# the avatar is on left of screen, cannot move up
				subu $t0, $t0, column_increment	# set base position 1 pixel left
				ble $t6, 12, draw_new_avatar	# if after movement, avatar is now at border, draw
				subu $t0, $t0, column_increment	# set base position 1 pixel left
				ble $t6, 13, draw_new_avatar	# if after movement, avatar is now at border, draw
				subu $t0, $t0, column_increment	# set base position 1 pixel left
				j draw_new_avatar
	
	respond_to_w:		ble $t6, 18, EXIT_KEY_PRESS	# the avatar is on top of screen, cannot move up
				subu $t0, $t0, row_increment	# set base position 1 pixel up
				ble $t6, 19, draw_new_avatar	# if after movement, avatar is now at border, draw
				subu $t0, $t0, row_increment	# set base position 1 pixel up
				ble $t6, 20, draw_new_avatar	# if after movement, avatar is now at border, draw
				subu $t0, $t0, row_increment	# set base position 1 pixel up
				j draw_new_avatar
	
	respond_to_s:		bgt $t6, 206, EXIT_KEY_PRESS
				add $t0, $t0, row_increment	# set base position 1 pixel down
				bge $t6, 207, draw_new_avatar	# if after movement, avatar is now at border, draw
				add $t0, $t0, row_increment	# set base position 1 pixel down
				bge $t6, 208, draw_new_avatar	# if after movement, avatar is now at border, draw
				add $t0, $t0, row_increment	# set base position 1 pixel down
				j draw_new_avatar
	
	respond_to_d:		bgt $t5, 216, EXIT_KEY_PRESS
				add $t0, $t0, column_increment	# set base position 1 pixel right
				bge $t6, 217, draw_new_avatar	# if after movement, avatar is now at border, draw
				add $t0, $t0, column_increment	# set base position 1 pixel right
				bge $t6, 218, draw_new_avatar	# if after movement, avatar is now at border, draw
				add $t0, $t0, column_increment	# set base position 1 pixel right
				j draw_new_avatar
	
	draw_new_avatar:	addi $a1, $zero, 0		# set $a1 as 0
				jal PAINT_PLANE			# (erase plane) paint plane black
	
				la $a0, ($t0)			# load new base address to $a0
				addi $a1, $zero, 1		# set $a1 as 1
				jal PAINT_PLANE			# paint plane at new location
				j EXIT_KEY_PRESS
	# restart game
	respond_to_p:		jal CLEAR_SCREEN		
				j INITIALIZE
	# quit game
	respond_to_q:		jal CLEAR_SCREEN
				j EXIT
	# go to gameover screen
	respond_to_g:		j END_SCREEN_LOOP
	
	EXIT_KEY_PRESS:		j OBSTACLE_MOVE			# avatar finished moving, move to next stage
#___________________________________________________________________________________________________________________________
# ==FUNCTIONS==:
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
	# This will make the object spawn on the rightmost column of the screen at a random row
	# Store used registers to stack
	push_reg_to_stack ($a0)
	push_reg_to_stack ($a1)
	push_reg_to_stack ($s0)
	push_reg_to_stack ($s1)
	push_reg_to_stack ($s2)
	
	# Randomly generate row value
	li $v0, 42 		# Specify random integer
	li $a0, 0 		# from 0
	li $a1, 188 		# to 220
	syscall 		# generate and store random integer in $a0
	
	addi $s0, $0, row_increment	# store row increment in $s0
	mult $a0, $s0			# multiply row index to row increment
	mflo $s2			# store result in $s2

	#li $v0, 42 		# Specify random integer
	#li $a0, 0 		# from 0
	#li $a1, 22 		# to 220
	#syscall 		# Generate and store random integer in $a0
	#add $a0, $a0, 183

	# right most column	
	addi $a0, $0, 225
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
			check_color ($t1)			# updates color according to func. param. $a1
	                add $t2, $a0, $t3		# update to specific column from base address
	            	addi $t2, $t2, plane_center	# update to specified center axis
	           	sw $t1, ($t2)			# paint at center axis
	           	j UPDATE_COL			# end iteration
		PLANE_COL_1_2:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (6)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_3:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (4)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_4_7:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (2)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_8_13:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (3)		# update row for column
    			j LOOP_PLANE_ROWS		# paint in row
                	j UPDATE_COL			# end iteration
		PLANE_COL_14:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (8)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
        	        j UPDATE_COL			# end iteration
		PLANE_COL_15_18:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (16)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_19_21:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (3)		# update row for column
	            	j LOOP_PLANE_ROWS		# paint in row
	            	j UPDATE_COL			# end iteration
		PLANE_COL_22_24:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
			set_row_incr (2)		# update row for column
			j LOOP_PLANE_ROWS		# paint in row
			j UPDATE_COL			# end iteration
		PLANE_COL_25:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
			add $t2, $0, $0			# reinitialize temporary address store
			add $t2, $a0, $t3		# update to specific column from base address
			addi $t2, $t2, plane_center	# update to specified center axis
			sw $t1, ($t2)			# paint at center axis
			j UPDATE_COL			# end iteration
		PLANE_COL_26:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color ($t1)			# updates color according to func. param. $a1
			set_row_incr (2)		# update row for column
			j LOOP_PLANE_ROWS		# paint in row
			j UPDATE_COL			# end iteration
		PLANE_COL_27:
			addi $t1, $0, 0x803635		# change current color to dark red
			check_color ($t1)			# updates color according to func. param. $a1
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
# FUNCTION: PAINT LASER
	# Inputs
		# $a0: object base address
		# $a1: If 0, paint in black. Elif 1, paint in color specified otherwise.
		# $a2: random address offset
	# Registers Used
		# $t1: stores current color value
		# $t2: temporary memory address storage for current unit (in bitmap)
		# $t3: column index for 'for loop' LOOP_LASER_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $t4: row index for 'for loop' LOOP_LASER_ROWS
		# $t5: parameter for subfunction LOOP_LASER_ROWS. Will store # rows to paint from the center row outwards
		# $t8-9: used for multiplication/logical operations
PAINT_LASER:
	# Store used registers to stack
	push_reg_to_stack ($t1)
	push_reg_to_stack ($t2)
	push_reg_to_stack ($t3)
	push_reg_to_stack ($t4)
	push_reg_to_stack ($t5)
	push_reg_to_stack ($t8)
	push_reg_to_stack ($t9)
	# Initialize registers
	addi $t1, $0, 0x00cb0d			# change current color to bright freen
	add $t2, $0, $0				# holds temporary memory address
	add $t3, $0, $0				# holds 'column for loop' indexer
	add $t4, $0, $0				# holds 'row for loop' indexer

	check_color ($t1)			# updates color according to func. param. $a1

	# FOR LOOP: (through col)
	LOOP_LASER_COLS: bge $t3, 128, EXIT_PAINT_LASER
		addi $t5, $0, 2048				# $t5 = %y * row_increment		(lower 32 bits)
		j LOOP_LASER_ROWS			# paint in row
	UPDATE_LASER_COL:				# Update column value
		addi $t3, $t3, column_increment	# add 4 bits (1 byte) to refer to memory address for next row
		add $t4, $0, $0			# reinitialize index for LOOP_LASER_ROWS
		j LOOP_LASER_COLS
	EXIT_PAINT_LASER:
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
	LOOP_LASER_ROWS: bge $t4, $t5, UPDATE_LASER_COL	# returns when row index (stored in $t4) >= (number of rows to paint in) /2
		add $t2, $a0, $0			# start from base address
		add $t2, $t2, $t3			# update to specific column
		add $t2, $t2, $t4			# update to specific row
		add $t2, $t2, $a2			# update to random offset
		
		calculate_indices ($t2, $t8, $t9)	# get address indices. Store in $t8 and $t9
		within_borders ($t8, $t9, $t9)		# check within borders. Store boolean result in $t9 
		beq $t9, 0, SKIP_LASER_PAINT		# skip painting pixel if out of border
		sw $t1, ($t2)				# paint pixel
		SKIP_LASER_PAINT:
		# Updates for loop index
		addi $t4, $t4, row_increment		# t4 += row_increment
		j LOOP_LASER_ROWS				# repeats LOOP_LASER_ROWS
#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT_ASTEROID
	# Inputs
		# $a0: object base address
		# $a1: If 0, paint in black. Elif 1, paint in color specified otherwise.
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: row index for 'for loop' LOOP_ASTEROID_ROW
		# $s3: column index for 'for loop' LOOP_ASTEROID_COLUMN
		# $s4: parameter for subfunction LOOP_ASTEROID_COLUMN
		# $s5-6: used in calculating pixel address row/col indices
PAINT_ASTEROID:
	    # Store used registers in the stack
	    push_reg_to_stack ($ra)
	    push_reg_to_stack ($s0)
	    push_reg_to_stack ($s1)
	    push_reg_to_stack ($s2)
	    push_reg_to_stack ($s3)
	    push_reg_to_stack ($s4)
	    push_reg_to_stack ($s5)
	    push_reg_to_stack ($s6)
    
	    # Initialize registers
	    add $s0, $0, $0				# initialize current color to black
	    add $s1, $0, $0				# holds temporary memory address
	    add $s2, $0, $0	
	    add $s3, $0, $0
	    add $s4, $0, $0

		LOOP_ASTEROID_ROW: bge $s2, row_max, EXIT_PAINT_ASTEROID
				# Boolean Expressions: Paint in based on row index
			ASTEROID_COND:
					beq $s2, 0, ASTEROID_ROW_0
					beq $s2, 1024, ASTEROID_ROW_1
					beq $s2, 2048, ASTEROID_ROW_2
					beq $s2, 3072, ASTEROID_ROW_3
					beq $s2, 4096, ASTEROID_ROW_4
					beq $s2, 5120, ASTEROID_ROW_5
					beq $s2, 6144, ASTEROID_ROW_6
					beq $s2, 7168, ASTEROID_ROW_7
					beq $s2, 8192, ASTEROID_ROW_8

					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_0:
					setup_general_paint (0x000000, 0, 8, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x443a33, 8, 12, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x7d6556, 12, 16, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x7c6455, 16, 20, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x564941, 20, 24, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x36312e, 24, 28, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_1:
					setup_general_paint (0x271f1a, 0, 4, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x826858, 4, 8, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x896e5d, 8, 28, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x82695a, 28, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_2:
					setup_general_paint (0x7c6454, 0, 4, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x896e5d, 4, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x332923, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_3:
					setup_general_paint (0x896e5d, 0, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x876c5b, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_4:
					setup_general_paint (0x896e5d, 0, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x876d5c, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_5:
					setup_general_paint (0x896e5d, 0, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x615045, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_6:
					setup_general_paint (0x896e5d, 0, 28, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x866b5b, 28, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_7:
					setup_general_paint (0x000000, 0, 4, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x876c5b, 4, 8, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x896e5d, 8, 24, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x866c5c, 24, 28, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x8a6e5f, 28, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_8:
					setup_general_paint (0x000000, 0, 4, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x40342c, 4, 8, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x896e5d, 8, 16, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x69564b, 16, 20, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x342f2d, 20, 24, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x161515, 24, 28, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW

    	UPDATE_ASTEROID_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_ASTEROID_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_ASTEROID_COLUMN: bge $s3, $s4, EXIT_LOOP_ASTEROID_COLUMN	# branch to UPDATE_ASTEROID_COL; if column index >= last column index to paint
			add $s1, $a0, $0			# start from given address
			add $s1, $s1, $s3			# update to specific column
			add $s1, $s1, $s2			# update to specific row
			add $s1, $s1, $a2			# update to random offset
		
			calculate_indices ($s1, $s5, $s6)	# get address indices. Store in $s5-6
			within_borders ($s5, $s6, $s6)		# check within borders. Store boolean result in $s6
			beq $s6, 0, SKIP_ASTEROID_PAINT		# skip painting pixel if out of border
			sw $s0, ($s1)				# paint pixel
			SKIP_ASTEROID_PAINT:
        		# Updates for loop index
        		addi $s3, $s3, column_increment			# t4 += row_increment
        		j LOOP_ASTEROID_COLUMN				# repeats LOOP_ASTEROID_ROW
	    EXIT_LOOP_ASTEROID_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_ASTEROID:
        		# Restore used registers
        		pop_reg_from_stack ($s6)
        		pop_reg_from_stack ($s5)
	    		pop_reg_from_stack ($s4)
	    		pop_reg_from_stack ($s3)
	    		pop_reg_from_stack ($s2)
	    		pop_reg_from_stack ($s1)
	    		pop_reg_from_stack ($s0)
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction
#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT_PICKUP_HEART
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: row index for 'for loop' LOOP_PICKUP_HEART_ROW
		# $s3: column index for 'for loop' LOOP_PICKUP_HEART_COLUMN
		# $s4: parameter for subfunction LOOP_PICKUP_HEART_COLUMN
		# $s5-6: used in calculating pixel address row/col indices
PAINT_PICKUP_HEART:
	    # Store used registers in the stack
	    push_reg_to_stack ($ra)
	    push_reg_to_stack ($s0)
	    push_reg_to_stack ($s1)
	    push_reg_to_stack ($s2)
	    push_reg_to_stack ($s3)
	    push_reg_to_stack ($s4)
	    push_reg_to_stack ($s5)
	    push_reg_to_stack ($s6)
    
	    # Initialize registers
	    add $s0, $0, $0				# initialize current color to black
	    add $s1, $0, $0				# holds temporary memory address
	    add $s2, $0, $0	
	    add $s3, $0, $0
	    add $s4, $0, $0

		LOOP_PICKUP_HEART_ROW: bge $s2, row_max, EXIT_PAINT_PICKUP_HEART
				# Boolean Expressions: Paint in based on row index
			PICKUP_HEART_COND:
					beq $s2, 1024, PICKUP_HEART_ROW_1
					beq $s2, 2048, PICKUP_HEART_ROW_2
					beq $s2, 3072, PICKUP_HEART_ROW_3
					beq $s2, 4096, PICKUP_HEART_ROW_4
					beq $s2, 5120, PICKUP_HEART_ROW_5
					beq $s2, 6144, PICKUP_HEART_ROW_6

					j UPDATE_PICKUP_HEART_ROW
			PICKUP_HEART_ROW_1:
					setup_general_paint (0x000000, 0, 4, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xd63a3a, 4, 8, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xe92828, 8, 12, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x5b0000, 12, 16, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xe30000, 16, 20, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xd90000, 20, 24, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x000000, 24, 28, LOOP_PICKUP_HEART_COLUMN)
					j UPDATE_PICKUP_HEART_ROW
			PICKUP_HEART_ROW_2:
					setup_general_paint (0x5c0000, 0, 4, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xff4141, 4, 8, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xff0000, 8, 20, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xf60000, 20, 24, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x580000, 24, 28, LOOP_PICKUP_HEART_COLUMN)
					j UPDATE_PICKUP_HEART_ROW
			PICKUP_HEART_ROW_3:
					setup_general_paint (0x000000, 0, 4, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xff0000, 4, 20, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xe80000, 20, 24, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x000000, 24, 28, LOOP_PICKUP_HEART_COLUMN)
					j UPDATE_PICKUP_HEART_ROW
			PICKUP_HEART_ROW_4:
					setup_general_paint (0x000000, 0, 4, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x750000, 4, 8, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xff0000, 8, 20, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x710000, 20, 24, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x000000, 24, 28, LOOP_PICKUP_HEART_COLUMN)
					j UPDATE_PICKUP_HEART_ROW
			PICKUP_HEART_ROW_5:
					setup_general_paint (0x000000, 0, 8, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x710000, 8, 12, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xff0000, 12, 16, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x6b0000, 16, 20, LOOP_PICKUP_HEART_COLUMN)
					j UPDATE_PICKUP_HEART_ROW
			PICKUP_HEART_ROW_6:
					setup_general_paint (0x000000, 0, 12, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x310000, 12, 16, LOOP_PICKUP_HEART_COLUMN)
					j UPDATE_PICKUP_HEART_ROW

    	UPDATE_PICKUP_HEART_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_PICKUP_HEART_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_PICKUP_HEART_COLUMN: bge $s3, $s4, EXIT_LOOP_PICKUP_HEART_COLUMN	# branch to UPDATE_PICKUP_HEART_COL; if column index >= last column index to paint
        		addi $s1, $a0, 0				# Reinitialize t2; temporary address store
        		add $s1, $s1, $s2				# update to specific row from base address
        		add $s1, $s1, $s3				# update to specific column
        		sw $s0, ($s1)					# paint in value

			calculate_indices ($s1, $s5, $s6)	# get address indices. Store in $s5-6
			within_borders ($s5, $s6, $s6)		# check within borders. Store boolean result in $s6
			beq $s6, 0, SKIP_PICKUP_HEART_PAINT	# skip painting pixel if out of border
			sw $s0, ($s1)				# paint pixel
			SKIP_PICKUP_HEART_PAINT:

        		# Updates for loop index
        		addi $s3, $s3, column_increment			# t4 += row_increment
        		j LOOP_PICKUP_HEART_COLUMN				# repeats LOOP_PICKUP_HEART_ROW
	    EXIT_LOOP_PICKUP_HEART_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_PICKUP_HEART:
        		# Restore used registers
        		pop_reg_from_stack ($s6)
        		pop_reg_from_stack ($s5)
	    		pop_reg_from_stack ($s4)
	    		pop_reg_from_stack ($s3)
	    		pop_reg_from_stack ($s2)
	    		pop_reg_from_stack ($s1)
	    		pop_reg_from_stack ($s0)
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction
#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT_PICKUP_COIN
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: row index for 'for loop' LOOP_PICKUP_COIN_ROW
		# $s3: column index for 'for loop' LOOP_PICKUP_COIN_COLUMN
		# $s4: parameter for subfunction LOOP_PICKUP_COIN_COLUMN
PAINT_PICKUP_COIN:
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
	    add $s2, $0, $0	
	    add $s3, $0, $0
	    add $s4, $0, $0

		LOOP_PICKUP_COIN_ROW: bge $s2, row_max, EXIT_PAINT_PICKUP_COIN
				# Boolean Expressions: Paint in based on row index
			PICKUP_COIN_COND:
					beq $s2, 0, PICKUP_COIN_ROW_0
					beq $s2, 1024, PICKUP_COIN_ROW_1
					beq $s2, 2048, PICKUP_COIN_ROW_2
					beq $s2, 3072, PICKUP_COIN_ROW_3
					beq $s2, 4096, PICKUP_COIN_ROW_4
					beq $s2, 5120, PICKUP_COIN_ROW_5
					beq $s2, 6144, PICKUP_COIN_ROW_6
					beq $s2, 7168, PICKUP_COIN_ROW_7
					beq $s2, 8192, PICKUP_COIN_ROW_8

					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_0:
					setup_general_paint (0x000000, 0, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x494900, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 12, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x5c5c37, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x222100, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_1:
					setup_general_paint (0x000000, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x535300, 4, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x8f8f00, 12, 16, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x5b5b00, 16, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x8d8d00, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xd1d15c, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_2:
					setup_general_paint (0x303016, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 4, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x939300, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x212100, 12, 16, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 16, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x333300, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xa3a200, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xe2e1a6, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x878715, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_3:
					setup_general_paint (0x5f5f00, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 4, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x494900, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 12, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x161600, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x5e5f00, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xa9a853, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_4:
					setup_general_paint (0x5e5f00, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 4, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x2f2f00, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 12, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x161600, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x5e5f00, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xa6a66b, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_5:
					setup_general_paint (0x5e5f00, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 4, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x494900, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 12, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x161600, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x5e5f00, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x8c8c59, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_6:
					setup_general_paint (0x272700, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 4, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x333315, 12, 16, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 16, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x353600, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xa7a700, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x393a00, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_7:
					setup_general_paint (0x000000, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x494900, 4, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 8, 16, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x909000, 16, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x939300, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x777700, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_8:
					setup_general_paint (0x000000, 0, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x252500, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 12, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x202100, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW

    	UPDATE_PICKUP_COIN_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_PICKUP_COIN_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_PICKUP_COIN_COLUMN: bge $s3, $s4, EXIT_LOOP_PICKUP_COIN_COLUMN	# branch to UPDATE_PICKUP_COIN_COL; if column index >= last column index to paint
        		addi $s1, $a0, 0				# initialize from base address specified in $a0
        		add $s1, $s1, $s2				# update to specific row from base address
        		add $s1, $s1, $s3				# update to specific column
        		sw $s0, ($s1)					# paint in value

        		# Updates for loop index
        		addi $s3, $s3, column_increment			# t4 += row_increment
        		j LOOP_PICKUP_COIN_COLUMN				# repeats LOOP_PICKUP_COIN_ROW
	    EXIT_LOOP_PICKUP_COIN_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_PICKUP_COIN:
        		# Restore used registers
	    		pop_reg_from_stack ($s4)
	    		pop_reg_from_stack ($s3)
	    		pop_reg_from_stack ($s2)
	    		pop_reg_from_stack ($s1)
	    		pop_reg_from_stack ($s0)
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction
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
	push_reg_to_stack ($a0)
	push_reg_to_stack ($a2)
	push_reg_to_stack ($a3)
	push_reg_to_stack ($s0)
	push_reg_to_stack ($t0)
	push_reg_to_stack ($t1)
	push_reg_to_stack ($t2)
	push_reg_to_stack ($t3)
	
	# Initialize for loop indexer
	add $t0, $0, $0
	# Loop 5 times through all possible hearts. Subtract 1 from number of hearts each time.
	LOOP_HEART: beq $t0, 5, EXIT_UPDATE_HEALTH	# branch if $t0 = 5
		addi $t1, $0, column_increment	# store column increment temporarily
		addi $t2, $0, 12			
		mult $t1, $t2
		mflo $t1			
		mult $t0, $t1			# address offset = current index * (3 * column_increment)
		mflo $t3			
		addi $a0, $t3, display_base_address	# param. address to start painting at
		
		add $t2, $s0, $0		# store number of hit points
		sub $t2, $t2, $t0		# subtract number of hit points by current indexer
		sge $a3, $t2, 1			# param. for helper function to paint/erase heart. If number of hearts > curr index, paint in heart. Otherwise, erase.		
		jal PAINT_BORDER_HEART		# paint/erase heart
		
		# Update for loop indexer
		addi $t0, $t0, 1		# $t0 = $t0 + 1
		j LOOP_HEART
	# Restore previouos state of used registers
	EXIT_UPDATE_HEALTH:
		pop_reg_from_stack ($t3)
		pop_reg_from_stack ($t2)
		pop_reg_from_stack ($t1)
		pop_reg_from_stack ($t0)
		pop_reg_from_stack ($s0)
		
		pop_reg_from_stack ($a3)
		pop_reg_from_stack ($a2)
		pop_reg_from_stack ($a0)
		pop_reg_from_stack ($ra)
		jr $ra
#___________________________________________________________________________________________________________________________
# HELPER FUNCTION: PAINT_BORDER_HEART
	# Precondition: 
		# $a1 must be equal to 1 to avoid painting black.
	# Inputs:
		# $a0: address to start painting
		# $a3: whether to paint in or erase heart
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: column index for 'for loop' LOOP_BORDER_HEART_COLS
		# $s3: starting row index for 'for loop' LOOP_BORDER_HEART_ROWS
		# $s4: ending row index for 'for loop' LOOP_BORDER_HEART_ROWS
PAINT_BORDER_HEART:
	    # Store used registers in the stack
	    push_reg_to_stack ($ra)
	    push_reg_to_stack ($s0)
	    push_reg_to_stack ($s1)
	    push_reg_to_stack ($s2)
	    push_reg_to_stack ($s3)
	    push_reg_to_stack ($s4)
	    push_reg_to_stack ($a1)
    
	    # Initialize registers
	    add $s0, $0, $0				# initialize current color to black
	    add $s1, $0, $0				# holds temporary memory address
	    add $s2, $0, $0	
	    add $s3, $0, $0
	    add $s4, $0, $0
	    addi $a1, $0, 1				# precondition
        	
		LOOP_BORDER_HEART_ROW: bge $s2, row_max, EXIT_PAINT_BORDER_HEART
				# Boolean Expressions: Paint in based on row index
			BORDER_HEART_COND:
					beq $s2, 0, BORDER_HEART_ROW_0
					beq $s2, 1024, BORDER_HEART_ROW_1
					beq $s2, 2048, BORDER_HEART_ROW_2
					beq $s2, 3072, BORDER_HEART_ROW_3
					beq $s2, 4096, BORDER_HEART_ROW_4
					beq $s2, 5120, BORDER_HEART_ROW_5
					beq $s2, 6144, BORDER_HEART_ROW_6
					beq $s2, 7168, BORDER_HEART_ROW_7
					beq $s2, 8192, BORDER_HEART_ROW_8

					j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_0:
					setup_general_paint (0x7f7f7f, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x797979, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x4c4c4c, 8, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x666666, 12, 16, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x7f7f7f, 16, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x6b6b6b, 20, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x4c4c4c, 24, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x747474, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x7f7f7f, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_1:
					setup_general_paint (0x777777, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x6c2a2a, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xdc3131, 8, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x9f1616, 12, 16, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x545353, 16, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x900000, 20, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xd80000, 24, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x741e1e, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x737373, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_2:
					setup_general_paint (0x553131, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xed4343, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff4d4d, 8, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff0000, 12, 16, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xcc0000, 16, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xfb0000, 20, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff0000, 24, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xdb0000, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x502424, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_3:
					setup_general_paint (0x512424, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff3535, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff0000, 8, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xe50000, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x4f1717, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_4:
					setup_general_paint (0x5f5050, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xc30000, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff0000, 8, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xfa0000, 24, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xb40000, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x564343, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_5:
					setup_general_paint (0x757575, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x701e1e, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xf80000, 8, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff0000, 12, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xfe0000, 20, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xe50000, 24, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x6c1717, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x707070, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_6:
					setup_general_paint (0x7f7f7f, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x787878, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x671c1c, 8, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff0000, 12, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xe90000, 20, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x651414, 24, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x727272, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x7f7f7f, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_7:
					setup_general_paint (0x7f7f7f, 0, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x7b7b7b, 8, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x621c1c, 12, 16, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xe60000, 16, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x611616, 20, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x747474, 24, 28, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_8:
					setup_general_paint (0x7f7f7f, 0, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x7a7a7a, 12, 16, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x423333, 16, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x747373, 20, 24, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW

    	UPDATE_BORDER_HEART_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_BORDER_HEART_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_BORDER_HEART_COLUMN: bge $s3, $s4, EXIT_LOOP_BORDER_HEART_COLUMN	# branch to UPDATE_BORDER_HEART_COL; if column index >= last column index to paint
        		addi $s1, $a0, 0		# start from address specified in $a0
        		
        		addi $s1, $s1, 250880				# shift row to bottom outermost border (row index 245)
        		addi $s1, $s1, 52				# shift column to column index 13
        		add $s1, $s1, $a2				# add offset from parameter $a2
        		
        		add $s1, $s1, $s2				# update to specific row from base address
        		add $s1, $s1, $s3				# update to specific column
        		
			beq $a3, 1, PAINT_BORDER_HEART_PIXEL		# check if parameter specifies to erase/paint 
        			addi $s0, $0, 0x868686
        		PAINT_BORDER_HEART_PIXEL: sw $s0, ($s1)					# paint in value
        		# Updates for loop index
        		addi $s3, $s3, column_increment			# t4 += row_increment
        		j LOOP_BORDER_HEART_COLUMN			
	    EXIT_LOOP_BORDER_HEART_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_BORDER_HEART:
        		# Restore used registers
        		pop_reg_from_stack ($a1)
	    		pop_reg_from_stack ($s4)
	    		pop_reg_from_stack ($s3)
	    		pop_reg_from_stack ($s2)
	    		pop_reg_from_stack ($s1)
	    		pop_reg_from_stack ($s0)
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction
#___________________________________________________________________________________________________________________________
# FUNCTION: UPDATE_SCORE
	# Inputs
		# $s1: score counter
	# Used Registers:
		# $t0-1: used as temporary storages from division
UPDATE_SCORE:
	# Store used registers to stack
	push_reg_to_stack ($ra)
	push_reg_to_stack ($a0)
	push_reg_to_stack ($a1)
	push_reg_to_stack ($a2)
	push_reg_to_stack ($t0)
	push_reg_to_stack ($t1)
	
	# Find tenths and ones place value to display
	addi $t0, $0, 10
	div $s1, $t0			# divide current score by 10
	mflo $t0			# holds tenths place value of score
	mfhi $t1			# holds ones place value of score
	
	# Erase old score
	addi $a0, $0, display_base_address
	addi $a0, $a0, 2948
	addi $a1, $0, 0
	add $a2, $0, $t0		
	jal PAINT_NUMBER		# erase tenths digit
	addi $a0, $a0, 24
	addi $a1, $0, 0
	add $a2, $0, $t1
	jal PAINT_NUMBER		# erase ones digit
	
	# Find tenths and ones place value to display
	addi $s1, $s1, 1		# update new score
	addi $t0, $0, 10
	div $s1, $t0			# divide current score by 10
	mflo $t0			# holds tenths place value of score
	mfhi $t1			# holds ones place value of score
	
	# Paint new score
	addi $a0, $0, display_base_address
	addi $a0, $a0, 2948
	addi $a1, $0, 1
	add $a2, $0, $t0		
	jal PAINT_NUMBER
	addi $a0, $a0, 24
	addi $a1, $0, 1
	add $a2, $0, $t1
	jal PAINT_NUMBER
	
	# EXIT UPDATE_SCORE
	pop_reg_from_stack ($t1)	# Restore used registers
	pop_reg_from_stack ($t0)
	pop_reg_from_stack ($a2)
	pop_reg_from_stack ($a1)
	pop_reg_from_stack ($a0)
	pop_reg_from_stack ($ra)
	jr $ra				# return to previous instruction
#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT_NUMBER
	# Inputs
		# $a0: address to start painting number
		# $a1: whether to paint in or erase
		# $a2: number to paint in
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: column index for 'for loop' LOOP_NUMBER_COLUMN
		# $s3: row index for 'for loop' LOOP_NUMBER_ROW
		# $s4: parameter for subfunction LOOP_NUMBER_ROW
PAINT_NUMBER:
	    # Store used registers in the stack
	    push_reg_to_stack ($ra)
	    push_reg_to_stack ($s0)
	    push_reg_to_stack ($s1)
	    push_reg_to_stack ($s2)
	    push_reg_to_stack ($s3)
	    push_reg_to_stack ($s4)
	    # Initialize registers
	    add $s0, $0, 0xffffff			# initialize current color to white
	    add $s1, $0, $0				# holds temporary memory address
	    add $s2, $0, $0	
	    add $s3, $0, $0
	    add $s4, $0, $0
		LOOP_NUMBER_COLUMN: bge $s2, column_max, EXIT_PAINT_NUMBER
			# Boolean Expressions: Paint in based on column index
			NUMBER_COND:
					beq $s2, 0, NUMBER_COLUMN_0
					beq $s2, 4, NUMBER_COLUMN_1
					beq $s2, 8, NUMBER_COLUMN_2
					beq $s2, 12, NUMBER_COLUMN_3
					beq $s2, 16, NUMBER_COLUMN_4

					j UPDATE_NUMBER_COLUMN
			NUMBER_COLUMN_0:
					# number-specific painting conditionals
					beq $a2, 1, SKIP_LOWER_NUMBER_COLUMN_0	
					beq $a2, 3, SKIP_LOWER_NUMBER_COLUMN_0
					beq $a2, 7, SKIP_LOWER_NUMBER_COLUMN_0
					beq $a2, 2, SKIP_UPPER_NUMBER_COLUMN_0
					
					setup_general_paint (0xffffff, 1024, 4096, LOOP_NUMBER_ROW)
					SKIP_UPPER_NUMBER_COLUMN_0:
					
					beq $a2, 4, SKIP_LOWER_NUMBER_COLUMN_0
					beq $a2, 5, SKIP_LOWER_NUMBER_COLUMN_0
					beq $a2, 9, SKIP_LOWER_NUMBER_COLUMN_0
					
					setup_general_paint (0xffffff, 5120, 8192, LOOP_NUMBER_ROW)
					SKIP_LOWER_NUMBER_COLUMN_0:
					j UPDATE_NUMBER_COLUMN
			NUMBER_COLUMN_1:
					# number-specific painting conditionals
					beq $a2, 1, SKIP_BOTTOM_NUMBER_COLUMN_1
					beq $a2, 4, SKIP_TOP_NUMBER_COLUMN_1
					beq $a2, 6, SKIP_TOP_NUMBER_COLUMN_1
					
					setup_general_paint (0xffffff, 0, 1024, LOOP_NUMBER_ROW)
					SKIP_TOP_NUMBER_COLUMN_1:
					
					beq $a2, 0, SKIP_MIDDLE_NUMBER_COLUMN_1
					beq $a2, 7, SKIP_BOTTOM_NUMBER_COLUMN_1
					
					setup_general_paint (0xffffff, 4096, 5120, LOOP_NUMBER_ROW)
					SKIP_MIDDLE_NUMBER_COLUMN_1:
					
					beq $a2, 4, SKIP_BOTTOM_NUMBER_COLUMN_1
					beq $a2, 9, SKIP_BOTTOM_NUMBER_COLUMN_1
					
					setup_general_paint (0xffffff, 8192, 9216, LOOP_NUMBER_ROW)
					SKIP_BOTTOM_NUMBER_COLUMN_1:
					j UPDATE_NUMBER_COLUMN
			NUMBER_COLUMN_2:
					# number-specific painting conditionals
					beq $a2, 1, SKIP_BOTTOM_NUMBER_COLUMN_2
					beq $a2, 4, SKIP_TOP_NUMBER_COLUMN_2
					beq $a2, 6, SKIP_TOP_NUMBER_COLUMN_2
					
					setup_general_paint (0xffffff, 0, 1024, LOOP_NUMBER_ROW)
					SKIP_TOP_NUMBER_COLUMN_2:
					
					beq $a2, 0, SKIP_MIDDLE_NUMBER_COLUMN_2
					beq $a2, 7, SKIP_BOTTOM_NUMBER_COLUMN_2
					
					setup_general_paint (0xffffff, 4096, 5120, LOOP_NUMBER_ROW)
					SKIP_MIDDLE_NUMBER_COLUMN_2:
					
					beq $a2, 4, SKIP_BOTTOM_NUMBER_COLUMN_2
					beq $a2, 9, SKIP_BOTTOM_NUMBER_COLUMN_2
					
					setup_general_paint (0xffffff, 8192, 9216, LOOP_NUMBER_ROW)
					SKIP_BOTTOM_NUMBER_COLUMN_2:
					j UPDATE_NUMBER_COLUMN
			NUMBER_COLUMN_3:
					# number-specific painting conditionals
					beq $a2, 1, SKIP_BOTTOM_NUMBER_COLUMN_3
					beq $a2, 4, SKIP_TOP_NUMBER_COLUMN_3
					beq $a2, 6, SKIP_TOP_NUMBER_COLUMN_3
					
					setup_general_paint (0xffffff, 0, 1024, LOOP_NUMBER_ROW)
					SKIP_TOP_NUMBER_COLUMN_3:
					
					beq $a2, 0, SKIP_MIDDLE_NUMBER_COLUMN_3
					beq $a2, 7, SKIP_BOTTOM_NUMBER_COLUMN_3
					
					setup_general_paint (0xffffff, 4096, 5120, LOOP_NUMBER_ROW)
					SKIP_MIDDLE_NUMBER_COLUMN_3:
					
					beq $a2, 4, SKIP_BOTTOM_NUMBER_COLUMN_3
					beq $a2, 9, SKIP_BOTTOM_NUMBER_COLUMN_3
					
					setup_general_paint (0xffffff, 8192, 9216, LOOP_NUMBER_ROW)
					SKIP_BOTTOM_NUMBER_COLUMN_3:
					j UPDATE_NUMBER_COLUMN
			NUMBER_COLUMN_4:
					# number-specific painting conditionals
					beq $a2, 5, SKIP_UPPER_NUMBER_COLUMN_4
					beq $a2, 6, SKIP_UPPER_NUMBER_COLUMN_4
					
					setup_general_paint (0xffffff, 1024, 4096, LOOP_NUMBER_ROW)
					SKIP_UPPER_NUMBER_COLUMN_4:
					
					beq $a2, 2, SKIP_LOWER_NUMBER_COLUMN_4
					
					setup_general_paint (0xffffff, 5120, 8192, LOOP_NUMBER_ROW)
					SKIP_LOWER_NUMBER_COLUMN_4:
					j UPDATE_NUMBER_COLUMN

    	UPDATE_NUMBER_COLUMN:				# Update column value
    	    	addi $s2, $s2, column_increment
	        	j LOOP_NUMBER_COLUMN

    	# FOR LOOP: (through row)
    	# Paints in row from $s3 to $s4 at some column
    	LOOP_NUMBER_ROW: bge $s3, $s4, EXIT_LOOP_NUMBER_ROW			# branch to UPDATE_NUMBER_COL; if row index >= last row index to paint
        		addi $s1, $a0, 0					# start from base address given by $a0
        		add $s1, $s1, $s2					# update to specific column from base address
        		add $s1, $s1, $s3					# update to specific row
	    		beq $a1, 1, PAINT_NUMBER_PIXEL				# if $a1 == 0, set to erase
	    		addi $s0, $0, 0x868686					# update color to border gray 
	    		PAINT_NUMBER_PIXEL: sw $s0, ($s1)			# paint in value
	    		
        		# Updates for loop index
        		addi $s3, $s3, row_increment				# s3 += column_increment
        		j LOOP_NUMBER_ROW					# repeats LOOP_NUMBER_COLUMN
	    EXIT_LOOP_NUMBER_ROW:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_NUMBER:
        		# Restore used registers
	    		pop_reg_from_stack ($s4)
	    		pop_reg_from_stack ($s3)
	    		pop_reg_from_stack ($s2)
	    		pop_reg_from_stack ($s1)
	    		pop_reg_from_stack ($s0)
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction

#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT_BORDER_COIN
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: row index for 'for loop' LOOP_BORDER_COIN_ROW
		# $s3: column index for 'for loop' LOOP_BORDER_COIN_COLUMN
		# $s4: parameter for subfunction LOOP_BORDER_COIN_COLUMN
PAINT_BORDER_COIN:
	    # Store used registers in the stack
	    push_reg_to_stack ($ra)
	    push_reg_to_stack ($a0)
	    push_reg_to_stack ($a1)
	    push_reg_to_stack ($a2)
	    push_reg_to_stack ($s0)
	    push_reg_to_stack ($s1)
	    push_reg_to_stack ($s2)
	    push_reg_to_stack ($s3)
	    push_reg_to_stack ($s4)
    
	    # Initialize registers
	    add $s0, $0, $0				# initialize current color to black
	    add $s1, $0, $0				# holds temporary memory address
	    add $s2, $0, $0	
	    add $s3, $0, $0
	    add $s4, $0, $0
	    addi $a1, $0, 1				# precondition for painting

		LOOP_BORDER_COIN_ROW: bge $s2, row_max, EXIT_PAINT_BORDER_COIN
				# Boolean Expressions: Paint in based on row index
			BORDER_COIN_COND:
					beq $s2, 0, BORDER_COIN_ROW_0
					beq $s2, 1024, BORDER_COIN_ROW_1
					beq $s2, 2048, BORDER_COIN_ROW_2
					beq $s2, 3072, BORDER_COIN_ROW_3
					beq $s2, 4096, BORDER_COIN_ROW_4
					beq $s2, 5120, BORDER_COIN_ROW_5
					beq $s2, 6144, BORDER_COIN_ROW_6
					beq $s2, 7168, BORDER_COIN_ROW_7
					beq $s2, 8192, BORDER_COIN_ROW_8

					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_0:
					setup_general_paint (0x868686, 0, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x494900, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 12, 16, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xbaba00, 16, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x5c5c37, 24, 28, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_1:
					setup_general_paint (0x868686, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x535300, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb8b800, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x939300, 12, 16, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x5d5d00, 16, 20, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x8f8f16, 20, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xd8d854, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xd1d15c, 28, 32, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_2:
					setup_general_paint (0x868686, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x979700, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x40403a, 12, 16, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 16, 20, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x4c4c46, 20, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xaaa900, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xe1e0a6, 28, 32, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x717131, 32, 36, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_3:
					setup_general_paint (0x5f5f00, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x494900, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 12, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x5e5e00, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xbaba00, 28, 32, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x787854, 32, 36, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 36, 44, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xffffff, 44, 48, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 48, 52, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xffffff, 52, 56, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_4:
					setup_general_paint (0x5e5f00, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x2f2f00, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 12, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x595b1b, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb8b800, 28, 32, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x74745d, 32, 36, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 36, 48, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xffffff, 48, 52, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 52, 56, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_5:
					setup_general_paint (0x5e5f00, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xbaba00, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x484800, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 12, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x5b5c00, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb8b800, 28, 32, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x6e6e57, 32, 36, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 36, 44, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xffffff, 44, 48, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 48, 52, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xffffff, 52, 56, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_6:
					setup_general_paint (0x868686, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb8b800, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xafaf00, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x343416, 12, 16, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 16, 20, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x333400, 20, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xa5a500, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 28, 32, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x414224, 32, 36, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_7:
					setup_general_paint (0x868686, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x494900, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb2b200, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb5b500, 12, 16, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x909000, 16, 20, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x939300, 20, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x777700, 28, 32, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_8:
					setup_general_paint (0x868686, 0, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb6b600, 12, 16, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 16, 20, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb3b300, 20, 24, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW

    	UPDATE_BORDER_COIN_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_BORDER_COIN_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_BORDER_COIN_COLUMN: bge $s3, $s4, EXIT_LOOP_BORDER_COIN_COLUMN	# branch to UPDATE_BORDER_COIN_COL; if column index >= last column index to paint
        		addi $s1, $0, display_base_address			# Reinitialize t2; temporary address store
        		add $s1, $s1, $s2				# update to specific row from base address
        		add $s1, $s1, $s3				# update to specific column
        		addi $s1, $s1, 2888				# add specified offset
                	sw $s0, ($s1)					# paint in value

        		# Updates for loop index
        		addi $s3, $s3, column_increment			# t4 += row_increment
        		j LOOP_BORDER_COIN_COLUMN				# repeats LOOP_BORDER_COIN_ROW
	    EXIT_LOOP_BORDER_COIN_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_BORDER_COIN:
       		# Paint 00 as initial score
		addi $a0, $0, display_base_address
		addi $a0, $a0, 2948
		addi $a1, $0, 1
		addi $a2, $0, 0		
		jal PAINT_NUMBER
		addi $a0, $a0, 24
		addi $a1, $0, 1
		addi $a2, $0, 0
		jal PAINT_NUMBER
       	
        	# Restore used registers
    		pop_reg_from_stack ($s4)
    		pop_reg_from_stack ($s3)
    		pop_reg_from_stack ($s2)
    		pop_reg_from_stack ($s1)
    		pop_reg_from_stack ($s0)
    		pop_reg_from_stack ($a2)
    		pop_reg_from_stack ($a1)
    		pop_reg_from_stack ($a0)
       		pop_reg_from_stack ($ra)
       		jr $ra						# return to previous instruction
#___________________________________________________________________________________________________________________________
# FUNCTION: CLEAR_SCREEN
	# Registers Used
		# $t1: stores current color value
		# $t2: temporary memory address storage for current unit (in bitmap)
		# $t3: column index for 'for loop' LOOP_CLEAR_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $t4: row index for 'for loop' LOOP_CLEAR_ROWS
		# $t5: parameter for subfunction LOOP_CLEAR_ROWS. Will store # rows to paint from the center row outwards
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
# FUNCTION: PAINT_GAME_OVER
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: row index for 'for loop' LOOP_GAME_OVER_ROW
		# $s3: column index for 'for loop' LOOP_GAME_OVER_COLUMN
		# $s4: parameter for subfunction LOOP_GAME_OVER_COLUMN
PAINT_GAME_OVER:
	j EXIT
