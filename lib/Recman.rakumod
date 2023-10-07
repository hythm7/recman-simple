use Cro::HTTP::Server;
use Cro::HTTP::Router;
use Cro::HTTP::Log::File;
use Libarchive::Read;

use Recman::DB;
  
unit class Recman;

has $!host = %*ENV<RECMAN_HOST> // 'localhost';
has $!port = %*ENV<RECMAN_PORT> // 4242;
has $!db   = Recman::DB.new;
  
method recommend (

    Str:D :$name!,
    Str   :$ver,
    Str   :$auth,
    Str   :$api

  ) {

  my %spec;

  %spec<ver>  = $ver  if defined $ver;
  %spec<auth> = $auth if defined $auth;
  %spec<api>  = $api  if defined $api;

  my @candy = $!db.select-by-name: :$name;

  @candy .= grep( -> %candy { match-spec %candy, %spec } );

  unless @candy {

    @candy = $!db.select-by-provides: :$name;

    @candy .= grep( -> %candy { match-spec %candy, %spec } );

  }

  return not-found unless @candy;

  # because v0.2.1 ~~ v0.2
  # to be able to recommend exact v0.2
  if %spec<ver>:exists {
    @candy .= grep( -> %candy { %candy<ver> ~~ %spec<ver> } ) unless %spec<ver>.contains( / <[*+-]> / );
  }

  if %spec<api>:exists {
    @candy .= grep( -> %candy { %candy<api> ~~ %spec<api> } ) unless %spec<api>.contains( / <[*+-]> / );
  }

  @candy.reduce( &reduce-latest ).<meta>;

}


method search (

    Str:D :$name!,
    Str   :$ver,
    Str   :$auth,
    Str   :$api,
    Str   :$latest,
    Str   :$relaxed,
    Str   :$count,

  ) {

  my %spec;

  %spec<ver>  = $ver  if defined $ver;
  %spec<auth> = $auth if defined $auth;
  %spec<api>  = $api  if defined $api;

  my @candy = $!db.search: :$name :$relaxed;

  @candy .= grep( -> %candy { match-spec %candy, %spec } );

  return not-found unless @candy;

  @candy .= sort( -> %left, %right {
    quietly ( %right<name> ~~ / :i ^ $name / ) cmp ( %left<name> ~~ / :i ^ $name / ) || 
    quietly ( %right<name> ~~ / :i   $name / ) cmp ( %left<name> ~~ / :i   $name / ) ||
    %left<name> cmp %right<name>                                                     ||
    sort-latest( %left, %right );
  }); 

  @candy .= squish: as => *.<name> if $latest;

  @candy .= head( $count ) if $count;

  Rakudo::Internals::JSON.to-json: :pretty, :sorted-keys, @candy.map: { Rakudo::Internals::JSON.from-json: .<meta> };

}

method meta ( ) {

  Rakudo::Internals::JSON.to-json(
    :pretty,
    :sorted-keys,
    $!db.meta.sort( -> %left, %right {

      %left<name> cmp %right<name> ||
      sort-latest( %left, %right );
       
    }).map( { Rakudo::Internals::JSON.from-json: .<meta> } );
  );
}

method serve ( ) {

  my Cro::Service $http = Cro::HTTP::Server.new(
  
    http => <1.1>,
  
    host => $!host || die("Missing RECMAN_HOST in environment"),
    port => $!port || die("Missing RECMAN_PORT in environment"),
  
    application => self!routes,
  
    after => [
        Cro::HTTP::Log::File.new(logs => $*OUT, errors => $*ERR)
    ]
  
  );
  
  $http.start;
  
  say "Listening at http://$!host:$!port>";
  
  react {

    whenever signal(SIGINT) {
        say "Shutting down...";
        $http.stop;
        done;

    }
  
  }

}


method !routes ( ) {

  route {

    get -> 'meta', 'recommend', Str:D $name, Str :$ver, Str :$auth, Str :$api {

      content 'applicationtext/json', self.recommend: :$name :$ver :$auth :$api;

    }

    get -> 'meta', 'search', Str:D $name, Str :$ver, Str :$auth, Str :$api, Str :$relaxed, Str :$latest, :$count {

      content 'applicationtext/json', self.search: :$name :$ver :$auth :$api, :$relaxed, :$latest, :$count;

    }
    get -> 'meta' {

      content 'applicationtext/json', self.meta;

    }
    get -> 'archive', *@path { static 'archive', @path }

  }

}


