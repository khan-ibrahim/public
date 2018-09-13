#IBRAHIM KHAN

##################################
# Part 1 - String Functions
##################################

is_whitespace:
	# $a0 char
	
	beqz $a0 is_whitespace_true	#evaluate null
	
	li $t0 10	#evaluate new line
	beq $a0 $t0 is_whitespace_true
	
	li $t0 32	#evaluate space
	beq $a0 $t0 is_whitespace_true
	
	add $v0 $0 $0	#return 0 (false)
	jr $ra
	
	is_whitespace_true:	#return 1 (true)
	li $v0 1
	jr $ra

cmp_whitespace:
	# $a0 char, #a1 char
	
	#inflate stack, store values
	addi $sp $sp -8
	sw $a1 0($sp)
	sw $ra 4($sp)
	
	jal is_whitespace	#evaluate first character
	beqz $v0 cmp_whitespace_ret	#return if first character evaluated 0
	
	lw $a0 0($sp)	#prepare and evaluate second character
	jal is_whitespace
	
	cmp_whitespace_ret:
	#restore values, deflate stack
	lw $ra 4($sp)
	addi $sp $sp 8
	
	jr $ra

strcpy:
	# $a0 src, $a1 dest, $a2 num bytes
	
	ble $a0 $a1 end	#terminate if src is less than or equal to dest
	
	strcpy_loop:
		beqz $a2 end	#ends if num bytes = 0
		lb $t0 0($a0)	#reads
		sb $t0 0($a1)	#writes
		
		addi $a0 $a0 1	#advances pointers
		addi $a1 $a1 1
		
		addi $a2 $a2 -1	#decrement num bytes
	j strcpy_loop
	
	end:
	jr $ra

strlen:
	# $a0 string address
	
	addi $sp $sp -12	#inflate stack
	sw $s0 0($sp)	#store s registers
	sw $s1 4($sp)	
	sw $ra 8($sp)	#store $ra
	
	add $s1 $a0 $0	#save string address
	add $s0 $0 $0	#zero len counter
	
	strlen_loop:
		lb $a0 0($s1)	#load current char
		jal is_whitespace	#evalute whitespace char
		bnez $v0 strlen_ret	#ret if whitespace
		
		addi $s0 $s0 1	#advance char counter
		addi $s1 $s1 1	#advance address
		
		j strlen_loop
	
	strlen_ret:
	add $v0 $s0 $0	#load return value

	lw $s0 0($sp)	#restore s registers
	lw $s1 4($sp)	
	lw $ra 8($sp)	#restore $ra
	addi $sp $sp 12	#deflate stack

	jr $ra

##################################
# Part 2 - vt100 MMIO Functions
##################################

set_state_color:
	# $a0 state struct address, $a1 color, $a2 category (0 default, 1 hightlight), $a3 mode (0 both, 1 only fg, 2 only bg)
	
	add $a0 $a0 $a2	#set address to relevant byte based on category
	lb $t0 0($a0)	#load relevant byte
	
	li $t1 2
	beq $a3 $t1 set_state_color_bg	#branch if only bg
	
	#set fg
	li $t1 0xf0
	and $t0 $t0 $t1	#clear foreground
	add $t0 $t0 $a1	#set foreground
	sb $t0 0($a0)	#store saved value
	
	bnez $a0 end	#jr #ra if done
	
	set_state_color_bg:	#set bg
	li $t1 0x0f
	and $t0 $t0 $t1	#clear background
	sll $a1 $a1 4	#shift color to bg position
	add $t0 $t0 $a1	#set background
	sb $t0 0($a0)	#store saved value

	jr $ra

save_char:
	# $a0 state struct address, $a1 char
	
	lb $t1 2($a0)	#get row (x)
	lb $t2 3($a0)	#get column (y)
	
	li $t0 0xffff0000	#load array start address 
	
	li $t3 160
	mul $t1 $t1 $t3	#calc offset for rows (x)
	add $t0 $t0 $t1	#offset
	
	li $t3 2
	mul $t2 $t2 $t3	#calc offset for columns
	add $t0 $t0 $t2	#offset
	
	sb $a1 0($t0)	#store char

	jr $ra

