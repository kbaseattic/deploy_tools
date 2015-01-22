#!/usr/bin/env perl

open(I,$ARGV[0]);
while(<I>){
  s/pwd=.*/pwd=xxxxxxxx/;
  if (/mongodb:\/\//){
    s/:.*@/:xxxxxxxx@/;
  }
  s/pass=.*/pass=xxxxxxxx/;
  s/Pwd=.*/Pwd=xxxxxxxx/;
  s/\/.*/\/xxxxxxxx/ if /userData=/;
  s/token=.*/token=<kbasetoken>/;
  s/secret=.*/secret=<secret>/;
  s/^host=.*/host=<XXXXX>/;
  print;
}

