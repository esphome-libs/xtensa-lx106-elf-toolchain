/* Minimal entry point: call main, then stop. */
	.text
	.literal_position
	.global	_start
	.type	_start, @function
	.align	4
_start:
	call0	main
1:
	j	1b
	.size	_start, . - _start
