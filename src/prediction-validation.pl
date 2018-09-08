#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Data::Dumper;

BEGIN {
    sub get_prices($$$ );
    sub get_errors($$ );
    sub calculate_average_error($$ );
    sub generate_output_line($$$ );
}

my ($usage) = qq{
USAGE:
 % $0 <window_filename> <actual_filename> <predicted_filename> <comparison_filename>
};

# check number of arguments
unless (@ARGV >= 4) {
    print $usage;
    exit(1);
}

# mandatory arguments
my ($window_file) = $ARGV[0];
my ($actual_file) = $ARGV[1];
my ($predicted_file) = $ARGV[2];
my ($comparison_file) = $ARGV[3];

# optional argument, used to print debug info
my ($debug) = $ARGV[4];

# check validity of input files
unless (-e $window_file) {
    print "Invalid window file: $window_file\n";
    exit(1);
}

unless (-e $actual_file) {
    print "Invalid actual file: $actual_file\n";
    exit(1);
}

unless (-e $predicted_file) {
    print "Invalid predicted file: $predicted_file\n";
    exit(1);
}

# check validity of window size
my $window_size = `cat $window_file`;
chomp($window_size);
if ($window_size !~ /^\d+$/) {
    print "Invalid window size: $window_size\n";
}

# read content of files, and store in hash
my ($prices) = {};
get_prices($actual_file, $prices, 'actual');
get_prices($predicted_file, $prices, 'predicted');

# calculate 1)total error; 2)count of valid entries; for each hour
my ($errors) = {};
get_errors($prices, $errors);

# print debug info if optional argument for debug is given
if (defined $debug && $debug eq 'debug') {
    print "[DEBUG:]\nwindow size: $window_size\n";
    print Dumper($prices);
    print Dumper($errors);
}

my (@hours) = sort { $a <=> $b } keys %$prices;
my ($start_hour) = $hours[0];
my ($end_hour) = $hours[scalar(@hours) - 1];

if ($window_size > ($end_hour - $start_hour + 1)) {
    print "Window size is greater than expand of hours, exit.\n";
    exit(1);
}

# open output file handle for write
open (OUT, "> $comparison_file") or die "Can't open file $comparison_file for write. Reason: $!\n";

my ($total) = 0; # total error of a time window
my ($count) = 0; # total count of valid entries in a time window
my ($s) = $start_hour;
my ($e) = $start_hour;
my ($n) = $window_size;
while ($n > 0) {
    if (exists $errors->{$e}) {
	$total += $errors->{$e}->{'error'};
	$count += $errors->{$e}->{'count'};
    }
    $e++;
    $n--;
}

my ($result) = calculate_average_error($total, $count);
print OUT generate_output_line($s, $e - 1, $result) . "\n";

while ($e <= $end_hour) {
    if (exists $errors->{$s}) {
	$total -= $errors->{$s}->{'error'};
	$count -= $errors->{$s}->{'count'};
    }

    if (exists $errors->{$e}) {
	$total += $errors->{$e}->{'error'};
	$count += $errors->{$e}->{'count'};
    }

    ($result) = calculate_average_error($total, $count);

    $s++;
    print OUT generate_output_line($s, $e, $result) . "\n";
    $e++;
}

# close the output file handle
close OUT;



############################################################
# Given the starting time/hour, the ending hour, and the 
# calculated average error, generate the line (to be written
# to the output file).
# @param $s the starting hour
# @param $s the ending hour
# @param $calc the calculated average error
# @return a string line
############################################################
sub generate_output_line($$$ ) {
    my ($s, $e, $calc) = @_;
    my (@temp) = ();
    push(@temp, $s);
    push(@temp, $e);
    push(@temp, $calc);
    return join('|', @temp);
}


############################################################
# Calculate average error
# @param $total total error
# @param $count number of valid entries
# @return $result average error rounded off to 
#         2 decimal places, if count is 0, return 'NA'
############################################################
sub calculate_average_error($$ ) {
    my ($total, $count) = @_;
    my ($result);
    if ($count == 0) {
	$result = 'NA';
    }
    else {
	$result = sprintf("%.2f", $total / $count); 
    }

    return $result;
}


############################################################
# Given the "prices" hash, calcuate 
# 1) the total error
# 2) the number of valid entries
# for each hour, and store in "errors" hash
# @param $prices the hash that was filled in by sub get_prices
# @param $errors the hash that contains the total error
#        and the number of valid entries
#
# The resulting hash is like:
# $errors = {
#           '127' => {
#                      'count' => 76,
#                      'error' => '14.75'
#                    },
#           '1049' => {
#                       'count' => 83,
#                       'error' => '968.02'
#                     },
# 	  ...
# 	     '807' => {
#                      'count' => 85,
#                      'error' => '636.61'
#                    }
#         }
# 
# where 127 is the hour, 76 is the number of valid entries, 
# and error is the total error for the hour.
############################################################
sub get_errors($$ ) {
    my ($prices, $errors) = @_;

    my ($hour_hash) = {};
    my ($stock_hash) = {};

    foreach my $hour (sort keys %$prices) {
	$hour_hash = $prices->{$hour};

	my ($total_error) = 0;
	my ($count) = 0;

	foreach my $stock (sort keys %$hour_hash) {
	    $stock_hash = $hour_hash->{$stock};
	    
	    # one or both of the actual and predicted prices are missing
	    if (!exists $stock_hash->{'actual'} || !exists $stock_hash->{'predicted'}) {
		next;
	    }

	    $count++;
	    my ($single_error) = abs($stock_hash->{'predicted'} - $stock_hash->{'actual'});
	    $total_error += $single_error;
	}

	$errors->{$hour}->{'error'} = $total_error;
	$errors->{$hour}->{'count'} = $count;
    } 
}


############################################################
# Given a input file, read the file and sotre the content
# in a hash
# @param $in the input file with lines in the format of:
#            1|ZZQVYU|106.73
# @param $count number of valid entries
# @param $type 'actual' or 'predicted'
#
# The hash will be filled in like:
# $prices = {
# 	'1049' => {
# 	             'OJKFNH' => {
#                                     'actual' => '113.53',
#                                     'predicted' => '96.81'
# 		                  },
# 		     'NQWHXT' => {
#                                     'actual' => '103.11',
#                                     'predicted' => '103.17'
# 	       		    },
# 		      ...
# 	            },
#          ...
# }
#
# where '1049' is the hour, 'OJKFNH' is the stock symbol,
# and the numbers are prices
############################################################
sub get_prices($$$ ) {
    my ($in, $prices, $type) = @_;

    if ($type ne 'actual' && $type ne 'predicted') {
	print "Invalid type: $type\n";
	return;
    }

    open(IN, "< $in") or die "Can't open file $in for read. Reason $!\n";

    my ($line);
    while (<IN>) {
	$line = $_;
	chomp $line;
	unless ($line =~ /\S/) {
	    next;
	}
	my (@tokens) = split(/\s*\|\s*/, $line);
	my ($hour) = $tokens[0];
	my ($stock) = $tokens[1];
	my ($price) = $tokens[2];

	unless ($hour =~ /^\d+$/) {
	    print "Invalid time, skip.  Current line: $line\n";
	    next;
	}

	unless ($stock =~ /\S/) {
	    print "Invalid stock, skip.  Current line: $line\n";
	}

	unless ($price =~ /^[\d\.\-]+$/) {
	    print "Invalid price, skip.  Current line: $line\n";
	    next;
	}

	$prices->{$hour}->{$stock}->{$type} = $price;
    }
    
    close IN;
}

