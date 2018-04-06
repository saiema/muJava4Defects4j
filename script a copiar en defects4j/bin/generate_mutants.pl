#!/usr/bin/env perl
#
#-------------------------------------------------------------------------------
# Copyright (c) 2014-2015 René Just, Darioush Jalali, and Defects4J contributors.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#-------------------------------------------------------------------------------

=pod

=head1 NAME

generate_mutants.pl -- mutation generation.

=head1 SYNOPSIS

  generate_mutants.pl -p project_id -b variant_id -y type

=head1 OPTIONS

=over 4

=item -p C<project_id>

The id of the project for which the generated test suites are analyzed.
See L<Project|Project/"Available Project IDs"> module for available project IDs.

=item -b C<variant_id>

Variant ID.

=item -y C<type>

f | b.

=back

=head1 DESCRIPTION

Generate mutants.

=cut
use warnings;
use strict;


use FindBin;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;

use lib abs_path("$FindBin::Bin/../core");
use Constants;
use Mutation;
use Project;
use Utils;
use Log;
use DB;

#
# Process arguments and issue usage message if necessary.
#
my %cmd_opts;
getopts('p:b:y:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p} and defined $cmd_opts{b} and defined $cmd_opts{y};

my $PID = $cmd_opts{p};
# Enable debugging if flag is set
$DEBUG = 1 if defined $cmd_opts{D};

# Set up project
my $project = Project::create_project($PID);

my $variant_id = $cmd_opts{b};
my $type = $cmd_opts{y};


# Temporary directory for execution
my $TMP_DIR = Utils::get_tmp_dir();
system("mkdir -p $TMP_DIR");

=pod

=cut

# Directory of class lists used for mutation step
my $CLASSES = defined $cmd_opts{A} ? "loaded_classes" : "modified_classes";
my $TARGET_CLASSES_DIR = "$SCRIPT_DIR/projects/$PID/$CLASSES";

_generate_mutants($PID, $variant_id, $type);

system("rm -rf $TMP_DIR") unless $DEBUG;

#
# Just generate (not compile) mutants
#
sub _generate_mutants {

    my ($pid, $bid, $type) = @_;
    print "pid: $pid\n";
    print "bid: $variant_id\n";
    print "type: $type\n";
    my $vid = "$variant_id$type";
    print "vid: $vid\n";

    # Checkout program version
    my $root = "$TMP_DIR/${vid}";
    $project->{prog_root} = "$root";
    $project->checkout_vid($vid) or die "Checkout failed";

    # Create mutation definitions (mml file)
    my $mml_dir = "$TMP_DIR/.mml";
    system("$UTIL_DIR/create_mml.pl -p $PID -c $TARGET_CLASSES_DIR/$bid.src -o $mml_dir -b $bid");
    my $mml_file = "$mml_dir/$bid.mml.bin";
    -e $mml_file or die "Mml file does not exist: $mml_file!";

    # Mutate source code
    $ENV{MML} = $mml_file;
    my $gen_mutants = $project->mutate();
    $gen_mutants > 0 or die "No mutants generated for $vid!";
}
