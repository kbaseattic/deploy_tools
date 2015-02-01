#!/usr/bin/env perl

use lib './perl';
use Config::IniFiles;
use Getopt::Std;
use Data::Dumper;
use strict;

my %opt;
getopts('i:', \%opt);
my %ignore;
map { $ignore{$_}=1;} split /,/,$opt{i};

my $cfg1 = Config::IniFiles->new( -file => $ARGV[0]);

my @sect1=$cfg1->Sections();

my %seen;
for my $s (@sect1){
  for my $p ($cfg1->Parameters($s)){
    print "dupe param [$s] $p\n" if $cfg1->val($s,$p)=~/\n/;
  }
  print "Duplicate [$s]\n" if defined $seen{$s};
  $seen{$s}=1;
  
}

my %urls;
for my $s (@sect1){
  next if $cfg1->val($s,'proxytype') eq 'skip';
  my $url=$s;
  my $urlname=$cfg1->val($s,'urlname');
  $url=$urlname if defined $urlname;
  $urls{$url}=1;
}
for my $s (@sect1){
  for my $p ($cfg1->Parameters($s)){
    my $v=$cfg1->val($s,$p);
    next if $v=~/services.doc/;
    next if $v=~/,/;
    next if $v=~/bio-data-1.mcs.anl/;
    if ($v=~/http.*\/services\//){
      $v=~s/.*services\///;
      $v=~s/\/.*//;
      printf "[%s] %s=%s\n",$s,$p,$cfg1->val($s,$p) if ! defined $urls{$v};
    }
  }
}
