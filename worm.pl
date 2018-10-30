#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;

use Data::Dumper;
use Curses;
use Time::HiRes qw(time);
use IO::Handle;


##### data ###
# worm
our $w = {
	c_body   => 'O',
	c_head   => 'X',
	body     => [],
	last_key => KEY_LEFT,
	# direction of movement
	row      => 0,
	col      => -1,
	meal     => '@',
	poison   => '*',
};

our $place = {
	# 0 row,0 col  top left corner
	max_row  => undef,
	max_col  => undef,
	# chars for screen frame
	r_char   => '-',
	c_char   => '|',
	end_str  => 'G A M E   O V E R !!!',
	win_str  => 'YOU are the Winner !!!',
	meal_cnt => undef,
};

# bad character - dead
$place->{badc} = $place->{r_char} . $place->{c_char} . $w->{c_body} . $w->{poison};

# free rows around the worm for a better start
our @bad_rows = ();


#### subs ###

sub create_frame {
	getmaxyx( $place->{max_row}, $place->{max_col} );
	clear;

	# top and botton row
	my $line = $place->{r_char} x $place->{max_col};
	move(0,0);
	printw($line);
	move(($place->{max_row} - 1), 0);
	printw($line);

	# left and right line
	for (my $line = 1; $line < ($place->{max_row} - 1); $line++) {
		move($line, 0);
		printw($place->{c_char});
		move($line, ($place->{max_col} - 1));
		printw($place->{c_char});
	}
}

# find char in array
# params ($scalar, @array_not_ref)
sub array_exists { my $x = shift; for my $i (@_) { return 1 if $x eq $i } }


# generating and drawing place for worm
sub generate_env {

	my ($meal_cnt, $poison_cnt) = get_max_items();
	my $meal   = $w->{meal};
	my $poison = $w->{poison};

	# calculating three lines for which we do not generate any characters
	my ($head_row, undef) = @{ $w->{body}->[0] };
	push @bad_rows, (($head_row - 1), $head_row, ($head_row + 1));

	display_item($meal_cnt, $meal);
	$place->{meal_cnt} = $meal_cnt;
	display_item($poison_cnt, $poison);
}

# randomly generates the coordinates of the desired character
sub display_item {
	my ($cnt, $char) = @_;

	srand;
	while ($cnt--) {
		my ($row, $col);

		do {
			$row = int(rand($place->{max_row} - 2));
		} while ( $row == 0 or array_exists($row, @bad_rows) );

		do {
			$col = int(rand($place->{max_col} - 2));
		} while ( $col == 0 );

		my $check_char = inch($row, $col);
		if ($check_char ne ' ') {
			$cnt++;
			next;
		}
		else {
			addstr($row, $col, $char);
		}
	}
}


# calculating max items - meal and poison
# depends on screen size
sub get_max_items {
	my $max_meal   = $place->{max_col};
	my $max_poison = int($place->{max_col} / 10);
	return($max_meal, $max_poison);
}


sub draw_worm {
	unless ( scalar @{ $w->{body} } ) {
		my $center_row = int( $place->{max_row} / 2 );
		my $center_col = int( $place->{max_col} / 2 );
		push @{ $w->{body} }, [ $center_row, $center_col ];
		push @{ $w->{body} }, [ $center_row, ($center_col + 1) ];
	}

	# head
	my $cor = $w->{body}->[0];
	move($cor->[0], $cor->[1]);
	printw($w->{c_head});

	# body
	for my $idx (1 .. $#{ $w->{body} }) {
		my $cor = $w->{body}->[$idx];
		move($cor->[0], $cor->[1]);
		printw($w->{c_body});
	}
}

# check and change direction of movement
sub chk_key {
	my ($k) = @_;

	# without key input
	{
		no warnings;
		return if ( $k == -1 );
	}

	# same direction
	my $last_key = $w->{last_key};
	return if ($last_key == $k);

	if ( $k == KEY_UP and $last_key != KEY_DOWN ) {
		$w->{row} = -1;
		$w->{col} = 0;
		$w->{last_key} = $k;
	}
	elsif ( $k == KEY_DOWN and $last_key != KEY_UP ) {
		$w->{row} = 1;
		$w->{col} = 0;
		$w->{last_key} = $k;
	}
	elsif ( $k == KEY_LEFT and $last_key != KEY_RIGHT ) {
		$w->{row} = 0;
		$w->{col} = -1;
		$w->{last_key} = $k;
	}
	elsif ( $k == KEY_RIGHT and $last_key != KEY_LEFT ) {
		$w->{row} = 0;
		$w->{col} = 1;
		$w->{last_key} = $k;
	}
}


