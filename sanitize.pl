#!/usr/bin/perl

use strict;
use Data::Dumper;
use lib 'lib';
use ParseArgs;

my $args = ParseArgs::parse(\@ARGV);


my (
	$curind, $mode, $src, $ppl,
	$lines, $line, $title, $cit,
	$citmap, @filecontent
);
my $srcidx = 101;
$| = 1;

init();
read_file();
write_file();

sub init() {
	# Consolidate arguments of different forms
	$args->{'a'} = (defined $args->{'a'} || defined $args->{'addr'})
		? $args->{'a'} || $args->{'addr'} : 0;
	$args->{'c'} = (defined $args->{'c'} || defined $args->{'change'})
		? $args->{'c'} || $args->{'change'} : 0;
	$args->{'i'} = (defined $args->{'i'} || defined $args->{'infile'})
		? $args->{'i'} || $args->{'infile'} : '';
	$args->{'l'} = (defined $args->{'l'} || defined $args->{'link'})
		? $args->{'l'} || $args->{'link'} : '';
	$args->{'m'} = (defined $args->{'m'} || defined $args->{'married'})
		? $args->{'m'} || $args->{'married'} : 0;
	$args->{'n'} = (defined $args->{'n'} || defined $args->{'notes'})
		? $args->{'n'} || $args->{'notes'} : 0;
	$args->{'o'} = (defined $args->{'o'} || defined $args->{'outfile'})
		? $args->{'o'} || $args->{'outfile'} : '';
	$args->{'p'} = (defined $args->{'p'} || defined $args->{'places'})
		? $args->{'p'} || $args->{'places'} : 0;

	# Check that we were given a file and set up some variables.
	if (!$args->{'i'}) {
		print usage();
		exit 1;
	}

	if (!$args->{'o'}) {
		$args->{'o'} = $args->{'i'};
		$args->{'o'} =~ s/\.(\w+)$/-fixed.$1/ig;
	}

	$citmap = {
		'Birth Surname' => 'GIVN',
		'Current Location' => 'ADDR',
		'Occupation' => 'OCCU',
		'Cause of Death' => 'DEAT',
		'Date of Death' => 'DEAT',
		'Gender' => 'SEX',
		'Place of Death' => 'DEAT',
		'Nicknames' => 'NICK',
		'Place of Baptism' => 'BAPM',
		'Place of Burial' => 'BURI',
		'Living Status' => '',
		'Also Known As' => 'NICK',
		'First Name' => 'NAME',
		'Place of Birth' => 'BIRT',
		'Last Name' => 'SURN',
		'Date of Burial' => 'BURI',
		'Date of Baptism' => 'CHR',
		'Ethnicity' => '',
		'Date of Birth' => 'BIRT',
		'Display Name' => 'NAME',
		'Suffix' => 'NSFX',
		'Middle Name' => 'GIVN',
		'Maiden Name' => '',
	};
}