reset:
	# $a0 state struct address, $a1 color_only
	
	li $t0 0xffff0000	#load array start address
	li $t1 0xffff0fa0	#load first array out of bounds address
	
	lb $t2 0($a0)	#load default color
	bnez $a1 reset_OnlyColorLoop	
	
	reset_loop:	#reset both loop
		sb $0 0($t0)	#set character 0
		sb $t2 1($t0)	#set color to default value
		addi $t0 $t0 2	#advance address to next cell
		bge $t0 $t1 end	#terminate upon exhausting cells
		j reset_loop
	
	reset_OnlyColorLoop:	#reset only color loop
		sb $t2 1($t0)	#set color to default value
		addi $t0 $t0 2	#advance address to next cell
		bge $t0 $t1 end	#terminate upon exhausting cells
		j reset_OnlyColorLoop

	jr $ra

clear_line:
	# $a0 x (row), $a1 y (column), $a2 color
	
	li $t0 0xffff0000	#load array start address 
	
	li $t2 160
	mul $a0 $a0 $t2	#calc offset for rows (x)
	add $t0 $t0 $a0	#offset

	li $t1 160
	add $t1 $t0 $t1	#out of row bounds address
	
	li $t2 2
	mul $a1 $a1 $t2	#calc offset for columns
	add $t0 $t0 $a1	#offset
	
	clear_line_loop:
		sb $0 0($t0)	#zero char
		sb $a2 1($t0)	#set color
		addi $t0 $t0 2	#advance cell pointer
		bge $t0 $t1 end	#terminate on line end
		j clear_line_loop
		
	jr $ra

set_cursor:
	# $a0 state struct address, $a1 x (row), $a2 y (column), $a3 initial

	addi $sp $sp -16	#inflate stack
	sw $s0 0($sp)	#save s registers
	sw $s1 4($sp)
	sw $s2 8($sp)
	sw $ra 12($sp)	#save $ra

	add $s0 $a0 $0	#store struct address
	add $s1 $a1 $0	#store new x
	add $s2 $a2 $0	#store new y
	
	bnez $a3 set_cursor_afterClearInitial	#evaluate skip clearing
	
	lb $a0 2($s0)	#load current cursor coords to clear
	lb $a1 3($s0)
	jal invert_cell_cursor_color	#clear current cursor
	
	set_cursor_afterClearInitial:
	sb $s1 2($s0)	#set state to new row
	sb $s2 3($s0)	#set state to new column
	
	add $a0 $s1 $0	#load values for new cursor
	add $a1 $s2 $0
	jal invert_cell_cursor_color	#invert new cursor

	lw $s0 0($sp)	#restore s registers
	lw $s1 4($sp)
	lw $s2 8($sp)
	lw $ra 12($sp)	#restore ra
	addi $sp $sp 16	#deflate stack
	
	jr $ra

move_cursor:
	# $a0 state address, $a1 direction char
	
	addi $sp $sp -4	#inflate stack
	sw $ra 0($sp)	#store $ra
	
	lb $t0 2($a0)	#load cursor x
	lb $t1 3($a0)
	
	li $t2 104	#check for left (h)
	beq $a1 $t2 move_cursor_left
	li $t2 106	#check for down (j)
	beq $a1 $t2 move_cursor_down
	li $t2 107	#check for down (j)
	beq $a1 $t2 move_cursor_up
	li $t2 108	#check for right (l)
	beq $a1 $t2 move_cursor_right
	
	move_cursor_left:	#h 
	beqz $t1 move_cursor_end	#terminate if in first column
	add $a1 $t0 $0	#load desired row
	addi $a2 $t1 -1	#decrement and load desired column
	add $a3 $0 $0	#set initial parameter 0
	jal set_cursor
	j move_cursor_end
	
	move_cursor_down:	#j
	li $t2 24
	beq $t0 $t2 move_cursor_end	#terminate if in last row
	addi $a1 $t0 1	#increase and load desired row
	add $a2 $t1 $0	#load desired column
	add $a3 $0 $0	#set initial parameter 0
	jal set_cursor
	j move_cursor_end
	
	move_cursor_up:	#k
	beqz $t0 move_cursor_end	#terminate if in first row
	addi $a1 $t0 -1	#decrement and load desired row
	add $a2 $t1 $0	#load desired column
	add $a3 $0 $0	#set initial parameter 0
	jal set_cursor
	j move_cursor_end
	
	move_cursor_right:	#k
	li $t2 79
	beq $t1 $t2 move_cursor_end	#terminate if in last column
	add $a1 $t0 $0	#load desired row
	addi $a2 $t1 1	#increase and load desired column
	add $a3 $0 $0	#set initial parameter 0
	jal set_cursor
	#j move_cursor_end
	
	move_cursor_end:
	lw $ra 0($sp)	#recall $ra
	addi $sp $sp 4	#deflate stack
	
	jr $ra

