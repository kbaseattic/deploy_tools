#!/usr/bin/env perl
use strict;
use Test;
use FindBin;
use lib "$FindBin::Bin/../perl/";

BEGIN { plan tests => 7 }

# load your module...
use KBProvision;

# Helpful notes.  All note-lines must start with a "#".
print "# I'm testing KBProvision version $KBProvision::VERSION\n";

my $host="test01";
my $group="testg";

`rpower $host off;rmvm $host -p;noderm $host`;
#
my $scfg;
$scfg->{mem}="1g";
$scfg->{cores}="1";
$scfg->{alias}="test-bogus";
$scfg->{baseimage}="ubuntu12.04.3berk3";
$scfg->{xcatgroups}="testg,vm,all";

ok(KBProvision::config_host($host,'bogus',$scfg));

# Test assignments
my $l=KBProvision::assignments($group);
ok($l->{$host},'bogus');
ok($l->{blah},undef);


# Boot node
ok(KBProvision::boot_nodes($host),1);

sleep 5;

# Test sync_files
my $file="t$$.out";
open(T,"> $file");
print T "Test file\n";
close T;
ok(KBProvision::sync_files($host,'/tmp',$file));
ok(KBProvision::sync_files($host,'/xxxx',$file),0);
unlink $file;

ok(KBProvision::run_remote($host,"rm /tmp/$file"));

# Test boot_nodes

