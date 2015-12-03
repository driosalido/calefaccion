#!/usr/bin/env perl

use strict;
use warnings;
use JSON;

use File::Spec::Functions;
use Data::Dumper;
use Getopt::Std qw(getopts);

my $path = '/sys/bus/w1/devices';
my $LIMIT = 3;
my $indexname = 'home_temp';

my %sensors = (
    '28-000004404452' => 'salon',
);

my %options;
getopts("f:", \%options);

my @files;
foreach my $sensor (keys %sensors){
    push @files , {id => $sensor , file => catfile($path,$sensor,'w1_slave')};
}

my %out;

#Leemos todos los ficheros que podamos , intentamos leer LIMIT veces cada un
foreach my $file (@files){
    my $sensor_data;
    my $retries = 0;
    OPENFILE: while (!$sensor_data && $retries < $LIMIT ) {
      local $/= undef;
      open FILE , $file->{file} or do { warn "can't open file $file->{file}"; $retries++; next OPENFILE; };
      $sensor_data = <FILE>;
      close FILE;
      my $temp = parse_temp($sensor_data);
      if ($temp) {
        my $sensor_name = $sensors{$file->{id}};
	$out{'temp-in'}{$sensor_name}=$temp;
      } else {
        warn "CRC error on sensor $file->{id}";
      }
    }
}
my $json = JSON->new;

print $json->encode(\%out);

sub parse_temp {
    my $data = shift;
    my $temp;
    if ($data && $data =~ m/YES/){
        $data =~ /\.*t=(\d{5})/;
        $temp = ($1/1000);
        $temp = sprintf ("%.1f",$temp);
    } else {
        $temp = undef;
    }
    return $temp;
}
