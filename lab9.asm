# Full Name: Stanley Bryan Z. Hua
# UTORid: huastanl


# CREATE ASSEMBLY GAME AVATAR


# Bitmap Display Configuration:
# - Unit width in pixels: 4
# - Unit height in pixels: 4
# - Display width in pixels: 1024
# - Display height in pixels: 1024
# - Base Address for Display: 0x10008000 ($gp)

# t0: Stores base address
# t1: Stores current color value
# t2: Temporary memory address storage for current unit (in bitmap)
# t3: width index for 'for loop' LOOP_WIDTH					# Stores (delta) width to add to memory address to move columns right in the bitmap
# t4: height index for 'for loop' CREATE_HEIGHT

# t8-9: used for multiplication operations

# a0: function CREATE_HEIGHT parameter. Stores height to paint in for column (from the center axis outwards symmetrically)

.eqv UNIT_WIDTH 4
.eqv UNIT_HEIGHT 4

.eqv width_increment 4			# 4 memory addressess will always refer to 1 unit (32 bits or 4 bytes)
.eqv height_increment 1024		# [(display_height) / UNIT_HEIGHT] * width_increment

.eqv width_max 1024			# width_increment * (display_width) / UNIT_WIDTH			# NOTE: Always equal to height_increment
.eqv height_max 262144			# height_increment * (display_height) / UNIT_HEIGHT

.eqv center_height 131072		# = height_max / 2


.data
displayAddress: .word 0x10008000

.text	

# ==MACROS==:
	# To specify unit's height diff from the center in CREATE_WIDTH, set $a0 to height_increment * %y
	.macro set_height_incr(%y)
		# temporarily store height_increment and y-unit value
		addi $t8, $0, height_increment	
		addi $t9, $0, %y
		mult $t8, $t9
		# set $a0 from lower 32 bits
		mflo $a0			
	.end_macro


# ==INITIALIZATION==:
lw $t0, displayAddress 			# holds base address for display
add $t1, $t3, $0			# initialize current color to blue
add $t2, $0, $0				# holds temporary memory address
add $t3, $0, $0				# holds 'width for loop' indexer
add $t4, $0, $0				# holds 'height for loop' indexer



