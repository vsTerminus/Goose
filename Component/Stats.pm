package Component::Stats;

use feature 'say';

use Moo;
use strictures 2;

use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(add_command);

has db  => ( is => 'ro' );

sub add_command
{
    my ($self, %args) = @_;

    return $self->db->query("INSERT into stats_commands VALUES ( ?, ?, ?, ?, ? );", 
                $args{'command'},
                $args{'channel_id'},
                $args{'user_id'},
                $args{'timestamp'},
                $args{'msg'}
            );
}

1;
