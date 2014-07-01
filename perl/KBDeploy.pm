package KBDeploy;

use strict;
use warnings;
use Config::IniFiles;
use Switch;
use Data::Dumper;

use Carp;
use Exporter;

$KBDeploy::VERSION = "1.0";

use vars  qw(@ISA @EXPORT_OK);
use base qw(Exporter);

our @ISA    = qw(Exporter);
our @EXPORT = qw(read_config mysystem);

sub read_config {
   my $file=shift;
   my $globaltag=shift;
   my $cfg;
   my $mcfg=new Config::IniFiles( -file => $file) or die "Unable to open $file".$Config::IniFiles::errors[0];

   # Could use the tie option, but let's build it up ourselves

   for my $section ($mcfg->Sections()){
     if ($section eq $globaltag){
       foreach ($mcfg->Parameters($section)){
         $cfg->{$globaltag}->{$_}=$mcfg->val($section,$_);
       }
     }
     else {
       $cfg->{services}->{$section}->{mem}=$cfg->{$globaltag}->{mem};
       $cfg->{services}->{$section}->{cores}=$cfg->{$globaltag}->{cores};
       #$cfg->{services}->{$section}->{host}=$cfg->{$globaltag}->{basename}."-".$section;
       foreach ($mcfg->Parameters($section)){
         $cfg->{services}->{$section}->{$_}=$mcfg->val($section,$_);
       }
       if (! defined $cfg->{services}->{$section}->{type} || $cfg->{services}->{$section}->{type} ne 'lib'){
         push @{$cfg->{servicelist}},$section;
       }
     }
   }
  return $cfg;
}

sub update_config {
   my $file=shift;
   my $section=shift;
   my $param=shift;
   my $value=shift;

   my $mcfg=new Config::IniFiles( -file => $file) or die "Unable to open $file".$Config::IniFiles::errors[0];

   if ( ! defined $mcfg->val($section,$param)){
     $mcfg->newval($section,$param,$value);
   }
   $mcfg->WriteConfig($file);
}


sub mysystem {
  foreach (@_){
    system($_) eq 0 or die "Failed on $_ in $0\n";
  }
}

1;
