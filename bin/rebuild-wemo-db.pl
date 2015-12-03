#!/usr/bin/perl

use WebService::Belkin::WeMo::Device;
use WebService::Belkin::WeMo::Discover;
use Data::Dumper;
use strict;
use warnings;

my $wemoDiscover = WebService::Belkin::WeMo::Discover->new();
my $discovered = $wemoDiscover->search();
$wemoDiscover->save("/etc/belkin.db");

foreach my $ip (keys %{$discovered}) {
	print "IP = $ip\n";
	print "Friendly Name = $discovered->{$ip}->{'name'}\n"
}
