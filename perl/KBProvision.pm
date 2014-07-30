package KBProvision;

use strict;
use warnings;
use Data::Dumper;

use Carp;
use Exporter;

$KBProvision::VERSION = "1.0";

use vars  qw(@ISA @EXPORT_OK);
use base qw(Exporter);

our @ISA    = qw(Exporter);
our @EXPORT = qw();

our $xg;

our $debug=0;

# Wrapper for system
sub mysystem {
  foreach (@_){
    system($_) eq 0 or die "Failed on $_ in $0\n";
  }
}

# Propogate a list of files to the basedir on each node
#
sub sync_files {
   my $xg=shift;
   my $basedir=shift;
   my $fl=join " ",@_;
   return 1 if $fl eq '';
   system("xdcp $xg $fl $basedir/ > /dev/null 2>&1");
   return 1 if $? eq 0;
   return 0;
}

sub assignments {
  my $xg=shift;
  my $assign;
  # Get a list of configured services and used nodes
  open(L,"nodels $xg nodelist.comments|");
  while(<L>){
    chomp;
    my ($host,$service)=split /: /;
    #$assign->{$host}=$service if $service ne ''; 
    $assign->{$host}=1 if $service ne ''; 
  }
  close L;
  return $assign;
}

#
# Boot all nodes and wait for them to come up.
# TODO: add a timeout
#
sub boot_nodes {
  my $xg=shift;
  my $ct=0;
  mysystem("rpower $xg on > /dev/null");
  while(system("nodestat $xg|grep -vc sshd > /dev/null") eq 0){
    sleep 5;
    $ct++;
    return 0 if $ct > 12;
  }
  return 1;
}

#
# Configure a host for a service
#
sub config_host{
  my $host=shift;
  my $service=shift;
  my $scfg=shift;

  my $mem=$scfg->{mem};
  my $cores=$scfg->{cores};
  my $alias=$scfg->{alias};
  my $base=$scfg->{baseimage};
  $scfg->{host}=$host;

  print "Configuring $host for $service with $mem and $cores cores\n" if $debug;
  system("nodels $host > /dev/null 2>&1");
  if ($? ne 0 ){
    print STDERR "Adding $host\n" if $debug;
    mysystem("nodeadd $host groups=$scfg->{xcatgroups}");
  }
  mysystem("nodech $host nodelist.comments=$service");
  mysystem("nodech $host vm.memory=$mem vm.cpus=$cores hosts.hostnames=$alias");
  mysystem("clonevm $host -b ".$base);
  if (defined $scfg->{disk}){
    foreach my $size (split /,/,$scfg->{disk}){
      mysystem("chvm $host -a $size");
    }
  }
  # Post creation
  mysystem("makehosts $host");
  mysystem("makeconservercf $host");
  mysystem("makedhcp $host");
  return 1;
}

sub run_remote_all{
  my $group=shift;
  my $command=shift;  
  mysystem("xdsh $group \"$command\"");
  return 1;
}

sub run_remote{
  my $host=shift;
  my $command=shift;  
  mysystem("ssh $host \"$command\"");
  return 1;
}

1;