sub read_file() {
	# Read in the GEDCOM and build some data structures for the sources
	# which will allow us to place each source under it's target individual
	# and field when we write the new GEDCOM back out.
	print "Reading in ",$args->{'i'} , " ";
	open INF, $args->{'i'};
	@filecontent = <INF>;
	close INF;

	foreach (@filecontent) {
		print '.' if $lines % (int($#filecontent/100)) == 0;
		$lines++;
		$line = $_;
		$line =~ s/\s+$//i;
		if ($line =~ /0 \@(\w+)\@ INDI/i) {
			$curind = $1;
		} elsif ($curind && $line =~ /1 SOUR/i) {
			$title = '';
			$cit = '';
			$mode = 'source';
		} elsif ($mode eq 'source') {
			if (!$cit && $line =~ /3 TEXT (.*)$/i) {
				$cit = $citmap->{$1};
			} elsif ($line =~ /3 TITL (.*)$/i) {
				$title = $1;
				if (!has_source($ppl->{$curind}{$cit}, $title)) {
					$srcidx++;
					$src->{$srcidx} = $title;
					$ppl->{$curind}{$cit}{$srcidx} = 1;
				}
			} elsif ($line =~ /^\s+1 /i) {
				$mode = '';
			}
		}
	}

	print "\nI found ", scalar keys %{$src}, " sources for ",
		scalar keys %{$ppl}, " people.\nWriting file ";
}

sub write_file() {
	my ($curind, $mode, $line, $title, $cit, $num, $lastnum, $printed_link);
	open OUT, sprintf(">%s", $args->{'o'});
	$lines = 0;
	foreach (@filecontent) {
		$lines++;
		print '.' if $lines % (int($#filecontent/100)) == 0;
		$line = $_;
		$line =~ s/\s+$//i;
		$line =~ s/^\s*//i;
		$line =~ /^\s*(\d+)\s+(\S+)/i;
		$num = $1;
		my $cmd = $2;
		if ($line =~ /0 \@(\w+)\@ INDI/i) {
			$curind = $1;
			$mode = '';
			$printed_link = 0;
		} elsif ($curind && $line =~ /0 TRLR/i) {
			$mode = 'source';
		} elsif ($curind && $line =~ /1 NOTE/
				&& $line !~ /about_me/i && $line !~ /occupation/i
				&& !$args->{'n'}) {
			$mode = 'note';
		} elsif ($curind && $line =~ / CHAN/ && !$args->{'c'}) {
			$mode = 'change';
		} elsif ($curind && $line =~ /1 OBJE/i) {
			$mode = 'source';
		} elsif ($curind && $line =~ /1 SOUR/i) {
			$title = '';
			$mode = 'source';
		} elsif ($line =~ /^\s*[10] /i
				|| ($mode eq 'change' && $lastnum > $num)) {
			$mode = '';
		}

		if ($line =~ /geni:job_title/i) {
			$line =~ s/^[^}]*\} //ig;
			if ($line) {
				print OUT " 1 OCCU $line\n";
			}
		} elsif (
			$mode eq 'source'
			|| ($line =~ /geni:/i && $line !~ /about_me/i)
			|| ($mode eq 'change' && !$args->{'c'})
			|| $line =~ /OCCU/
			|| ($line =~ /ADDR$/ && !$args->{'a'})
			|| ($mode eq 'note' && !$args->{'n'})
			|| (
					($line =~ /STAE/ || $line =~ /CTRY/ || $line =~ /CITY/)
					&& !$args->{'p'}
				)
			|| ($line =~ /_MAR/ && !$args->{'m'})
		) {
			# These are the lines that we are completely removing.
		} elsif ($cmd && array_has($cmd, values %{$citmap})) {
			# print Geni link if there was no about_me section
			if ($args->{'l'} && !$printed_link && (
				$line =~ /FAMS / || $line =~ /FAMC / || $line =~ /SUBM /
			)) {
				$curind =~ /I(\d+)/i;
				print OUT sprintf(
					" 1 NOTE Geni Profile: http://www.geni.com/people/p/%s\n",
					$1
				);
				$printed_link = 1;
			}
			print OUT " " x $num, "$line\n";

			# print Geni link if there was already an about_me section
			if ($args->{'l'} && !$printed_link && $line =~ /about_me/i) {
				$curind =~ /I(\d+)/i;
				$num++;
				print OUT sprintf(
					"%s%s CONT Geni Profile: http://www.geni.com/people/p/%s\n",
					' ' x $num, $num, $1
				);
				$printed_link = 1;
			}
			if ($ppl->{$curind} && $ppl->{$curind}{$cmd}) {
				$num++;
				foreach my $uid (sort {$a <=> $b}
						keys %{$ppl->{$curind}{$cmd}}) {
					print OUT sprintf("%s%s SOUR \@SR%s\@\n",
						' ' x $num, $num, $uid);
				}
				$num--;
			}
		} else {
			print OUT ' ' x $num, "$line\n";
		}
		$lastnum = $num;
	}

	foreach my $uid (sort {$a <=> $b} keys %{$src}) {
		print OUT "0 \@SR", $uid, "\@ SOUR\n";
		print OUT " 1 TITL ", $src->{$uid}, "\n";
	}
	print OUT "0 TRLR\n";
	close OUT;
	print "\nDone, created ", $args->{'o'}, "\n";
}

sub array_has(@) {
	# return 1 if the array contains an element with the desired value
	# return 0 otherwise
	my $element = shift;
	my @array = @_;
	foreach (@array) {
		if ($element == $_) {
			return 1;
		}
	}
	return 0;
}

sub has_source($$) {
	# has_source($ppl->{$curind}{$cit}, $title)
	my $obj = shift;
	my $title = shift;
	foreach my $id (keys %{$ppl->{$curind}{$cit}}) {
		if ($src->{$id} eq $title) {
			return 1;
		}
	}
	return 0;
}

sub usage() {
	return "\tUsage:

    ./sanitize.pl -i gedcom_file [-o output_file] [options]

        Options:

    -a, --addr       Leave the ADDR field, which contains the current
                     location, in place.
    -c, --change     Leave CHAN notes, which contains the dates of past
                     revisions, in place.
    -i, --infile     Input GEDCOM file exported from Geni.com
    -l, --link       Add a link to the Geni.com profile to the about me NOTE.
    -m, --married    Leave the _MAR field, which contains the married name,
                     in place.
    -n, --notes      Leave NOTE elements and their children in place.
    -o, --outfile    Output GEDCOM filename.
    -p, --places     Leave nonstandard children of PLAC elements in place.
                     The PLAC field itself is never removed, regardless
                     of this setting.
";
}
