#!/usr/bin/perl

use strict;
use Data::Dumper;

# Whether or not to remove CHAN notes, which indicate when the
# field was last updated.
my $REMOVE_CHANGE_NOTES = 1;

# Wether or not to remove STAE, CITY, and CTRY fields, which are under the
# PLAC field.  I believe this is always recommended, as I have not
# encountered an instance yet where these were set and PLAC was not.
my $REMOVE_EXTRA_PLAC_FIELDS = 1;

# Remove the _MAR field, which is Geni-specific.
my $REMOVE_MAIDEN_NAMES = 1;

# Remove ADDR, which is equivalent to Geni's Current Location field.
my $REMOVE_ADDR = 1;

# Remove NOTE. I don't know what these are used for in Geni. I cannot find
# these entries in the Geni.com web UI.
my $REMOVE_NOTE = 1;

# Convert OBJE type sources into SOUR type sources.
# Places SOUR objects under the field they provide a citation for.
# Define all SOUR objects at the end of the file.
# Rename geni:occupation to OCCU

my (
	$curind, $mode, $src, $ppl,
	$lines, $line, $title, $cit,
	$citmap, @filecontent
);
my $srcidx = 101;
my $file = shift;
my $newfile = shift;
$| = 1;

init();
read_file();
write_file();

sub init() {
	# Check that we were given a file and set up some variables.
	if (!$file) {
		print "No file given.\n";
		exit 1;
	}

	if (!$newfile) {
		$newfile = $file;
		$newfile =~ s/\.(\w+)$/-fixed.$1/ig;
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
	print "Reading in $file ";
	open INF, $file;
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

	print "\n I found ", scalar keys %{$src}, " sources and ",
		scalar keys %{$ppl}, " people\nWriting file ";
}

sub write_file() {
	my ($curind, $mode, $line, $title, $cit, $num, $lastnum);
	open OUT, ">$newfile";
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
		} elsif ($curind && $line =~ /0 TRLR/i) {
			$mode = 'source';
		} elsif ($curind && $line =~ / CHAN/ && $REMOVE_CHANGE_NOTES) {
			$mode = 'change';
		} elsif ($curind && $line =~ /1 OBJE/i) {
			$mode = 'source';
		} elsif ($curind && $line =~ /1 SOUR/i) {
			$title = '';
			$mode = 'source';
		} elsif ($line =~ /^\s+[10] /i
				|| ($mode eq 'change' && $lastnum > $num)) {
			$mode = '';
		}

		if ($line =~ /geni:job_title/i) {
			$line =~ s/^[^}]*\} //ig;
			if ($line) {
				print OUT " 1 OCCU $line\n";
			}
		} elsif ($mode eq 'source' || $line =~ /geni:/i || ($mode eq 'change'
					&& $REMOVE_CHANGE_NOTES)
				|| $line =~ /OCCU/ || ($line =~ /ADDR$/ && $REMOVE_ADDR)
				|| ($line =~ /1 NOTE/ && $REMOVE_NOTE)
				|| (($line =~ /STAE/ || $line =~ /CTRY/ || $line =~ /CITY/)
					&& $REMOVE_EXTRA_PLAC_FIELDS)
				|| ($line =~ /_MAR/ && $REMOVE_MAIDEN_NAMES)) {
			# These are the lines that we are completely removing.
		} elsif ($cmd && array_has($cmd, values %{$citmap})) {
			print OUT " " x $num, "$line\n";
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
	print "\nDone, created $newfile\n";
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
