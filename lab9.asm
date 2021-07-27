# Full Names: Stanley Bryan Z. Hua, Jun Ni Du
# UTORid: huastanl, dujun1

# Bitmap Display Configuration:
# - Unit column in pixels: 4
# - Unit row in pixels: 4
# - Display column in pixels: 1024
# - Display row in pixels: 1024
# - Base Address for Display: 0x10008000 ($gp)
#___________________________________________________________________________________________________________________________
# ==CONSTANTS==:
.eqv UNIT_WIDTH 4
.eqv UNIT_HEIGHT 4

.eqv column_increment 4			# 4 memory addressess will always refer to 1 unit (32 bits or 4 bytes)
.eqv row_increment 1024			# [(display_row) / UNIT_HEIGHT] * column_increment

.eqv column_max 1024			# column_increment * (display_column) / UNIT_WIDTH			# NOTE: Always equal to row_increment
.eqv row_max 262144			# row_increment * (display_row) / UNIT_HEIGHT

.eqv center_row 15360			# offset for center of plane. = 15 bytes * row_increment
#___________________________________________________________________________________________________________________________
.data
displayAddress: .word 0x10008000
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
		# set $t5 from lower 32 bits
		mflo $t5			
	.end_macro
	# MACRO: Check whether to color normally or black. Update $t1 accordingly.
		# $t1: contains color to be painted
		# $a1: boolean to determine if color $t1 or black. 
		# NOTE: $t1 == $t1 if $a1 == 1. Otherwise, $t1 == 0.
	.macro check_color
		mult $a1, $t1
		mflo $t1
	.end_macro
#___________________________________________________________________________________________________________________________
# ==INITIALIZATION==:
lw $a0, displayAddress 				# load base address of BitMap to temp. base address for plane
addi $a1, $zero, 1
jal PAINT_PLANE					# paint plane at $a0

# main game loop
MAIN_LOOP:

	AVATAR_MOVE:
		jal check_key_press			# check for keyboard input and redraw avatar accordingly

	OBSTACLE_MOVE:
		j MAIN_LOOP
	
	
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
	# Initialize registers
	add $t1, $0, $0				# initialize current color to black
	add $t2, $0, $0				# holds temporary memory address
	add $t3, $0, $0				# holds 'column for loop' indexer
	add $t4, $0, $0				# holds 'row for loop' indexer
	
	# FOR LOOP (through the bitmap columns)
	LOOP_PLANE_COLS: bge $t3, column_max, EXIT_PLANE_PAINT	# repeat loop until column index = column 31 (4096)
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
	            	addi $t2, $t2, center_row	# update to specified center axis
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
			addi $t2, $t2, center_row	# update to specified center axis
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
			addi $t2, $t2, center_row	# update to specified center axis
			sw $t1, ($t2)			# paint at center axis
			j UPDATE_COL			# end iteration

		UPDATE_COL: addi $t3, $t3, column_increment	# add 4 bits (1 byte) to refer to memory address for next row row
			j LOOP_PLANE_COLS		# repeats LOOP_PLANE_COLS
	
	EXIT_PLANE_PAINT:
		jr $ra					# return to previous instruction before PAINT_PLANE was called.
	
	# FOR LOOP: (through row)
	# Paints in symmetric row at given column (stored in t2) 	# from center using row (stored in $t5)
	LOOP_PLANE_ROWS: bge $t4, $t5, UPDATE_COL	# returns to LOOP_PLANE_COLS when index (stored in $t4) >= center_row (row)t2
		add $t2, $0, $0				# Reinitialize t2; temporary address store
		add $t2, $a0, $t3			# update to specific column from base address
		addi $t2, $t2, center_row		# update to specified center axis
		
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
			
			addi $a1, $zero, 0		# set $a1 as 0 			
			jal PAINT_PLANE			# paint current plane black
			
			lw $t4, 0xffff0004		# load the ascii value of the key that was pressed
			beq $t4, 0x61, respond_to_a 	# ASCII code of 'a' is 0x61 or 97 in decimal
			beq $t4, 0x77, respond_to_w	# ASCII code of 'w'
			beq $t4, 0x73, respond_to_s	# ASCII code of 's'
			beq $t4, 0x64, respond_to_d	# ASCII code of 'd'
			j EXIT_KEY_PRESS		# invalid key, exit the input checking stage
			
respond_to_a:		la $t0, ($a0)			# load base address to $t0
			subu $t0, $t0, column_increment	# set base position 1 pixel left
			la $a0, ($t0)			# load new base address to $a0
			addi $a1, $zero, 1		# set $a1 as 1
			jal PAINT_PLANE			# paint plane at new location
			j EXIT_KEY_PRESS

respond_to_w:		la $t0, ($a0)			# load base address to $t0
			subu $t0, $t0, row_increment	# set base position 1 pixel up
			la $a0, ($t0)			# load new base address to $a0
			addi $a1, $zero, 1		# set $a1 as 1
			jal PAINT_PLANE			# paint plane at new location
			j EXIT_KEY_PRESS
			
respond_to_s:		la $t0, ($a0)			# load base address to $t0
			addu $t0, $t0, row_increment	# set base position 1 pixel down
			la $a0, ($t0)			# load new base address to $a0 
			addi $a1, $zero, 1		# set $a1 as 1
			jal PAINT_PLANE			# paint plane at new location
			j EXIT_KEY_PRESS
			
respond_to_d:		la $t0, ($a0)			# load base address to $t0
			addu $t0, $t0, column_increment	# set base position 1 pixel right
			la $a0, ($t0)			# load new base address to $a0 
			addi $a1, $zero, 1		# set $a1 as 1
			jal PAINT_PLANE			# paint plane at new location
			j EXIT_KEY_PRESS
					
EXIT_KEY_PRESS:		j OBSTACLE_MOVE			# avatar finished moving, move to next stage
#___________________________________________________________________________________________________________________________
