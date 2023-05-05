#!/usr/bin/env raku 

use Recman;

multi MAIN ( 'serve'          ) { Recman.new.serve           }
multi MAIN ( 'process', $file ) { Recman.new.process: :$file }
multi MAIN ( 'remove',  $dist ) { Recman.new.remove:  :$dist }

multi MAIN ( 'list', $spec ) {

  my $regex = / ^ $<name>=[<-[./:<>()\h]>+]+ % '::' [ ':' @<key>=[ver|auth|api] '<' ~ '>' @<val>=<-[<>]>* ]* $ /;

  my $m = $spec ~~ $regex;

  die "{$spec.raku} not valid spec!" unless $m;

  my $name  = $m<name>.Str;
  my %parts = $m<key>.map( *.Str ) Z=> $m<val>.map( *.Str );

  my @dist = Recman.new.list: :$name, |%parts;

  @dist.map( *.say );
  
}
