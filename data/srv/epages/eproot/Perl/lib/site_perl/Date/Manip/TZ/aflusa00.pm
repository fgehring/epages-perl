package Date::Manip::TZ::aflusa00;
# Copyright (c) 2008-2011 Sullivan Beck.  All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

# This file was automatically generated.  Any changes to this file will
# be lost the next time 'tzdata' is run.
#    Generated on: Fri Apr 15 08:11:57 EDT 2011
#    Data version: tzdata2011f
#    Code version: tzcode2011e

# This module contains data from the zoneinfo time zone database.  The original
# data was obtained from the URL:
#    ftp://elsie.nci.nih.gov/pub

=pod

=head1 NAME

Date::Manip::TZ::aflusa00 - Support for the Africa/Lusaka time zone

=head1 SYNPOSIS

This module contains data from the Olsen database for the time zone. It
is not intended to be used directly (other Date::Manip modules will
load it as needed).

=cut

use strict;
use warnings;
require 5.010000;

our (%Dates,%LastRule);
END {
   undef %Dates;
   undef %LastRule;
}

our ($VERSION);
$VERSION='6.23';
END { undef $VERSION; }

%Dates         = (
   1    =>
     [
        [ [1,1,2,0,0,0],[1,1,2,1,53,8],'+01:53:08',[1,53,8],
          'LMT',0,[1903,2,28,22,6,51],[1903,2,28,23,59,59],
          '0001010200:00:00','0001010201:53:08','1903022822:06:51','1903022823:59:59' ],
     ],
   1903 =>
     [
        [ [1903,2,28,22,6,52],[1903,3,1,0,6,52],'+02:00:00',[2,0,0],
          'CAT',0,[9999,12,31,0,0,0],[9999,12,31,2,0,0],
          '1903022822:06:52','1903030100:06:52','9999123100:00:00','9999123102:00:00' ],
     ],
);

%LastRule      = (
);

1;
