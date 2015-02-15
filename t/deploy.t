#!/usr/bin/env perl
use strict;
use Test;
use FindBin;
use lib "$FindBin::Bin/../perl/";
use Data::Dumper;

my $repobase="file:///Users/canon/Dev/gits/";
my $testrepo="kbtestserv";
my $testrepo2="kbtestserv2";
my $repohash="82e4ae592542cdeb76fa32bfebe7f3b7cf6d6567";

my $tdir=$FindBin::Bin;

BEGIN { plan tests => 25 }

# load your module...
use KBDeploy;

my $tf="/tmp/tf.$$.out";
my $cf="/tmp/test.$$.ini";
my $ad="autodeploy.cfg";
my $base="/tmp/dc.$$";
my $lf="/tmp/dep.$$.log";


# Helpful notes.  All note-lines must start with a "#".
print "# I'm testing KBDeploy version $KBDeploy::VERSION\n";

# read_config
print "# Testing reading a config.\n";
my $cfg;
open(C,"> $cf");
print C "[global]\n";
print C "[defaults]\n\n";
print C "[bogus]\n";
print C "type=service\n";
print C "host=myhost\n";
close C;
ok($cfg=KBDeploy::read_config($cf));
#print Dumper($cfg);
# myservices
my @sl=KBDeploy::myservices('myhost');
ok(@sl,1);
ok(@sl[0],'bogus');

# hostlist
my @hl=KBDeploy::hostlist();
ok(@hl,1);
ok(@hl[0],'myhost');


# Make sure things got defined
ok(defined $cfg->{global});
ok(defined $cfg->{defaults});

#Make sure reading a config resets state
$cfg->{bogus}=1;
$cfg=KBDeploy::read_config($cf);
ok(! defined $cfg->{bogus});

# Update_config
ok(! defined $cfg->{defaults}->{bogus});
KBDeploy::update_config($cf,'defaults','bogus',1);
$cfg=KBDeploy::read_config($cf);
ok($cfg->{defaults}->{bogus},1);

# maprepos



# Add check for undefined reponame

#
# Bogus branch
#
open(C,"> $cf");
print C "[global]\n";
print C "repobase=$repobase\n";
print C "[$testrepo]\n";
print C "git-branch=bogus\n";
close C;
$cfg=KBDeploy::read_config($cf);
ok(KBDeploy::mkhashfile($tf),0);
ok(-e "$tf",undef);


#
# Detect duplicates with mismatch
#
open(C,"> $cf");
print C "[global]\n";
print C "repobase=$repobase\n";
print C "[$testrepo]\n";
print C "[$testrepo2]\n";
print C "type=lib\n";
print C "git-branch=dev\n";
print C "giturl=".$repobase."/$testrepo\n";
close C;
$cfg=KBDeploy::read_config($cf);

# Get hash for test repo
print "# tag \n";
ok(KBDeploy::gittag($testrepo));
print "# duplicate mismatch\n";
ok(KBDeploy::mkhashfile($tf),0);
ok(-e "$tf",undef);

#
# Duplicate that is okay
#
my $dc=$base."/dev_container";
open(C,"> $cf");
print C "[global]\n";
print C "repobase=$repobase\n";
print C "devcontainer=$dc\n";
print C "default-modules=\n";
print C "[dev_container]\n";
print C "type=lib\n";
print C "[$testrepo]\n";
print C "[$testrepo2]\n";
print C "type=lib\n";
print C "giturl=".$repobase."/$testrepo\n";
close C;

# Write out a hashfile
$cfg=KBDeploy::read_config($cf);
ok(KBDeploy::mkhashfile($tf),1);

#
# Read back the hashfile
#
ok(KBDeploy::readhashes($tf));
ok(defined $cfg->{services}->{$testrepo}->{hash});

# TOD: test updatehashfile

# Test clonetag
print "# test clonetag $testrepo\n";
mkdir("$base") or die "Unable to create $base";
chdir("$base");
mkdir("$base/dev_container");
KBDeploy::clonetag($testrepo);

#This comes from update fix
#ok(defined $cfg->{deployed}->{$testrepo});
#ok($cfg->{deployed}->{$testrepo}->{hash},$repohash);


#
# Test read/write githash
#
my $gh="/tmp/gh.$$.out";
#KBDeploy::write_githash($gh);


#
# mark complete
KBDeploy::mark_complete();
ok(-e $dc."/".$cfg->{global}->{hashfile});


# Re-read config to reset state
#$cfg=KBDeploy::read_config($cf);

# is_complete
ok(KBDeploy::is_complete());

#ok(!defined $cfg->{deployed}->{$testrepo});
#KBDeploy::read_githash($gh);
#ok(defined $cfg->{deployed}->{$testrepo});


KBDeploy::reset_complete();
ok(! -e $dc."/".$cfg->{global}->{hashfile});
ok(KBDeploy::is_complete(),0);

`rm -rf $base/$testrepo`;
`rm -rf $dc`;

KBDeploy::deploy_devcontainer($lf);
ok(-e $dc);
chdir($dc."/modules");
KBDeploy::clonetag($testrepo);
chdir($dc);

ok(KBDeploy::generate_autodeploy($ad));
ok(-e $dc.'/'.$ad);

# Cleanup
unlink($cf);
unlink($tf);
unlink($gh);
unlink($dc."/".$cfg->{global}->{hashfile}.'.old');
#`rm -rf $dc/dev_container/`;
rmdir $dc;



# getdeps
# start_service
# stop_service
# test_service
# prepare_service
# check_updates
# auto_deploy
# deploy_service
# update_service
# postprocess
# mkdocs