method process ( IO() :$file! ) {

  #say "Processing $file";

  my $archive := Libarchive::Read.new( $file );

  my %meta;

  for $archive {

    if .pathname.ends-with: 'META6.json' and $*SPEC.splitdir( .pathname.IO.dirname ) == 1 {

      #say "Found { .pathname }";
      %meta = Rakudo::Internals::JSON.from-json( .content );
      last;
    }
  }

  die 'No valid META6.json found' unless %meta;



  my Str:D $name = %meta<name>;
  my $ver  = %meta<version>;
  my $auth = %meta<auth>;
  my $api  = %meta<api>;

  my $dist = quietly "{$name}:ver<$ver>:auth<$auth>:api<$api>";

  my $nameid = id( $name );
  my $distid = id( $dist );

  die "$dist already exists" if $!db.exists-distid: $distid;

  my $path = 'archive'.IO.add( $nameid ).add( $distid ~ '.tar.gz' );

  my $source = "http://$!host:$!port/" ~ $path;

  %meta<source> = $source;

  my $meta = Rakudo::Internals::JSON.to-json( %meta );

  say $dist;

  $!db.insert-into-dist(

    :$distid,
    :$meta,
    :$name,
    :$ver,
    :$auth,
    :$api,
    :$dist,
    :$source,

  );

  # TODO: insert depeendencies
  

  %meta<provides>.grep( *.defined ).map( { $!db.insert-into-provides: :$distid, unit => .key, file => .value } ) ;

  %meta<resources>.grep( *.defined ).map( -> $resource { try $!db.insert-into-resources: :$distid, :$resource } ) ;

  %meta<emulates>.grep( *.defined ).map( { $!db.insert-into-emulates: :$distid, unit => .key, use => .value } ) ;

  %meta<supersedes>.grep( *.defined ).map( { $!db.insert-into-supersedes: :$distid, unit => .key, use => .value } ) ;

  %meta<superseded-by>.grep( *.defined ).map( { $!db.insert-into-superseded: :$distid, unit => .key, use => .value } ) ;

  %meta<excludes>.grep( *.defined ).map( { $!db.insert-into-excludes: :$distid, unit => .key, use => .value } ) ;

  %meta<authors>.grep( *.defined ).map( -> $author { $!db.insert-into-author: :$distid, :$author } ) ;

  %meta<tags>.grep( *.defined ).map( -> $tag { $!db.insert-into-tag: :$distid, :$tag } ) ;

  mkdir $path.dirname;

  $file.copy( $path );
}

method list ( Str:D :$name!, Str :$ver, Str :$auth, Str :$api ) {


  my %spec;


  %spec<ver>  = $ver  if defined $ver;
  %spec<auth> = $auth if defined $auth;
  %spec<api>  = $api  if defined $api;

  my @candy = $!db.search: :$name;

  @candy .= grep( -> %candy { match-spec %candy, %spec } );


  @candy .= sort( &sort-latest );

  @candy.map( {

    my %meta = Rakudo::Internals::JSON.from-json: .<meta>;

    my $ver  = %meta<version>;
    my $auth = %meta<auth>;
    my $api  = %meta<api>;

    quietly "{ %meta<name> }:ver<$ver>:auth<$auth>:api<$api>";

  } );


}

method remove ( Str:D :$dist! ) {

  my $distid = id( $dist );

  die "$dist does not exist" unless $!db.exists-distid: $distid;

  $!db.delete-dist: $dist;
}


my sub id ( Str:D $name ) { use nqp; nqp::sha1( $name ) }

my sub match-spec ( %candy, %spec --> Bool ) {

  do return False unless %candy<auth> ~~ %spec<auth> if %spec<auth>;

  do return False unless Version.new( %candy<ver> ) ~~ Version.new( %spec<ver> ) if %spec<ver>;
  do return False unless Version.new( %candy<api> ) ~~ Version.new( %spec<api> ) if %spec<api>;

  True;

}

my sub reduce-latest ( %left, %right ) {

  return %left if         Version.new( %left<ver> ) > Version.new( %right<ver> );
  return %left if quietly Version.new( %left<api> ) > Version.new( %right<api> );
  return %right;

}

my sub sort-latest ( %left, %right ) {

  ( Version.new( %right<ver> ) cmp Version.new( %left<ver> ) ) or quietly
  ( Version.new( %right<api> ) cmp Version.new( %left<api> ) );

}

#my sub sort-all ( %left, %right ) {
#
#  %left<name> cmp %right<name> ||
#    quietly ( Version.new( %right<ver> ) cmp Version.new( %left<ver> ) ) or quietly
#    ( Version.new( %right<api> ) cmp Version.new( %left<api> ) );
#
#}

