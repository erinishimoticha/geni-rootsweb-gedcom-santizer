#!/usr/bin/perl

use strict;
package ParseArgs;

###############################################################################
# take a reference to the @ARGV array and return an object
###############################################################################

sub parse($) {
	my $a = shift;
	my $vars;
	for (my $i = 0; $i < scalar @{$a}; $i++) {
		if (${$a}[$i] =~ /^--/) {
			${$a}[$i] =~ s/^--//;
			if (${$a}[$i] =~ /=/) {
				${$a}[$i] =~ /([^=]+)=*([^=]*)/;
				$vars->{$1} = $2 || "";
			} else {
				${$a}[$i] =~ /([^=]+)/;
				$vars->{$1} = 1;
			}
		} elsif (${$a}[$i] =~ /^-/) {
			${$a}[$i] =~ s/^-//;
			foreach (split(//, ${$a}[$i])) {
				$vars->{$_} = 1 if $_;
			}
		} else {
			if (${$a}[$i-1] =~ /^.{1,1}$/ && $vars->{${$a}[$i-1]} == 1) {
				$vars->{${$a}[$i-1]} = ${$a}[$i];
			}
		}
	}
	return $vars;
}

1;
