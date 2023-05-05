use DB::SQLite;
  
unit class Recman::DB;

has $!db;

submethod TWEAK ( ) {

  $!db = DB::SQLite.new: filename => %?RESOURCES<db/recman.sqlite>.Str;
  self!db-schema();
  self!pragma-enable-foreign-key( )

}

method insert-into-dist (
    :$distid!,
    :$meta!,
    :$name!,
    :$ver!,
    :$auth!,
    :$api!,
    :$dist!,
    :$source!
    --> Int
  ) {

  $!db.query( q:to/SQL/, :$distid, :$meta, :$name, :$ver, :$auth, :$api, :$dist, :$source );
  INSERT INTO 'dist' (
    'distid', 'meta', 'name', 'ver', 'auth', 'api', 'dist', 'source'
    )
    VALUES (
      $distid, $meta, $name, $ver, $auth, $api, $dist, $source
    )
    ON CONFLICT DO NOTHING;
  SQL
}

method insert-into-provides (
    :$distid!,
    :$unit!,
    :$file!
    --> Int
  ) {

  $!db.query( q:to/SQL/, :$distid, :$unit, :$file );
  INSERT INTO 'provides' ('distid', 'unit', 'file' )
    VALUES ( $distid, $unit, $file )
    ON CONFLICT DO NOTHING;
  SQL
}

method insert-into-dep (
    :$distid!,
    :$phase!,
    :$need!,
    :$use!
    --> Int
  ) {

  $!db.query( q:to/SQL/, :$distid, :$phase, :$need, :$use );
  INSERT INTO 'dep' ('distid', 'phase', 'need', 'use' )
    VALUES ( $distid, $phase, $need, $use )
    ON CONFLICT DO NOTHING;
  SQL
}


method insert-into-resources (
    :$distid!,
    :$resource!
    --> Int
  ) {

  $!db.query( q:to/SQL/, :$distid, :$resource );
  INSERT INTO 'resources' ('distid', 'resource' )
    VALUES ( $distid, $resource )
    ON CONFLICT DO NOTHING;
  SQL
}

method insert-into-emulates (
    :$distid!,
    :$unit!,
    :$use!
    --> Int
  ) {

  $!db.query( q:to/SQL/, :$distid, :$unit, :$use );
  INSERT INTO 'emulates' ('distid', 'unit', 'use' )
    VALUES ( $distid, $unit, $use )
    ON CONFLICT DO NOTHING;
  SQL
}

method insert-into-supersedes (
    :$distid!,
    :$unit!,
    :$use!
    --> Int
  ) {

  $!db.query( q:to/SQL/, :$distid, :$unit, :$use );
  INSERT INTO 'supersedes' ('distid', 'unit', 'use' )
    VALUES ( $distid, $unit, $use )
    ON CONFLICT DO NOTHING;
  SQL
}

method insert-into-superseded (
    :$distid!,
    :$unit!,
    :$use!
    --> Int
  ) {

  $!db.query( q:to/SQL/, :$distid, :$unit, :$use );
  INSERT INTO 'superseded-by' ('distid', 'unit', 'use' )
    VALUES ( $distid, $unit, $use )
    ON CONFLICT DO NOTHING;
  SQL
}

method insert-into-excludes (
    :$distid!,
    :$unit!,
    :$use!
    --> Int
  ) {

  $!db.query( q:to/SQL/, :$distid, :$unit, :$use );
  INSERT INTO 'excludes' ('distid', 'unit', 'use' )
    VALUES ( $distid, $unit, $use )
    ON CONFLICT DO NOTHING;
  SQL
}

method insert-into-author (
    :$distid!,
    :$author!
    --> Int
  ) {

  $!db.query( q:to/SQL/, :$distid, :$author );
  INSERT INTO 'author' ('distid', 'author' )
    VALUES ( $distid, $author )
    ON CONFLICT DO NOTHING;
  SQL
}

method insert-into-tag (
    :$distid!,
    :$tag!
    --> Int
  ) {

  $!db.query( q:to/SQL/, :$distid, :$tag );
  INSERT INTO 'tag' ('distid', 'tag' )
    VALUES ( $distid, $tag )
    ON CONFLICT DO NOTHING;
  SQL
}