# FOR LOOP (through the bitmap width)
LOOP_WIDTH: bge $t3, width_max, EXIT	# repeat loop until width index = column 31 (4096)
	add $t4, $0, $0			# reinitialize t4; index for CREATE_HEIGHT
	
	# SWITCH CASES: paint in height based on column value
	beq $t3, 124, COL_1
	beq $t3, 120, COL_2
	beq $t3, 116, COL_3
	beq $t3, 112, COL_4_6
	beq $t3, 108, COL_4_6
	beq $t3, 104, COL_4_6
	beq $t3, 100, COL_7_9
	beq $t3, 96, COL_7_9
	beq $t3, 92, COL_7_9
	beq $t3, 88, COL_10_13
	beq $t3, 84, COL_10_13
	beq $t3, 80, COL_10_13
	beq $t3, 76, COL_10_13
	beq $t3, 72, COL_14
	beq $t3, 68, COL_15_20
	beq $t3, 64, COL_15_20
	beq $t3, 60, COL_15_20
	beq $t3, 56, COL_15_20
	beq $t3, 52, COL_15_20
	beq $t3, 48, COL_15_20
	beq $t3, 44, COL_21_24
	beq $t3, 40, COL_21_24
	beq $t3, 36, COL_21_24
	beq $t3, 32, COL_21_24
	beq $t3, 28, COL_25
	beq $t3, 24, COL_26_27
	beq $t3, 20, COL_26_27
	beq $t3, 16, COL_28
	
	# If not of specified heights, end iteration without doing anything.
	j UPDATE_WIDTH				
	
	COL_1:
		addi $t1, $0, 0x803635		# change current color to dark red
		add $t2, $0, $0			# reinitialize temporary address store
		add $t2, $t0, $t3		# update to specific width from base address
		addi $t2, $t2, center_height	# update to specified center axis
		sw $t1, ($t2)			# paint at center axis
		j UPDATE_WIDTH			# end iteration
	COL_2:  
		addi $t1, $0, 0x255E90		# change current color to dark blue
		set_height_incr (2)		# update height for column
		jal CREATE_HEIGHT		# paint in height
		j UPDATE_WIDTH			# end iteration
	COL_3:
		addi $t1, $0, 0x29343D		# change current color to dark gray
		add $t2, $0, $0			# reinitialize temporary address store
		add $t2, $t0, $t3		# update to specific width from base address
		addi $t2, $t2, center_height	# update to specified center axis
		sw $t1, ($t2)			# paint at center axis
		j UPDATE_WIDTH			# end iteration
	COL_4_6:
		addi $t1, $0, 0x29343D		# change current color to dark gray
		set_height_incr (2)		# update height for column
		jal CREATE_HEIGHT		# paint in height
		j UPDATE_WIDTH			# end iteration
	COL_7_9:
		addi $t1, $0, 0x29343D		# change current color to dark gray
    		set_height_incr (3)		# update height for column
            	jal CREATE_HEIGHT		# paint in height
            	j UPDATE_WIDTH			# end iteration
	COL_10_13:
		addi $t1, $0, 0x255E90		# change current color to dark blue
    		set_height_incr (16)		# update height for column
    		jal CREATE_HEIGHT		# paint in height
                j UPDATE_WIDTH			# end iteration
	COL_14:
		addi $t1, $0, 0x29343D		# change current color to dark gray
    		set_height_incr (8)		# update height for column
    		jal CREATE_HEIGHT		# paint in height
                j UPDATE_WIDTH			# end iteration
	COL_15_20:
		addi $t1, $0, 0x29343D		# change current color to dark gray
    		set_height_incr (3)		# update height for column
    		jal CREATE_HEIGHT		# paint in height
                j UPDATE_WIDTH			# end iteration
	COL_21_24:
		addi $t1, $0, 0x29343D		# change current color to dark gray
    		set_height_incr (2)			# update height for column
    		jal CREATE_HEIGHT		# paint in height
                j UPDATE_WIDTH			# end iteration
	COL_25:
		addi $t1, $0, 0x29343D		# change current color to dark gray
    		set_height_incr (4)		# update height for column
    		jal CREATE_HEIGHT		# paint in height
                j UPDATE_WIDTH			# end iteration
	COL_26_27:
		addi $t1, $0, 0x255E90		# change current color to dark blue
    		set_height_incr (6)		# update height for column
    		jal CREATE_HEIGHT		# paint in height
                j UPDATE_WIDTH			# end iteration
	COL_28:
		addi $t1, $0, 0x255E90		# change current color to dark blue
                add $t2, $t0, $t3		# update to specific width from base address
            	addi $t2, $t2, center_height	# update to specified center axis
           	sw $t1, ($t2)			# paint at center axis
           	j UPDATE_WIDTH			# end iteration

UPDATE_WIDTH: addi $t3, $t3, width_increment	# add 4 bits (1 byte) to refer to memory address for next row height
	j LOOP_WIDTH				# repeats LOOP_HEIGHT


# Tells OS the program ends
EXIT:	li $v0, 10
	syscall



# FOR LOOP: (through height)				
# Paints in symmetric height at given width (stored in t2) 	# from center using height (stored in $a0)
CREATE_HEIGHT: bge $t4, $a0, END_HEIGHT		# returns to LOOP_WIDTH when index (stored in $t4) >= center_height (height)t2
	add $t2, $0, $0				# Reinitialize t2; temporary address store
	add $t2, $t0, $t3			# update to specific width from base address
	addi $t2, $t2, center_height		# update to specified center axis
	
	add $t2, $t2, $t4			# update to positive (delta) height
	sw $t1, ($t2)				# paint at positive (delta) height
	
	sub $t2, $t2, $t4			# update back to specified center axis
	sub $t2, $t2, $t4			# update to negative (delta) height
	sw $t1, ($t2)				# paint at negative (delta) height

	# Updates for loop index
	addi $t4, $t4, height_increment		# t4 += height_increment
	j CREATE_HEIGHT				# repeats CREATE_HEIGHT

END_HEIGHT:
	jr $ra					# return to previous instruction
