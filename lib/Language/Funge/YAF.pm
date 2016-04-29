package Language::Funge::YAF;

use 5.010;
use strict;
use warnings;
no  warnings 'syntax';

use feature 'signatures';
no  warnings 'experimental::signatures';

our $VERSION = '2016042601';

use Hash::Util::FieldHash 'fieldhash';

fieldhash my %program;          # "Compiled" program
fieldhash my %sizes;            # Current size of field
fieldhash my %program_counter;  # Program Counter:  [x position,
                                #                    y position,
                                #                    direction it's facing
                                #                    turn preference]
fieldhash my %stack;            # Stack a running program uses

sub movement;

#
# PC index constants.
#
use constant {
    X                 =>  0,
    Y                 =>  1,
    DIRECTION         =>  2,
    TURNING           =>  3,
};

#
# Directions
#
use constant {
    EAST              =>  0,
    SOUTH             =>  1,
    WEST              =>  2,
    NORTH             =>  3,
    NR_OF_DIRECTIONS  =>  4,
};

#
# Turn preference
#
use constant {
    CLOCKWISE         =>  0,
    ANTI_CLOCKWISE    =>  1,
    NR_OF_TURNINGS    =>  2,
};

#
# Operands
#
use constant {
    OP_ILLEGAL        => -1,
    OP_NONE           =>  0,
    OP_SPACE          =>  ord (' '),
    OP_WALL           =>  ord ('#'),
    OP_EXIT           =>  ord ('@'),
};

my %VALID_OPS = map {$_ => 1} OP_EXIT;

#
# Characters
#
use constant {
    SPACE             => ' ',
};

#
# Other
#
use constant {
    OP_MASK           => 0x7F,
    ERR_ILLEGAL       => -1,
};


#
# Create an instance
#
sub new ($class) {
    bless \do {my $x} => $class;
}

#
# No-op for now.
#
sub init ($self) {
    $self;
}


