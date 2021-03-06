#! /bin/sh

# Interactive installer for modernish.
# https://github.com/modernish/modernish
#
# This installer is itself an example of a modernish script (from '. modernish' on).
# For more conventional examples, see share/doc/modernish/examples
#
# --- begin license ---
# Copyright (c) 2016 Martijn Dekker <martijn@inlv.org>, Groningen, Netherlands
# 
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
# --- end license ---

# ensure sane default permissions
umask 022

usage() {
	echo "usage: $0 [ -n ] [ -s SHELL ] [ -f ] [ -d INSTALLROOT ] [ -D PREFIX ]"
	echo "	-n: non-interactive operation"
	echo "	-s: specify default shell to execute modernish"
	echo "	-f: force unconditional installation on specified shell"
	echo "	-d: specify root directory for installation"
	echo "	-D: extra destination directory prefix (for packagers)"
	exit 1
} 1>&2

# parse options
unset -v opt_relaunch opt_n opt_d opt_s opt_f opt_D
case ${1-} in
( --relaunch )
	opt_relaunch=''
	shift ;;
( * )	unset -v MSH_SHELL ;;
esac
while getopts 'ns:fd:D:' opt; do
	case $opt in
	( \? )	usage ;;
	( n )	opt_n='' ;;
	( s )	opt_s=$OPTARG ;;
	( f )	opt_f='' ;;
	( d )	opt_d=$OPTARG ;;
	( D )	opt_D=$OPTARG ;;
	esac
