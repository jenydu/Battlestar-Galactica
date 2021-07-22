#####################################################################
#
# CSC258 Summer 2021 Assembly Final Project
# University of Toronto
#
# Student: Jun Ni Du, 1006217130, dujun1
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8 (update this as needed)
# - Unit height in pixels: 8 (update this as needed)
# - Display width in pixels: 256 (update this as needed)
# - Display height in pixels: 256 (update this as needed)
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1/2/3 (choose the one that applies)
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

.eqv BASE_ADDRESS 0x10008000
.text


update_spaceship_position:	li $t0, BASE_ADDRESS # $t0 stores the base address for display
				li $t1, 0xff0000 # $t1 stores the red colour code
				li $t2, 0x00ff00 # $t2 stores the green colour code
				li $t3, 0x0000ff # $t3 stores the blue colour code
				sw $t1, 0($t0) # paint the first (top-left) unit red.
				sw $t2, 4($t0) # paint the second unit on the first row green. Why $t0+4?
				sw $t3, 128($t0) # paint the first unit on the second row blue. Why +128?





check_key_press:	li $t9, 0xffff0000
			lw $t8, 0($t9)
			beq $t8, 1, keypress_happened
keypress_happened:	lw $t2, 4($t9) # this assumes $t9 is set to 0xfff0000 from before
			beq $t2, 0x61, respond_to_a # ASCII code of 'a' is 0x61 or 97 in decimal
			beq $t2, 0x77, respond_to_w
			beq $t2, 0x73, respond_to_s
			beq $t2, 0x64, respond_to_d
			
respond_to_a:	la $t0, BASE_ADDRESS
		addi $t0, $t0, 4
		j update_spaceship_position
			
respond_to_w:
			
respond_to_s:
			
respond_to_d:
						
			
			
			
			
			
			
			
			
			
li $v0, 10 # terminate the program gracefully
syscall

