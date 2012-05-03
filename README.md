geni-rootsweb-gedcom-santizer
=============================

Prepare a Geni.com GEDCOM for uploading to RootsWeb.

Usage:

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

Requirements:
	Any version of perl that supports the array multiplier operator ('x').

This script expects to be passed the filename of a GEDCOM expored from Geni.com
and optionally, the desired filename of the output file. It will read in the
file, convert the sources to a format acceptable to RootsWeb, preserving field
citations; convert geni:occupation to an OCCU field; remove all other geni:
fields; remove last change fields (CHAN); remove extra fields under PLAC, like
STAE, CITY, and CTRY; remove Geni's custom _MAR field which is used for married
names; and remove the ADDR field, which is equivalent to Geni's 'Current
Location' field. Some of these actions can be disabled by setting flags at the
top of the script to 0. If no new filename is passed on commandline, the new
GEDCOM will be written with the same filename as the old one, except that
'-fixed' will be added to the filename before the .ged extension.