done
case $((OPTIND - 1)) in
( $# )	;;
( * )	usage ;;
esac

# validate options
case ${opt_s+s} in
( s )	OPTARG=$opt_s
	opt_s=$(command -v "$opt_s")
	if ! test -x "$opt_s"; then
		echo "$0: shell not found: $OPTARG" >&2
		exit 1
	fi
	case ${MSH_SHELL-} in
	( "$opt_s" ) ;;
	( * )	MSH_SHELL=$opt_s
		export MSH_SHELL
		echo "Relaunching ${0##*/} with $MSH_SHELL..." >&2
		exec "$MSH_SHELL" "$0" --relaunch "$@" ;;
	esac ;;
esac
case ${opt_D+s} in
( s )	opt_D=$(mkdir -p "$opt_D" && cd "$opt_D" && pwd && echo X) && opt_D=${opt_D%?X} || exit ;;
esac

# Since we're running the source-tree copy of modernish and not the
# installed copy, manually make sure that $MSH_SHELL is a shell with POSIX
# 'kill -s SIGNAL' syntax and without FTL_PARONEARG, FTL_NOPPID, FTL_FNREDIR,
# FTL_PSUB, FTL_BRACSQBR, FTL_DEVCLOBBR, FTL_NOARITH, FTL_UPP or FTL_UNSETFAIL.
# These selected fatal bug tests should lock out most release versions that
# cannot run modernish. Search these IDs in bin/modernish for documentation.
test_cmds='IFS= && set -fCu && set 1 2 3 && set "$@" && [ "$#" -eq 3 ] &&
f() { echo x; } >&2 && case $(f 2>/dev/null) in ("")
t=barbarfoo; case ${t##bar*}/${t%%*} in (/)
t=]abcd; case c in (*["$t"]*) case e in (*[!"$t"]*)
set -fuC && set -- >/dev/null && kill -s 0 "$$" "$@" && j=0 &&
unset -v _Msh_foo$((((j+=6*7)==0x2A)>0?014:015)) && echo "$PPID"
;; esac;; esac;; esac;; esac'
case ${MSH_SHELL-} in
( '' )	for MSH_SHELL in sh /bin/sh ash dash yash lksh mksh ksh93 bash zsh5 zsh ksh pdksh oksh; do
		if ! command -v "$MSH_SHELL" >/dev/null 2>&1; then
			MSH_SHELL=''
			continue
		fi
		case $("$MSH_SHELL" -c "$test_cmds" 2>/dev/null) in
		( '' | *[!0123456789]* )
			MSH_SHELL=''
			continue ;;
		( * )	MSH_SHELL=$(command -v "$MSH_SHELL")
			case ${opt_n+n} in
			( n )	# If we're non-interactive, relaunch early so that our shell is known.
				export MSH_SHELL
				echo "Relaunching ${0##*/} with $MSH_SHELL..." >&2
				exec "$MSH_SHELL" "$0" --relaunch "$@" ;;
			esac
			break ;;
		esac
	done
	case $MSH_SHELL in
	( '' )	echo "Fatal: can't find any suitable POSIX compliant shell!" 1>&2
		exit 125 ;;
	esac
	case $(eval "$test_cmds" 2>/dev/null) in
	( '' | *[!0123456789]* )
		echo "Relaunching ${0##*/} with $MSH_SHELL..." >&2
		exec "$MSH_SHELL" "$0" "$@" ;;
	esac ;;
( * )	case $("$MSH_SHELL" -c "$test_cmds" 2>/dev/null) in
	( '' | *[!0123456789]* )
		echo "Shell $MSH_SHELL is not a suitable POSIX compliant shell." >&2
		exit 1 ;;
	esac ;;
esac

# Let test initialisations of modernish in other shells use this result.
export MSH_SHELL

# find directory install.sh resides in; assume everything else is there too
case $0 in
( */* )	srcdir=${0%/*} ;;
( * )	srcdir=. ;;
esac
srcdir=$(cd "$srcdir" && pwd && echo X) || exit
srcdir=${srcdir%?X}
cd "$srcdir" || exit

# commands for test-initialising modernish
# test thisshellhas(): a POSIX reserved word, POSIX special builtin, and POSIX regular builtin
test_modernish='. bin/modernish || exit
thisshellhas --rw=if --bi=set --bi=wait || exit 1 "Failed to determine a working thisshellhas() function."'

# try to test-initialize modernish in a subshell to see if we can run it
#
# On ksh93, subshells are normally handled specially without forking. Depending
# on the version of ksh93, bugs cause various things to leak out of the
# subshell into the main shell (e.g. aliases, see BUG_ALSUBSH). This may
# prevent the proper init of modernish later. To circumvent this problem, force
# the forking of a real subshell by making it a background job.
if (eval '[[ -n ${.sh.version+s} ]]') 2>/dev/null; then
	(eval "$test_modernish") & wait "$!"
else
	(eval "$test_modernish")
fi || {
	echo
	echo "install.sh: The shell executing this script can't run modernish. Try running"
	echo "            it with another POSIX shell, for instance: dash install.sh"
	exit 3
} 1>&2

# load modernish and some modules
. bin/modernish
use safe -w BUG_APPENDC			# IFS=''; set -f -u -C (declaring compat with bug)
use var/setlocal			# setlocal is like zsh anonymous functions
use var/arith/cmp			# arithmetic comparison shortcuts: eq, gt, etc.
use loop/select -w BUG_SELECTRPL \
	-w BUG_SELECTEOF		# ksh/zsh/bash 'select' now on all POSIX shells (declare mksh & zsh bug workarounds)
use sys/base/mktemp
use sys/base/which
use sys/base/readlink
use sys/term/readkey
use sys/dir/traverse			# for 'traverse'
use var/string				# for 'trim' and 'append'

# abort program if any of these commands give an error
# (the default error condition is '> 0', exit status > 0;
# for some commands, such as grep, this is different)
# also make sure the system default path is used to find them (-p)
harden -p cd
harden -p -t mkdir
harden -p cp
harden -p chmod
harden -p ln
harden -p -e '> 1' LC_ALL=C grep
harden -p sed
harden -p sort
harden -p paste
harden -p fold

# (Does the script below seem like it makes lots of newbie mistakes with not
# quoting variables and glob patterns? Think again! Using the 'safe' module
# disables field splitting and globbing, along with all their hazards: most
# variable quoting is unnecessary and glob patterns can be passed on to
# commands such as 'match' without quoting. In the one instance where this
# script needs field splitting, it is enabled locally using 'setlocal', and
# splits only on the one needed separator character. Globbing is not needed
# or enabled at all.)

# (style note: modernish library functions never have underscores or capital
# letters in them, so using underscores or capital letters is a good way to
# avoid potential conflicts with future library functions, as well as an
# easy way for readers of your code to tell them apart.)

# function that lets the user choose a shell from /etc/shells or provide their own path,
# verifies that the shell can run modernish, then relaunches the script with that shell
pick_shell_and_relaunch() {
	clear_eol=$(tput el)	# clear to end of line

	# find shells, eliminating duplicates (symlinks, hard links) and non-compatible shells
	which -as sh ash bash dash yash zsh zsh5 ksh ksh93 pdksh mksh lksh oksh
	shells_to_test=$REPLY	# newline-separated list of shells to test
	# supplement 'which' results with any additional shells from /etc/shells
	if can read /etc/shells; then
		shells_to_test=${shells_to_test}${CCn}$(grep -E '^/[a-z/][a-z0-9/]+/[a-z]*sh[0-9]*$' /etc/shells |
			grep -vE '(csh|/esh|/psh|/posh|/fish|/r[a-z])')
	fi

	setlocal REPLY PS3 valid_shells='' IFS=$CCn; do
		# Within this 'setlocal' block: local positional parameters; local variables REPLY, PS3 and
		# valid_shells; field splitting on newline (IFS=$CCn).
		# Field splitting on newline means that any expansions that may contain a newline must be quoted
		# (unless they are to be split, of course -- like in the 'for' and 'select' statements).

		for shell in $shells_to_test; do
			for alreadyfound in $valid_shells; do
				if is -L samefile $shell $alreadyfound; then
					continue 2
				fi
			done
			readlink -fs $shell && not endswith $REPLY /busybox && shell=$REPLY
			put "${CCr}Testing shell $shell...$clear_eol"
			if can exec $shell && MSH_SHELL=$shell $shell -c $test_modernish 2>/dev/null; then
				append "--sep=$CCn" valid_shells $shell
			fi
		done

		putln "${CCr}Please choose a default shell for executing modernish scripts.$clear_eol"

		if thisshellhas BUG_SELECTRPL; then
			# On mksh with this bug, "select" doesn't store non-menu input in $REPLY,
			# so install.sh can't offer this feature.
			PS3='Shell number: '
		else
			putln	"Either pick a shell from the menu, or enter the command name or path" \
				"of another POSIX-compliant shell at the prompt."
			PS3='Shell number, command name or path: '
		fi

		if empty "$valid_shells"; then
			valid_shells='(no POSIX-compliant shell found; enter path)'
		else
			valid_shells=$(putln "$valid_shells" | sort)
		fi
		REPLY='' # BUG_SELECTEOF workaround (zsh)
		select msh_shell in $valid_shells; do
			if empty $msh_shell && not empty $REPLY; then
				# a path or command instead of a number was given
				msh_shell=$REPLY
				not contains $msh_shell / && which -s $msh_shell && msh_shell=$REPLY
				readlink -fs $msh_shell	&& not endswith $REPLY /busybox && msh_shell=$REPLY
				if not so || not is present $msh_shell; then
					putln "$msh_shell does not seem to exist. Please try again."
				elif match $msh_shell *[!$SHELLSAFECHARS]*; then
					putln "The path '$msh_shell' contains" \
						"non-shell-safe characters. Try another path."
				elif not can exec $msh_shell; then
					putln "$msh_shell does not seem to be executable. Try another."
				elif not $msh_shell -c $test_modernish; then
					putln "$msh_shell was found unable to run modernish. Try another."
				else
					break
				fi
			else
				# a number was chosen: already tested, so assume good
				break
			fi
		done
		empty $REPLY && exit 2 Aborting.	# user pressed ^D
	endlocal

	putln "* Relaunching installer with $msh_shell" ''
	export MSH_SHELL=$msh_shell
	exec $msh_shell $srcdir/${0##*/} --relaunch "$@"
}