method delete-dist (
    $dist,
    --> Int
  ) {
  $!db.query( q:to/SQL/, :$dist );
  DELETE from dist where dist = $dist;
  SQL
}

method select-by-name( Str:D :$name! ) {

  $!db.query( q:to/SQL/, :$name ).hashes;
  SELECT ver, auth, api, meta
    FROM      dist
    WHERE     name = $name;
  SQL
}

method select-by-provides( Str:D :$name! ) {

  $!db.query( q:to/SQL/, :$name ).hashes;
  SELECT ver, auth, api, meta
    FROM      provides
    INNER JOIN dist
    ON        provides.distid = dist.distid
    WHERE     unit = $name;
  SQL
}

method search( Str:D :$name!, Str :$relaxed ) {

  my $search = $name;

  $search = '%' ~ $search ~ '%' if $relaxed;

  $!db.query( q:to/SQL/, :$search ).hashes;
  SELECT DISTINCT name, ver, auth, api, meta
    FROM      dist
    INNER JOIN provides
    ON        dist.distid = provides.distid
    WHERE     name like $search OR unit like $search;
  SQL
}

method meta( ) {

  $!db.query( q:to/SQL/).hashes;
  SELECT name, ver, auth, api, meta
    FROM dist
    ORDER BY name;
  SQL
}


method exists-distid ( Str:D $distid! --> Bool:D ) {

  $!db.query( q:to/SQL/, :$distid ).value.Bool;
  SELECT EXISTS(SELECT 1 FROM dist WHERE distid = $distid);
  SQL

}

method !db-schema( ) {

  self!create-table-dist( );
  self!create-index-dist-name( );
  self!create-index-dist-dist( );
  self!create-index-dist-distid( );
  self!create-table-provides( );
  self!create-index-provides-distid( );
  self!create-index-provides-unit( );
  self!create-table-dep( );
  self!create-table-resources( );
  self!create-table-emulates( );
  self!create-table-supersedes( );
  self!create-table-superseded( );
  self!create-table-excludes( );
  self!create-table-author( );
  self!create-table-tag( );

}

method !create-table-dist( ) {

  $!db.execute( q:to/SQL/);
  CREATE TABLE IF NOT EXISTS 'dist' (
  
    'distid' TEXT  NOT NULL,
    'meta'   TEXT  NOT NULL,
    'name'   TEXT  NOT NULL,
    'ver'    TEXT          ,
    'auth'   TEXT          ,
    'api'    TEXT          ,
    'dist'   TEXT  NOT NULL,
    'source' TEXT  NOT NULL,
  
    PRIMARY KEY ( distid )
  );
  SQL
  
}

method !create-index-dist-name( ) {

  $!db.execute( q:to/SQL/);
  CREATE INDEX IF NOT EXISTS index_dist_name ON dist ( name );
  SQL

}

method !create-index-dist-dist( ) {

  $!db.execute( q:to/SQL/);
  CREATE INDEX IF NOT EXISTS index_dist_dist ON dist ( dist );
  SQL

}

method !create-index-dist-distid( ) {

  $!db.execute( q:to/SQL/);
  CREATE INDEX IF NOT EXISTS index_dist_distid ON dist ( distid );
  SQL

}


method !create-table-provides( ) {

  $!db.execute( q:to/SQL/);
  CREATE TABLE IF NOT EXISTS 'provides' (
  
    'distid' TEXT NOT NULL,
    'unit'   TEXT NOT NULL,
    'file'   TEXT NOT NULL,
  
    PRIMARY KEY ( distid, unit )
  
    FOREIGN KEY ( distid ) REFERENCES dist ( distid )
    ON DELETE CASCADE
    ON UPDATE CASCADE
  );
  SQL
}

method !create-index-provides-distid( ) {

  $!db.execute( q:to/SQL/);
  CREATE INDEX IF NOT EXISTS index_provides_distid ON provides ( distid );
  SQL

}

method !create-index-provides-unit( ) {

  $!db.execute( q:to/SQL/);
  CREATE INDEX IF NOT EXISTS index_provides_unit ON provides ( unit );
  SQL

}