mmio_streq:
	# $a0 mmio string, $a1 compareTo string
	
	addi $sp $sp -12	#inflate stack
	sw $s0 0($sp)	#store s registers
	sw $s1 4($sp)
	sw $ra 8($sp)	#store $ra
	
	add $s0 $a0 $0	#save mmio string address
	add $s1 $a1 $0	#save compareToString address
	
	mmio_streq_loop:
		lb $a0 0($s0)	#load char from current mmio cell
		lb $a1 0($s1)	#load current char from compareTo string
		
		jal cmp_whitespace
		bnez $v0 mmio_streq_succeed	#succeed if both strings terminated		
		lb $t0 0($s0)	#load char from current mmio cell
		lb $t1 0($s1)	#load current char from compareTo string
		bne $t0 $t1 mmio_streq_fail	#fail if characters not equal
		
		addi $s0 $s0 2	#advance mmio cell
		addi $s1 $s1 1	#advance compareToString char
		j mmio_streq_loop

	mmio_streq_fail:
	add $v0 $0 $0	#load 0 in return reguster
	j mmio_streq_end
	
	mmio_streq_succeed:
	li $v0 1	#load 1 in return register
	
	mmio_streq_end:
	
	lw $s0 0($sp)	#restore s registers
	lw $s1 4($sp)
	lw $ra 8($sp)	#restore $ra1144444
	addi $sp $sp 12	#deflate stack
	
	jr $ra

get_cell_address:
	# $a0 x (row), $a1 y (column)
	#returns starting address of two byte VT100 cell at given coords
	
	li $v0 0xffff0000	#load array start address 
	
	li $t0 160
	mul $a0 $a0 $t0	#calc offset for rows (x)
	add $v0 $v0 $a0	#offset
	
	li $t0 2
	mul $a1 $a1 $t0	#calc offset for columns
	add $v0 $v0 $a1	#offset
	
	jr $ra	#return

invert_cell_cursor_color:
	# $a0 x (row), $a1 y (column)
	# inverts bold bit of cell at given coord
	
	addi $sp $sp -4	#inflate stack
	sw $ra 0($sp)	#save $ra

	jal get_cell_address
	lb $t0 1($v0)	#load color byte
	li $t1 0x88
	
	xor $t0 $t1 $t0	#invert bold bits
	sb $t0 1($v0)	#writes inverted color
	
	lw $ra 0($sp)	#recall $ra
	addi $sp $sp 4	#deflate stack
	
	jr $ra	#return

##################################
# Part 3 - UI/UX Functions
##################################

handle_nl:
	# 4a0 state struct
	
	addi $sp $sp -8	#inflate stack
	sw $s0 0($sp)	#store s registers
	sw $ra 4($sp)	#store $ra
	
	add $s0 $a0 $0	#save state struct
	
	lb $a0 2($s0)	#load cursor x
	lb $a1 3($s0)	#load cursor y
	lb $a2 0($s0)	#load default color
	jal clear_line	#clear rest of line (including cursor)
	
	add $a0 $s0 $0	#load state struct address
	li $a1 0xa	#load new line char
	jal save_char	#write newline char to current target
	
	add $a0 $s0 $0	#load state struct address
	li $a1 106	#load j for down direction in $a1
	jal move_cursor	#move to next line
	
	add $a0 $s0 $0	#load state struct address
	lb $a1 2($s0)	#load current x (row)
	add $a2 $0 $0	#load column 0
	add $a3 $0 $0	#load 0 for initial
	jal set_cursor	#set cursor to start of line
	
	lw $s0 0($sp)	#restore s register
	lw $ra 4($sp)	#restore $ra
	addi $sp $sp 8	#shrink stack
	
	jr $ra

