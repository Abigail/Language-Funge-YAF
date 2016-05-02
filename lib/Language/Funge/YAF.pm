package Language::Funge::YAF;

use 5.010;
use strict;
use warnings;
no  warnings 'syntax';

use feature  'signatures';
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
sub turn;
sub turn_direction;

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
    EAST              =>  1,
    SOUTH             =>  2,
    STAY_PUT          =>  0,
    WEST              => -1,
    NORTH             => -2,
};

#
# Turn preference
#
use constant {
    CLOCKWISE         =>  1,
    NO_TURNING        =>  0,
    ANTI_CLOCKWISE    => -1,
};

#
# Operators
#
use constant {
    OP_ILLEGAL            => -1,
    OP_NONE               =>  0,
    OP_SPACE              =>  ord (' '),        # 0x20
    OP_WALL               =>  ord ('#'),        # 0x23
    OP_EXIT               =>  ord ('@'),        # 0x40

    OP_NUMBER_0           =>  ord ('0'),        # 0x30
    OP_NUMBER_1           =>  ord ('1'),        # 0x31
    OP_NUMBER_2           =>  ord ('2'),        # 0x32
    OP_NUMBER_3           =>  ord ('3'),        # 0x33
    OP_NUMBER_4           =>  ord ('4'),        # 0x34
    OP_NUMBER_5           =>  ord ('5'),        # 0x35
    OP_NUMBER_6           =>  ord ('6'),        # 0x36
    OP_NUMBER_7           =>  ord ('7'),        # 0x37
    OP_NUMBER_8           =>  ord ('8'),        # 0x38
    OP_NUMBER_9           =>  ord ('9'),        # 0x39

    OP_WRITE_NUMBER       =>  ord ('.'),        # 0x2E
    OP_WRITE_CHAR         =>  ord (','),        # 0x2C

    OP_ADDITION           =>  ord ('+'),        # 0x2B
    OP_SUBTRACTION        =>  ord ('-'),        # 0x2D
    OP_MULTIPLICATION     =>  ord ('*'),        # 0x2A
    OP_DIVISION           =>  ord ('/'),        # 0x2F

    OP_STACK_DUPLICATE    =>  ord (':'),        # 0x3A
    OP_STACK_DISCARD      =>  ord ('_'),        # 0x5F
    OP_STACK_DIG          =>  ord ('\\'),       # 0x5C
};


#
# Errors
#
use constant {
    ERR_ILLEGAL           =>  -1,
    ERR_STUCK             =>  -2,
    ERR_LOOPING           =>  -3,
    ERR_DIVISION_BY_ZERO  =>  -4,
};

my %ARITHMETIC_OP = map {$_ => 1}  OP_ADDITION,        OP_SUBTRACTION,
                                   OP_MULTIPLICATION,  OP_DIVISION;
my %WRITE_OP      = map {$_ => 1}  OP_WRITE_NUMBER,    OP_WRITE_CHAR;
my %STACK_OP      = map {$_ => 1}  OP_STACK_DUPLICATE, OP_STACK_DISCARD,
                                   OP_STACK_DIG;

my %VALID_OPS     = (%ARITHMETIC_OP, %WRITE_OP, %STACK_OP,
                    map {$_ => 1}  OP_EXIT, OP_NUMBER_0 .. OP_NUMBER_9,);

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
        push @$gridline => (OP_SPACE) x ($max - @$gridline);
    }

    $self -> clear_sizes;
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

    $turning   = CLOCKWISE unless $turning   == CLOCKWISE ||
                                  $turning   == ANTI_CLOCKWISE;
    $direction = EAST      unless $direction == EAST  ||
                                  $direction == SOUTH ||
                                  $direction == WEST  ||
                                  $direction == NORTH;

    my ($x_size, $y_size) = $self -> sizes;

    ($x, $y) = (0, 0) unless $x >= 0 && $x < $x_size &&
                             $y >= 0 && $y < $y_size;

    #
    # Initialize program
    #
    $self -> set_program_counter ($x, $y, $direction, $turning);
    $self -> init_stack;

    #
    # Main loop:
    #    - Fetch the current op.
    #    - Exit if illegal, or exit op.
    #    - Execute op
    #    - Move to next operand
    #
    while (1) {
        my $op = $self -> find_next_op;
        return   $op           if     $op <  0;   # Error occurred
        return   $self -> exit if     $op == OP_EXIT;
        if ($op != OP_NONE) {
            my $error = $self -> execute ($op);
            return $error if $error;
        }
    }
}

