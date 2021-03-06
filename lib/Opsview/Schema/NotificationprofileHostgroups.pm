package Opsview::Schema::NotificationprofileHostgroups;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".notificationprofile_hostgroups"
);
__PACKAGE__->add_columns(
    "notificationprofileid",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "hostgroupid",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
);
__PACKAGE__->set_primary_key( "notificationprofileid", "hostgroupid" );
__PACKAGE__->belongs_to(
    "notificationprofile",
    "Opsview::Schema::Notificationprofiles",
    { id => "notificationprofileid" },
);
__PACKAGE__->belongs_to( "hostgroup", "Opsview::Schema::Hostgroups",
    { id => "hostgroupid" },
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2010-03-16 12:52:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WMvZmiJDSeUIliLwkqqaSQ

# You can replace this text with custom content, and it will be preserved on regeneration
1;