handle_backspace:
	# $a0 state struct
	
	addi $sp $sp -8	#inflate stack
	sw $s0 0($sp)	#store s register
	sw $ra 4($sp)	#store $ra
	
	add $s0 $a0 $0	#save state struct address
	
	li $t0 79	#load last column index
	lb $a1 3($s0)	#load cursor y
	bge $a1 $t0 handle_backspace_nullifyLast	#skip copy if on last column
	
	lb $a0 2($s0)	#load cursor x
	jal get_cell_address	#get address of cell
	
	li $t0 79	#load last column index
	lb $t1 3($s0)	#load cursor y
	sub $a2 $t0 $t1	#calc length of remaining line 
	li $t0 2
	
	mul $a2 $a2 $t0	#calc and load num bytes of cells of remaining line
	add $a1 $v0 $0	#set current cursor as copy dest
	add $a0 $a1 $t0	#set next cell and onwards as copy src
	jal strcpy
	
	handle_backspace_nullifyLast:
	lb $a0 2($s0)	#load cursor x	
	li $a1 79	#load max last y coord
	lb $a2 0($s0)	#load default color
	jal clear_line	#reset last cell of row
	
	lw $s0 0($sp)	#restore s register
	lw $ra 4($sp)	#restore $ra
	addi $sp $sp 8	#shrink stack
	
	jr $ra

highlight:
	# $a0 x (row), $a1 y (column), $a2 color, $a3 num cells
	
	li $t0 0xffff0000	#load array start address 
	
	li $t1 160
	mul $a0 $a0 $t1	#calc offset for rows (x)
	add $t0 $t0 $a0	#offset
	
	li $t1 2
	mul $a1 $a1 $t1	#calc offset for columns
	add $t0 $t0 $a1	#offset

	mul $t1 $a3 $t1	#calc num bytes of cells
	add $t1 $t0 $t1	#calc out of bounds address
	
	highlight_loop:
		sb $a2 1($t0)	#set color of current cell
		addi $t0 $t0 2	#advance to next cell
		bge $t0 $t1 end	#terminate on end
	j highlight_loop

	jr $ra

highlight_all:
	# $a0 color, $a1 string[] dict

	addi $sp $sp -24	#inflate stack
	sw $s0 0($sp)	#store s registers
	sw $s1 4($sp)	
	sw $s2 8($sp)	
	sw $s3 12($sp)	
	sw $s4 16($sp)	#dict word counter
	sw $ra 20($sp)	#store $ra

	add $s0 $a0 $0	#save color
	add $s1 $a1 $0	#save dict adddress

	li $s2 0xffff0000	#load initial cell display address
	li $s3 0xffff0fa0	#load out of bounds address
	add $s4 $s1 $0	#load initial dict address
			
	highlight_all_displayLoop:	
		bge $s2 $s3 highlight_all_end	#terminate on display exhaustion
		lb $a0 0($s2)	#load current cell char
		jal is_whitespace	#evaulate whitespace
		beqz $v0 highlight_all_wordLoop	#initate dict compare if not whitespace
		addi $s2 $s2 2	#advance cell pointer
		j highlight_all_displayLoop
		
		highlight_all_wordLoop:
			lw $a1 0($s4)	#load current dict pointer
			beqz $a1 highlight_all_wordLoop_exit	#exit if dict exhuasted
			add $a0 $s2 $0	#load current cell
			jal mmio_streq	#evaluate equality		
			bnez $v0 highlight_all_wordLoop_highlight	#highlight if equal
			addi $s4 $s4 4	#move to next dict pointer
			j highlight_all_wordLoop
	
		highlight_all_wordLoop_highlight:
			lw $a0 0($s4)	#load dict hit
			jal strlen
			add $a3 $v0 $0	#load dict hit length
			add $a2 $s0 $0	#load color
			
			addi $t0 $s2 0x00010000	#gain coords from address
			li $t1 2
			div $t0 $t1
			mflo $t0
			li $t1 80
			div $t0 $t1
			mflo $a0
			mfhi $a1
			
			jal highlight
			
			
		highlight_all_wordLoop_exit:
			add $s4 $s1 $0	#load initial dict address
		
		highlight_all_findNotWhitespaceLoop:
			bge $s2 $s3 highlight_all_end	#terminate on display exhaustion
			lb $a0 0($s2)	#load current cell char
			jal is_whitespace	#evaluate whitespace
			bnez $v0 highlight_all_displayLoop	#advance to whitespace checker if whitespace
			addi $s2 $s2 2	#advance cell pointer
			j highlight_all_findNotWhitespaceLoop
	
	highlight_all_end:
	
	lw $s0 0($sp)	#restore s registers
	lw $s1 4($sp)	
	lw $s2 8($sp)
	lw $s3 12($sp)
	lw $s4 16($sp)
	lw $ra 20($sp)	#restore $ra
	addi $sp $sp 24	#shrink stack
	
	jr $ra
