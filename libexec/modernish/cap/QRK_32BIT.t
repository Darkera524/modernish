#! /shell/quirk/test/for/moderni/sh
# -*- mode: sh; -*-
# See the file LICENSE in the main modernish directory for the licence.

# QRK_32BIT: the shell only has 32-bit arithmetics. Since every modern
# system these days supports 64-bit long integers even on 32-bit kernels, we
# can now count this as a quirk.
# mksh has it (on purpose). For 64-bit arithmetics, run lksh instead.
{ _Msh_test=$((2147483650)); } 2>/dev/null
case ${_Msh_test} in
( 2147483650 ) return 1 ;;
( -2147483646 ) ;;	# number wrapped around
( 2147483647 ) ;;	# number capped at maximum
( 214748365 ) ;;	# number truncated after 9 digits (zsh)
( * )	echo "QRK_32BIT.t: Undiscovered bug with 32-bit arithmetic limitation! (${_Msh_test})" 1>&2
	return 2 ;;
esac
