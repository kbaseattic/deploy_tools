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
my $cfg2 = Config::IniFiles->new( -file => $ARGV[1]);

my @sect1=$cfg1->Sections();
my @sect2=$cfg2->Sections();
my %s1;
my %s2;
my %orsect;
my $ct=0;
map { $s1{$_}=1;$orsect{$_}=$ct; $ct++ } @sect1;
$ct=0;
map { $s2{$_}=1;$orsect{$_}=$ct; $ct++ } @sect2;

#for my $section (@sect1){
#  print "- [$section]\n" if ! defined $s2{$section};
#}
#for my $section (@sect2){
#  print "+ [$section]\n" if ! defined $s1{$section};
#}
for my $s (sort {$orsect{$a}<=>$orsect{$b}}keys %orsect){
  next if ! defined $s2{$s};
  my @p1=$cfg1->Parameters($s);
  my @p2=$cfg2->Parameters($s);
  my %ps1;
  my %ps2;
  my %orset;
  map { $ps1{$_}=1;$orset{$_}=1 } @p1;
  map { $ps2{$_}=1;$orset{$_}=1 } @p2;
  my $header=sprintf "%30s |\n%-30s |\n",'',"[$s]";
  for my $p (sort keys %orset){
    next if defined $ignore{$p};
    my $v1=$cfg1->val($s,$p);
    my $v2=$cfg2->val($s,$p);
    if ($v1 ne $v2){
      print $header;
      $header='';
      printblock($p,$v1,$v2);
      #printf "%-25s |  %-50s  <=>  %-50s\n",$p,$v1,$v2;
    }
  }
}

sub printblock{
  my $p=shift;
  my $v1=shift;
  my $v2=shift;
  my $len=50;

  my $a=substr $v1,0,$len;
  my $b=substr $v2,0,$len;
  my $ar=substr $v1,$len+1;
  my $br=substr $v2,$len+1;
  printf "%-30s |  %-50s  <=>  %-50s\n","$p=",$a,$b;
  while ($ar ne '' || $br ne ''){
    $a=substr $ar,0,$len;
    $b=substr $br,0,$len;
    $ar=substr $ar,$len+1;
    $br=substr $br,$len+1;
    printf "%-30s |  %-50s  <=>  %-50s\n",'',$a,$b;
  }

}