#
# Take a program text, and "compile" it, so it can be run.
# Throw an exception when encountering a non-ASCII character.
#
sub compile ($self, $text) {
    die "Only printable ASCII characters are allowed in a program"
         if $text =~ /[^\x20-\x7E\n]/;

    #
    # Split the text into lines.
    #
    my @lines = split /\n/ => $text;

    #
    # Split each line. Store the ASCII value of each character.
    # Remember the max width.
    #
    my @grid;
    my $max = 0;
    foreach (@lines) {
        my $gridline = [map {ord} split //];
        $max = @$gridline if @$gridline > $max;
        push @grid => $gridline;
    }
    #
    # Pad with spaces when necessary
    #
    foreach my $gridline (@grid) {
        push @$gridline => (SPACE) x ($max - @$gridline);
    }

    $self -> set_sizes ($max, scalar @grid);

    $program {$self}   = \@grid;

    $self;
}


#
# Run the program.
#
sub run ($self, $x = 0, $y = 0, $direction = EAST, $turning = CLOCKWISE) {
    #
    # Intialize the program counter. We start in the top left corner,
    # facing east, and with a preference to run clockwise, unless
    # told otherwise.
    #

    die "You cannot run a program which has not been compiled yet"
         unless $program {$self};

    #
    # Sanity checks.
    #
    $x         += 0;
    $y         += 0;
    $direction += 0;
    $turning   += 0;

    ($x, $y) = (0, 0) unless $y >= 0 && $x >= 0    &&
                             $program {$self} [$y] &&
                     defined $program {$self} [$y] [$x];

    #
    # Initialize program
    #
    $program_counter {$self} = [];
    $program_counter {$self} [0] [X]         = $x;
    $program_counter {$self} [0] [Y]         = $y;
    $program_counter {$self} [0] [DIRECTION] = $direction % NR_OF_DIRECTIONS;
    $program_counter {$self} [0] [TURNING]   = $turning   % NR_OF_TURNINGS;

    $stack {$self} = [];

    #
    # Main loop:
    #    - Fetch the current op.
    #    - Exit if illegal, or exit op.
    #    - Execute op
    #    - Move to next operand
    #
    while (1) {
        my $op = $self -> find_next_op;
        return   ERR_ILLEGAL   if     $op == OP_ILLEGAL;
        return   $self -> exit if     $op == OP_EXIT;
        $self -> execute ($op) unless $op == OP_NONE;
    }
}


sub find_operand ($self, $x, $y) {
    #
    # Return the operand at the given coordinates
    #
    my $op = $program {$self} [$y] [$x];

    return OP_NONE if !$op;

    $op &= OP_MASK;

    return OP_NONE if $op == OP_SPACE;
    return $op     if $VALID_OPS {$op};

    return OP_ILLEGAL;
}


#
# Move the program to the next operand, and return it.
#
sub find_next_op ($self) {
    my ($curr_x, $curr_y, $direction, $turning) = $self -> program_counter;

    my ($x_size, $y_size) = $self -> sizes;

    my $op;
    my $next_x;
    my $next_y;

    while (1) {
        #
        # Direction may change, so we calculate dx/dy in each iteration.
        #
        my ($dx, $dy) = movement ($direction);

        $next_x = ($curr_x + $dx) % $x_size;
        $next_y = ($curr_y + $dy) % $y_size;
        $next_x =  $x_size - 1 if $next_x < 0;
        $next_y =  $y_size - 1 if $next_y < 0;

        $op = $self -> find_operand ($next_x, $next_y);

        last if $op && $op != OP_SPACE;

        $curr_x = $next_x;
        $curr_y = $next_y;
    }

    #
    # Update program counter
    #
    $self -> set_program_counter ($next_x, $next_y);

    return $op if $VALID_OPS {$op};

    return OP_ILLEGAL;
}



#
# Set program counter stats
#
sub set_program_counter ($self, $x, $y, $direction = undef, $turning = undef) {
    my $pc = $program_counter {$self} [-1];

    $$pc [X]         = $x;
    $$pc [Y]         = $y;
    $$pc [DIRECTION] = $direction if defined $direction;
    $$pc [TURNING]   = $turning   if defined $turning;

    $self;
}

#
# Get the current program counter stats
#
sub program_counter ($self) {
    @{$program_counter {$self} [-1]};
}



#
# Get/set the current size (width, height) of the program
#
sub sizes ($self) {@{$sizes {$self}}}

sub set_sizes ($self, $x, $y) {
    $sizes {$self}   ||= [0, 0];
    $sizes {$self} [X] = int ($x) if int ($x) > $sizes {$self} [X];
    $sizes {$self} [Y] = int ($y) if int ($y) > $sizes {$self} [Y];

    $self;
}


#
# Given a direction, return dx/dy
#
sub movement ($direction) {
    my ($dx, $dy);
    if    ($direction == NORTH) {($dx, $dy) = ( 0, -1)}
    elsif ($direction == EAST)  {($dx, $dy) = ( 1,  0)}
    elsif ($direction == SOUTH) {($dx, $dy) = ( 0,  1)}
    elsif ($direction == WEST)  {($dx, $dy) = (-1,  0)}
    else {
        die "Unknown direction $direction";
    }

    return ($dx, $dy);
}


################################################################################
#
#  Commands go below
#
################################################################################

sub exit ($self) {
    return 1;
}

1;

__END__

=head1 NAME

Language::Funge::YAF - Abstract

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TODO

=head1 SEE ALSO

=head1 DEVELOPMENT

The current sources of this module are found on github,
L<< git://github.com/Abigail/Language-Funge-YAF.git >>.

=head1 AUTHOR

Abigail, L<< mailto:cpan@abigail.be >>.

=head1 COPYRIGHT and LICENSE

Copyright (C) 2016 by Abigail.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),   
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=head1 INSTALLATION

To install this module, run, after unpacking the tar-ball, the 
following commands:

   perl Makefile.PL
   make
   make test
   make install

=cut