#
# Execute a particular operation
#
sub execute ($self, $op) {
    if ($op >= OP_NUMBER_0 && $op <= OP_NUMBER_9) {
        my $number = $self -> scan_number;
        if ($number < 0) {
            return $number;
        }
        $self -> push_stack ($number);
        return;
    }
    elsif ($WRITE_OP {$op}) {
        $self -> write_value ($op);
        return;
    }
    elsif ($ARITHMETIC_OP {$op}) {
        return $self -> arithmetic ($op);
    }
    elsif ($STACK_OP {$op}) {
        $self -> munge_stack ($op);
        return;
    }
    die "execute called with unknown operation '$op'\n";
}


#
# Return the operation at the given coordinates
#
sub find_operation ($self, $x, $y) {
    my $op = $program {$self} [$y] [$x];

    return OP_NONE if !$op;

    $op &= OP_MASK;

    return $op if $op == OP_SPACE || $op == OP_WALL || $VALID_OPS {$op};

    return OP_ILLEGAL;
}


#
# Move the program to the next operand, and return it.
#
sub find_next_op ($self) {
    my ($curr_x, $curr_y, $direction, $turning) = $self -> program_counter;

    my $old_direction = $direction;
    my $old_turning   = $turning;

    my ($x_size, $y_size) = $self -> sizes;

    my $op;
    my $next_x;
    my $next_y;

    my %seen;
    $seen {$curr_x, $curr_y, $direction, $turning} ++;

    while (1) {
        #
        # We will try to move one step ahead. If we hit a wall, we
        # try turning. If we hit a wall again, we try turning in the
        # other direction. If that hits a wall as well, we flip
        # direction. If that hits a wall, we're stuck.
        #
        my @escapes = ([ $direction, NO_TURNING],
                       [ $direction,   $turning],
                       [ $direction,  -$turning],
                       [-$direction, NO_TURNING]);

        my ($try_direction, $try_turn);
        foreach my $escape (@escapes) {
            ($try_direction, $try_turn) = @$escape;
            ($next_x, $next_y) = $self -> step ($curr_x, $curr_y,
                                                $try_direction, $try_turn);

            $op = $self -> find_operation ($next_x, $next_y);

            unless ($op == OP_WALL) {
                $direction = turn_direction ($try_direction, $try_turn);
                $turning   = $try_turn unless $try_turn == NO_TURNING;
                last;
            }
        }
        
        last unless $op == OP_SPACE;

        $curr_x = $next_x;
        $curr_y = $next_y;
        
        if ($seen {$curr_x, $curr_y, $direction, $turning} ++) {
            #
            # We've been here, facing the same direction, and wanting to
            # turn the same way. 
            #
            return ERR_LOOPING;
        }
    }

    if ($op == OP_WALL) {
        #
        # We are stuck. Don't update the program counter
        #
        return ERR_STUCK;
    }

    #
    # Update program counter
    #
    $self -> set_program_counter ($next_x, $next_y, $direction, $turning);

    return $op if $VALID_OPS {$op};

    return ERR_ILLEGAL;
}



#
# Set program counter stats
#
sub set_program_counter ($self, $x, $y, $direction = undef,
                                        $turning   = undef) {
    $program_counter {$self} ||= [[ ]];

    my $pc = $program_counter {$self} [-1];

    $$pc [X]         = $x;
    $$pc [Y]         = $y;
    $$pc [DIRECTION] = $direction if $direction && $direction != STAY_PUT;
    $$pc [TURNING]   = $turning   if $turning   && $turning   != NO_TURNING;

    $self;
}

#
# Get the current program counter stats
#
sub program_counter ($self) {
    @{$program_counter {$self} [-1]};
}




#
# Initialize the stack
#
sub init_stack ($self) {
    $stack {$self} = [];
}

#
# Pop from the stack; if stack is empty, return 0.
# Optionally, give how many items to pop.
#
sub pop_stack ($self, $n = 1) {
    $n = 1 unless $n =~ /^[1-9][0-9]*$/;
    my @ret;
    if (@{$stack {$self}} >= $n) {
        @ret = splice @{$stack {$self}} => - $n;
    }
    else {
        @ret = ((0) x ($n - @{$stack {$self}}), @{$stack {$self}});
        $stack {$self} = [];
    }

    return wantarray ? @ret : $ret [0];
}

#
# Return the top value of the stack, or 0 if stack is empty
#
sub top_stack ($self) {
    return @{$stack {$self}} ? $stack {$self} [-1] : 0
}

#
# Push to the stack.
#
sub push_stack ($self, @items) {
    push @{$stack {$self}} => @items;
}


#
# Get/set the current size (width, height) of the program
#
sub sizes ($self) {@{$sizes {$self}}}

