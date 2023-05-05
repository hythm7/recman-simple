NAME
====

simple-recman - a very simple recommendation manager for Raku dists.


Overview
========
simple-recman purpose is to process raku dists archives, extract the META6 information and populate an sqlite database. these META6 info can be served via HTTP, so a request like `curl http://localhost/meta/recommend/MyModule` will return the META6 info for MyModule.

To add a raku dist archive to recman:

`raku -I. bin/recman.raku process path/to/archive.tar.gz`

if valid Raku dist archive, and contains a valid META6.json file, the archive will be processed successfully and become available (a copy of it also will be moved to `archive` directory).

To run the HTTP service:

`raku -I. bin/recman.raku serve`

To list available dists that match a name:

`raku -I. bin/recman.raku list MyModule`

To remove a dist from recman:

`raku -I. bin/recman.raku remove MyModule:ver<0.1>:auth<author>:api<>`

AUTHOR
======

Haytham Elganiny <elganiny.haytham@gmail.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2023 Haytham Elganiny

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

