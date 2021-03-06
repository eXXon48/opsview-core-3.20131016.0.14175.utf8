#
# AUTHORS:
#	Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#    This file is part of Opsview
#
#    Opsview is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    Opsview is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Opsview; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
package Runtime::Schema::NagiosObjects;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components( "Core" );
__PACKAGE__->table( "nagios_objects" );
__PACKAGE__->add_columns(
    "object_id",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "instance_id",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "objecttype_id",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "name1",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 128
    },
    "name2",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
    "is_active",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
);
__PACKAGE__->set_primary_key( "object_id" );

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-07-16 21:28:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FweOfvhWdniErQTvOgiaEA

__PACKAGE__->has_many(
    "events",
    "Runtime::Schema::NagiosStatehistory",
    { "foreign.object_id" => "self.object_id" },
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