method !create-table-dep( ) {

  $!db.execute( q:to/SQL/);
  CREATE TABLE IF NOT EXISTS 'dep' (

    'distid'  TEXT NOT NULL,
    'phase'   TEXT NOT NULL,
    'need'    TEXT NOT NULL,
    'use'     TEXT NOT NULL,

    PRIMARY KEY ( distid, phase, need, use )

    FOREIGN KEY ( distid ) REFERENCES dist ( distid )
    ON DELETE CASCADE
    ON UPDATE CASCADE
  );
  SQL
}


method !create-table-resources( ) {

  $!db.execute( q:to/SQL/);
  CREATE TABLE IF NOT EXISTS 'resources' (

    'distid'   TEXT NOT NULL,
    'resource' TEXT NOT NULL,

    PRIMARY KEY ( distid, resource )

    FOREIGN KEY ( distid ) REFERENCES dist ( distid )
    ON DELETE CASCADE
    ON UPDATE CASCADE
  );
  SQL
}

method !create-table-emulates( ) {

  $!db.execute( q:to/SQL/);
  CREATE TABLE IF NOT EXISTS 'emulates' (

    'distid' TEXT NOT NULL,
    'unit'   TEXT NOT NULL,
    'use'    TEXT NOT NULL,

    PRIMARY KEY ( distid, unit )

    FOREIGN KEY ( distid ) REFERENCES dist ( distid )
    ON DELETE CASCADE
    ON UPDATE CASCADE
  );
  SQL
}

method !create-table-supersedes( ) {

  $!db.execute( q:to/SQL/);
  CREATE TABLE IF NOT EXISTS 'supersedes' (

    'distid' TEXT NOT NULL,
    'unit'   TEXT NOT NULL,
    'use'    TEXT NOT NULL,

    PRIMARY KEY ( distid, unit )

    FOREIGN KEY ( distid ) REFERENCES dist ( distid )
    ON DELETE CASCADE
    ON UPDATE CASCADE
  );
  SQL
}

method !create-table-superseded( ) {

  $!db.execute( q:to/SQL/);
  CREATE TABLE IF NOT EXISTS 'superseded-by' (

    'distid' TEXT NOT NULL,
    'unit'   TEXT NOT NULL,
    'use'    TEXT NOT NULL,

    PRIMARY KEY ( distid, unit )

    FOREIGN KEY ( distid ) REFERENCES dist ( distid )
    ON DELETE CASCADE
    ON UPDATE CASCADE
  );
  SQL
}

method !create-table-excludes( ) {

  $!db.execute( q:to/SQL/);
  CREATE TABLE IF NOT EXISTS 'excludes' (

    'distid' TEXT NOT NULL,
    'unit'   TEXT NOT NULL,
    'use'    TEXT NOT NULL,

    PRIMARY KEY ( distid, unit, use )

    FOREIGN KEY ( distid ) REFERENCES dist ( distid )
    ON DELETE CASCADE
    ON UPDATE CASCADE
  );
  SQL
}

method !create-table-author( ) {

  $!db.execute( q:to/SQL/);
  CREATE TABLE IF NOT EXISTS 'author' (

    'distid'   TEXT NOT NULL,
    'author'   TEXT NOT NULL,

    PRIMARY KEY ( distid , author )

    FOREIGN KEY ( distid ) REFERENCES dist ( distid )
    ON DELETE CASCADE
    ON UPDATE CASCADE
  );
  SQL
}

method !create-table-tag( ) {

  $!db.execute( q:to/SQL/);
  CREATE TABLE IF NOT EXISTS 'tag' (

    'distid' TEXT NOT NULL,
    'tag'    TEXT NOT NULL,

    PRIMARY KEY ( distid , tag )

    FOREIGN KEY ( distid ) REFERENCES dist ( distid )
    ON DELETE CASCADE
    ON UPDATE CASCADE
  );
  SQL
}

method !pragma-enable-foreign-key( ) {

  $!db.execute( q:to/SQL/);
  PRAGMA foreign_keys = ON;
  SQL

}
