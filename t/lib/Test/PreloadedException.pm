package Test::PreloadedException;

use strict;
use warnings;

# This module defines its exception class via Exception::Class while it is itself being loaded, so
# %INC already points at this file when Exception::Class creates the class.
use Exception::Class (
    'Test::PreloadedException' => { description => 'preloaded' },
);

1;
