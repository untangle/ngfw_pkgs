#!/usr/bin/env perl

use strict;
use warnings;

use MaxMind::DB::Writer::Tree;

my $filename = ' /var/cache/untangle-geoip/foo.mmdb';

my %types = (
    environments => [ 'array', 'utf8_string' ],
    expires      => 'uint32',
    name         => 'utf8_string',
);

my $tree = MaxMind::DB::Writer::Tree->new(
  database_type => 'GeoCountry',
  description => { en => 'GeoCountry' },
  ip_version => 6,
  map_key_type_callback => sub { $types{ $_[0] } },
  record_size => 32,
);

my %address = (
  '1.2.3.4/28' => {
      environments => [ 'foo', 'bar' ],
      expires      => 3600,
      name         => 'baz',
  },
);

for my $network (keys %address) {
  $tree->insert_network($network, $address{$network});
}

open my $fh, '>:raw', $filename;
print "FOO" . "\n";
$tree->write_tree($fh);
print "BAR" . "\n";
close $fh;
print "BAZ" . "\n";

#!/usr/bin/env perl

use strict;
use warnings;
use feature qw( say );

use Data::Printer;
use MaxMind::DB::Reader;

my $ip = shift @ARGV or die 'Usage: perl examples/02-reader.pl [ip_address]';

my $reader = MaxMind::DB::Reader->new( file => '/var/cache/untangle-geoip/GeoCountry.mmdb' );

my $record = $reader->record_for_address( $ip );
say np $record;