sub clear_sizes ($self) {
    $sizes {$self} = [0, 0];
}

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


#
# Given (dx, dy) movement, and a turning direction, find new movement.
#
sub turn ($dx, $dy, $turning) {
    if ($turning == CLOCKWISE) {
        ($dx, $dy) = (-$dy,  $dx);
    }
    elsif ($turning == ANTI_CLOCKWISE) {
        ($dx, $dy) = ( $dy, -$dx);
    }
    # else ($turning == NO_TURNING)
    return ($dx, $dy);
}

#
# Given a direction and a turning direction, return new direction
#
sub turn_direction ($direction, $turning) {
    if ($turning == CLOCKWISE) {
        return EAST  if $direction == NORTH;
        return SOUTH if $direction == EAST ;
        return WEST  if $direction == SOUTH;
        return NORTH;
    }
    elsif ($turning == ANTI_CLOCKWISE) {
        return EAST  if $direction == SOUTH;
        return SOUTH if $direction == WEST ;
        return WEST  if $direction == NORTH;
        return NORTH;
    }
    else {
        return $direction;
    }
}


#
# Given (x, y) coordinates, a direction of movement, and a 
# turning direction, return new coordinates.
#
sub step ($self, $x, $y, $direction, $turning = NO_TURNING) {
    my ($x_size, $y_size) = $self -> sizes;
    my ($dx, $dy) = turn movement ($direction), $turning;

    my  $new_x = ($x + $dx) % $x_size;
    my  $new_y = ($y + $dy) % $y_size;
        $new_x =  $x_size - 1 if $new_x < 0;
        $new_y =  $y_size - 1 if $new_y < 0;

    return ($new_x, $new_y);
}



################################################################################
#
#  Commands go below
#
################################################################################

sub exit ($self) {
    return $self -> pop_stack;
}

#
# Scan a number starting from the current location.
#
sub scan_number ($self) {
    my ($x, $y, $direction) = $self -> program_counter;
    my  $number = $self -> find_operation ($x, $y) - OP_NUMBER_0;

    my %seen;
    $seen {$x, $y} ++;

    while (1) {
        my ($next_x, $next_y) = $self -> step ($x, $y, $direction);
        my  $op = $self -> find_operation ($next_x, $next_y);
        if ($op < OP_NUMBER_0 || $op > OP_NUMBER_9) {
            $self -> set_program_counter ($x, $y);
            return $number;
        }
        $number *= 10;
        $number += $op - OP_NUMBER_0;
        $x = $next_x;
        $y = $next_y;
        if ($seen {$x, $y} ++) {
            return ERR_LOOPING;
        }
    }
}


#
# Write the top of the stack, either as a number, or a character.
#
sub write_value ($self, $op) {
    my $value = $self -> pop_stack;
    print $op == OP_WRITE_NUMBER ? $value : chr $value;
    return;
}


#
# Pop two numbers, add, subtract, multiply, or divide them.
# Push the result back on the stack; when dividing, push both
# quotient and modulus.
#
sub arithmetic ($self, $op) {
    my $x = $self -> pop_stack;
    my $y = $self -> pop_stack;
    if    ($op == OP_ADDITION) {
        $self -> push_stack ($x + $y);
    }
    elsif ($op == OP_SUBTRACTION) {
        $self -> push_stack ($x - $y);
    }
    elsif ($op == OP_MULTIPLICATION) {
        $self -> push_stack ($x * $y);
    }
    elsif ($op == OP_DIVISION) {
        return ERR_DIVISION_BY_ZERO unless $y;
        $self -> push_stack (int ($x / $y));
        $self -> push_stack      ($x % $y);
    }
    else {
        die "Unknown arithmetic operator '$op'\n";
    }
    return;
}


#
# Manipulate the stack:
#    - Duplicate a value
#    - Pop a value (discard)
#
sub munge_stack ($self, $op) {
    if    ($op == OP_STACK_DUPLICATE) {
        $self -> push_stack ($self -> top_stack);
    }
    elsif ($op == OP_STACK_DISCARD) {
        $self -> pop_stack;
    }
    elsif ($op == OP_STACK_DIG) {
        # Pop the distance from the stack. If distance is 0, we're done.
        my $distance = $self -> pop_stack or return;

        my @list = $self -> pop_stack ($distance);

        if ($distance > 0) {
            my $val = shift @list;
            push @list => $val;
        }
        else {
            my $val = pop @list;
            unshift @list => $val;
        }
        $self -> push_stack (@list);
    }
    else {
        die "Unknown stack operation '$op'\n";
    }
    return;
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