# Simple function to ask a question of a user.
yesexpr=$(PATH=$DEFPATH command locale yesexpr 2>/dev/null) && trim yesexpr \" || yesexpr=^[yY]
noexpr=$(PATH=$DEFPATH command locale noexpr 2>/dev/null) && trim noexpr \" || noexpr=^[nN]
ask_q() {
	REPLY=''
	put "$1 (y/n) "
	readkey -E "($yesexpr|$noexpr)" REPLY || exit 2 Aborting.
	putln $REPLY
	ematch $REPLY $yesexpr
}

# Function to generate 'readonly -f' for bash and yash.
mk_readonly_f() {
	putln "${CCt}readonly -f \\"
	sed -n 's/^[[:blank:]]*\([a-zA-Z_][a-zA-Z_]*\)()[[:blank:]]*{.*/\1/p
		s/^[[:blank:]]*eval '\''\([a-zA-Z_][a-zA-Z_]*\)()[[:blank:]]*{.*/\1/p' \
			$1 |
		grep -Ev '(^showusage$|^echo$|^_Msh_initExit$|^_Msh_test|^_Msh_have$|^_Msh_tmp|^_Msh_.*dummy)' |
		sort -u |
		paste -sd' ' - |
		fold -sw64 |
		sed "s/^/${CCt}${CCt}/; \$ !s/\$/\\\\/; \$ s/\$/ \\\\/"
	putln "${CCt}${CCt}2>/dev/null"
}

# Function to identify the version of this shell, if possible.
identify_shell() {
	case ${YASH_VERSION+ya}${KSH_VERSION+k}${SH_VERSION+k}${ZSH_VERSION+z}${BASH_VERSION+ba}${POSH_VERSION+po} in
	( ya )	putln "* This shell identifies itself as yash version $YASH_VERSION" ;;
	( k )	isset KSH_VERSION || KSH_VERSION=$SH_VERSION
		case $KSH_VERSION in
		( '@(#)MIRBSD KSH '* )
			putln "* This shell identifies itself as mksh version ${KSH_VERSION#*KSH }." ;;
		( '@(#)LEGACY KSH '* )
			putln "* This shell identifies itself as lksh version ${KSH_VERSION#*KSH }." ;;
		( '@(#)PD KSH v'* )
			putln "* This shell identifies itself as pdksh version ${KSH_VERSION#*KSH v}."
			if endswith $KSH_VERSION 'v5.2.14 99/07/13.2'; then
				putln "  (Note: many different pdksh variants carry this version identifier.)"
			fi ;;
		( Version* )
			putln "* This shell identifies itself as AT&T ksh93 v${KSH_VERSION#V}." ;;
		( * )	putln "* WARNING: This shell has an unknown \$KSH_VERSION identifier: $KSH_VERSION." ;;
		esac ;;
	( z )	putln "* This shell identifies itself as zsh version $ZSH_VERSION." ;;
	( ba )	putln "* This shell identifies itself as bash version $BASH_VERSION." ;;
	( po )	putln "* This shell identifies itself as posh version $POSH_VERSION." ;;
	( * )	if (eval '[[ -n ${.sh.version+s} ]]') 2>/dev/null; then
			eval 'putln "* This shell identifies itself as AT&T ksh v${.sh.version#V}."'
		else
			putln "* This is a POSIX-compliant shell without a known version identifier variable."
		fi ;;
	esac
	putln "  Modernish detected the following bugs, quirks and/or extra features on it:"
	thisshellhas --show | sort | paste -s -d ' ' - | fold -s -w 78 | sed 's/^/  /'
}

# --- Main ---

if isset opt_n || isset opt_s || isset opt_relaunch; then
	msh_shell=$MSH_SHELL
	putln "* Modernish version $MSH_VERSION, now running on $msh_shell".
	identify_shell
else
	putln "* Welcome to modernish version $MSH_VERSION."
	identify_shell
	pick_shell_and_relaunch "$@"
fi

putln "* Running modernish test suite on $msh_shell ..."
if $msh_shell bin/modernish --test -qq; then
	putln "* Tests passed. No bugs in modernish were detected."
elif isset opt_n && not isset opt_f; then
	putln "* ERROR: modernish has some bug(s) in combination with this shell." \
	      "         Add the '-f' option to install with this shell anyway." >&2
	exit 1
else
	putln "* WARNING: modernish has some bug(s) in combination with this shell." \
	      "           Run 'modernish --test' after installation for more details."
fi

unset -v shellwarning
if thisshellhas BUG_APPENDC; then
	putln "* Warning: this shell has BUG_APPENDC, complicating 'use safe' (set -C)."
	shellwarning=y
fi
if thisshellhas BUG_SELECTRPL; then
	putln "* Warning: this shell has BUG_SELECTRPL, complicating 'use loop/select'."
	shellwarning=y
fi
if isset shellwarning; then
	putln "  Using this shell as the default shell is possible, but not recommended." \
		"  Modernish itself works around these bug(s), but some modernish scripts" \
		"  that have not implemented relevant workarounds may refuse to run."
fi

if isset BASH_VERSION; then
	putln "  Note: bash is good, but much slower than other shells. If performance" \
	      "  is important to you, it is recommended to pick another shell."
fi

if not isset opt_n && not isset opt_f; then
	ask_q "Are you happy with $msh_shell as the default shell?" \
	|| pick_shell_and_relaunch ${opt_d+-d$opt_d} ${opt_D+-D$opt_D}
fi

while not isset installroot; do
	if not isset opt_n && not isset opt_d; then
		putln "* Enter the directory prefix for installing modernish."
	fi
	if isset opt_d; then
		installroot=$opt_d
	elif isset opt_D || { is -L dir /usr/local && can write /usr/local; }; then
		if isset opt_n; then
			installroot=/usr/local
		else
			putln "  Just press 'return' to install in /usr/local."
			put "Directory prefix: "
			read -r installroot || exit 2 Aborting.
			empty $installroot && installroot=/usr/local
		fi
	else
		if isset opt_n; then
			installroot=
		else
			putln "  Just press 'return' to install in your home directory."
			put "Directory prefix: "
			read -r installroot || exit 2 Aborting.
		fi
		if empty $installroot; then
			# Installing in the home directory may not be as straightforward
			# as simply installing in ~/bin. Search $PATH to see if the
			# install prefix should be a subdirectory of ~.
			setlocal p --split=: -- $PATH; do	# ':' is $PATH separator
				# --split=: splits $PATH on ':' and puts it in the PPs without activating split within the block.
				for p do
					startswith $p $srcdir && continue 
					is -L dir $p && can write $p || continue
					if identic $p ~/bin || match $p ~/*/bin
					then  #       ^^^^^             ^^^^^^^ note: tilde expansion, but no globbing
						installroot=${p%/bin}
						return	# exit setlocal
					fi
				done
				installroot=~
				putln "* WARNING: $installroot/bin is not in your PATH."
			endlocal
		fi
	fi
	if not is present ${opt_D-}$installroot; then
		if isset opt_D || { not isset opt_n && ask_q "$installroot doesn't exist yet. Create it?"; }; then
			mkdir -p ${opt_D-}$installroot
		elif isset opt_n; then
			exit 1 "$installroot doesn't exist."
		else
			unset -v installroot opt_d
			continue
		fi
	elif not is -L dir ${opt_D-}$installroot; then
		putln "${opt_D-}$installroot is not a directory. Please try again." | fold -s >&2
		isset opt_n && exit 1
		unset -v installroot opt_d
		continue
	fi
	# Make sure it's an absolute path
	installroot=$(cd ${opt_D-}$installroot && pwd && echo X) || exit
	installroot=${installroot%?X}
	isset opt_D && installroot=${installroot#"$opt_D"}
	if match $installroot *[!$SHELLSAFECHARS]*; then
		putln "The path '$installroot' contains non-shell-safe characters. Please try again." | fold -s >&2
		if isset opt_n || isset opt_D; then
			exit 1
		fi
		unset -v installroot opt_d
		continue
	fi
	if startswith $(cd ${opt_D-}$installroot && pwd -P) $(cd $srcdir && pwd -P); then
		putln "The path '${opt_D-}$installroot' is within the source directory '$srcdir'. Choose another." | fold -s >&2
		isset opt_n && exit 1
		unset -v installroot opt_d
		continue
	fi
done

# zsh is more POSIX compliant if launched as sh, in ways that cannot be
# achieved if launched as zsh; so use a compatibility symlink to zsh named 'sh'
if isset ZSH_VERSION && not endswith $msh_shell /sh; then
	my_zsh=$msh_shell	# save for later
	zsh_compatdir=$installroot/libexec/modernish/zsh-compat
	msh_shell=$zsh_compatdir/sh
else
	unset -v my_zsh zsh_compatdir
fi

# Handler function for 'traverse': install one file or directory.
# Parameter: $1 = full source path for a file or directory.
# TODO: handle symlinks (if/when needed)
install_handler() {
	case ${1#.} in
	( */.* | */_* | */Makefile | *~ | *.bak )
		# ignore these (if directory, prune)
		return 1 ;;
	esac
	if is dir $1; then
		absdir=${1#.}
		destdir=${opt_D-}$installroot$absdir
		if not is present $destdir; then
			mkdir $destdir
		fi
	elif is reg $1; then
		relfilepath=${1#./}
		if not contains $relfilepath /; then
			# ignore files at top level
			return 1
		fi
		destfile=${opt_D-}$installroot/$relfilepath
		if is present $destfile; then
			exit 3 "Fatal error: '$destfile' already exists, refusing to overwrite"
		fi
		put "- Installing: $destfile "
		if identic $relfilepath bin/modernish; then
			put "(hashbang path: #! $msh_shell) "
			mktemp -s -C	# use mktemp with auto-cleanup from sys/base/mktemp module
			readonly_f=$REPLY
			mk_readonly_f $1 >|$readonly_f || exit 1 "can't write to temp file"
			# paths with spaces do occasionally happen, so make sure the assignments work
			defpath_q=$DEFPATH
			installroot_q=$installroot
			msh_shell_q=$msh_shell
			shellquote defpath_q installroot_q msh_shell_q
			# 'harden sed' aborts program if 'sed' encounters an error,
			# but not if the output direction (>) does, so add a check.
			sed "	1		s|.*|#! $msh_shell|
				/^DEFPATH=/	s|=.*|=$defpath_q|
				/^MSH_SHELL=/	s|=.*|=$msh_shell_q|
				/^MSH_PREFIX=/	s|=.*|=$installroot_q|
				/@ROFUNC@/	{	r $readonly_f
							d;	}
				/^#readonly MSH_/ {	s/^#//
							s/[[:blank:]]*#.*//;	}
			" $1 > $destfile || exit 2 "Could not create $destfile"
		else
			cp -p $1 $destfile
		fi
		read -r firstline < $1
		if startswith $firstline '#!'; then
			# make scripts executable
			chmod 755 $destfile
			putln "(executable)"
		else
			chmod 644 $destfile
			putln "(not executable)"
		fi
	fi
}

# Traverse through the source directory, installing files as we go.
traverse . install_handler

# Handle README.md specially.
putln "- Installing: ${opt_D-}$installroot/share/doc/modernish/README.md (not executable)"
cp -p README.md ${opt_D-}$installroot/share/doc/modernish/
chmod 644 ${opt_D-}$installroot/share/doc/modernish/README.md

# If we're on zsh, install compatibility symlink.
if isset ZSH_VERSION && isset my_zsh && isset zsh_compatdir; then
	mkdir -p ${opt_D-}$zsh_compatdir
	putln "- Installing zsh compatibility symlink: ${opt_D-}$msh_shell -> $my_zsh"
	ln -sf $my_zsh ${opt_D-}$msh_shell
	msh_shell=$my_zsh
fi

putln '' "Modernish $MSH_VERSION installed successfully with default shell $msh_shell." \
	"Be sure $installroot/bin is in your \$PATH before starting." \