# is the next chars of death ?
sub chk_c {
	my ($c) = @_;
	return 0 if ( $place->{badc} =~ /\Q$c\E/ );
	return 1;
}


sub finish_with_text {
	my $end_str = '* ' . +shift . ' *';

	my $str_length = length( $end_str );
	my $center_row = int( $place->{max_row} / 2 );
	my $center_col = int( ($place->{max_col} / 2) - ($str_length / 2) );

	my $top_botton_line = '*' x $str_length;

	endwin();
	refresh();
	clear();

	attron(A_BOLD);
	addstr(($center_row - 1), $center_col, $top_botton_line);
	addstr($center_row, $center_col, $end_str);
	addstr(($center_row + 1), $center_col, $top_botton_line);

	timeout(4000);
	getch();
	exit;
}


sub enlarge_worm {
	my ($new_row, $new_col) = @_;

	my ($act_row, $act_col) = @{ $w->{body}->[0] };
	move($act_row, $act_col);
	printw($w->{c_body});

	move($new_row, $new_col);
	printw($w->{c_head});

	unshift @{ $w->{body} }, [$new_row, $new_col];
}


sub move_body {
	my ($new_row, $new_col) = @_;

	move($new_row, $new_col);
	printw($w->{c_head});

	my ($act_row, $act_col) = @{ $w->{body}->[0] };
	move($act_row, $act_col);
	printw($w->{c_body});

	my ($last_row, $last_col) = @{ $w->{body}->[-1] };
	move($last_row, $last_col);
	printw(' ');

	unshift @{ $w->{body} }, [$new_row, $new_col];
	pop @{ $w->{body} };
}


sub move_worm {
	my ($act_row, $act_col) = @{ $w->{body}->[0] };
	my $new_row = $act_row + $w->{row};
	my $new_col = $act_col + $w->{col};

	my $next_char = inch($new_row, $new_col);
	unless ( chk_c($next_char) ) {
		finish_with_text($place->{end_str});
	}

	if ( $next_char eq $w->{meal} ) {
		enlarge_worm($new_row, $new_col);
		$place->{meal_cnt}--;
	}
	else {
		move_body($new_row, $new_col);
	}

	finish_with_text($place->{win_str}) unless ($place->{meal_cnt});
}


sub intro {

	my @text = ();
	while (my $line = <DATA>) {
		chomp($line);
		push @text, $line;
	}
	getmaxyx( $place->{max_row}, $place->{max_col} );

	my $text_width = length($text[0]) ;
	my $text_height = scalar @text;
	my $center_row = int( ($place->{max_row} / 2) - ($text_height / 2) );
	my $center_col = int( ($place->{max_col} / 2) - ($text_width / 2) );

	while (scalar @text) {
		my $line = shift @text;
		addstr($center_row, $center_col, $line);
		$center_row++;
	}

	my $meal_poison_txt = $w->{meal} . ' = meal and ' . $w->{poison} . ' = poison';
	$text_width = length($meal_poison_txt) ;
	$center_col = int( ($place->{max_col} / 2) - ($text_width / 2) );
	$center_row += 2;
	addstr($center_row, $center_col, $meal_poison_txt);

	getch();
	clear();
}



##### main ###
initscr;
END{endwin;}

noecho;
cbreak;
keypad(stdscr, 1);
# cursor invisible
curs_set(0);
refresh();

intro();

nodelay(stdscr, 1);

my $size_changed = 0;
$SIG{'WINCH'} = sub { $size_changed = 1; };

create_frame();
draw_worm();
generate_env();

# time management ;-)
timeout(100);
my $last_time = time;
# lower value = higher speed
my $time_chunk = 0.5;


### main loop
while( my $k = getch() ){

	last if ( $k eq 'q' );
	chk_key($k);

	my $act_time = time();
	if (($act_time - $last_time) > $time_chunk) {
		move_worm();
		$last_time = $act_time;
	}

	if ($size_changed) {
		endwin();
		refresh();
		create_frame();
		draw_worm();
		generate_env();
		$size_changed = 0;
	}

}

finish_with_text($place->{end_str});


__END__
#    #  ####  #####  #    #
#    # #    # #    # ##  ##
#    # #    # #    # # ## #
# ## # #    # #####  #    #
##  ## #    # #   #  #    #
#    #  ####  #    # #    #


       Use arrow keys
      for play a game
        q for quit
