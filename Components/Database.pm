package Components::Database;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(query);

use DBI;
use Data::Dumper;

# This module exists to make it easier to include the database in command modules.
# The modules don't have to care about connection info or manually connecting, they can just call this module's 'do' function.

sub new
{
    my ($class, %params) = @_;
    my $self = {};
    
    $self->{'type'} = $params{'type'};
    $self->{'name'} = $params{'name'};
    $self->{'user'} = $params{'user'};
    $self->{'pass'} = $params{'pass'};
    
    bless($self, $class); 
    return $self;
}

sub db_connect
{
    my $self = shift;

    # MySQL Connection
    my $dsn = 'DBI:' . $self->{'type'} . ':' . $self->{'name'};
    my $user = $self->{'user'};
    my $pass = $self->{'pass'};

    my $dbh = DBI->connect_cached($dsn, $user, $pass) or die "Could not connect to database\n$@";
 
    return $dbh;
}

sub db_disconnect
{
    my ($self, $dbh) = @_;

    $dbh->disconnect();
}

sub query
{
    my ($self, $sql, @args) = @_;

    my $dbh = db_connect($self);

    my $query = $dbh->prepare($sql);
    $query->execute(@args);

    return $query;
}

1;
