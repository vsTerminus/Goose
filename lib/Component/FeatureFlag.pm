package Component::FeatureFlag;

use feature 'say';
use Moo;

use Mojo::UserAgent;
use Mojo::Promise;
use Mojo::URL;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(weather);

has db          => ( is => 'ro' );

sub create_flag
{
    my ($self, $flag_name) = @_;

    return -1 unless _is_valid($flag_name);

    my $sql = "INSERT INTO feature_flags VALUES (?, 0)";
    $self->db->query($sql, lc $flag_name);

    return $self->get_flag($flag_name) == 0 ? 1 : -1;
}

sub delete_flag
{
    my ($self, $flag_name) = @_;

    return -1 unless _is_valid($flag_name);

    my $sql = "DELETE FROM feature_flags WHERE flag_name = ?";
    $self->db->query($sql, lc $flag_name);

    return !defined $self->get_flag($flag_name) ? 1 : -1;
}

sub enable_flag
{
    my ($self, $flag_name) = @_;

    return -1 unless _is_valid($flag_name);

    my $sql = "UPDATE feature_flags SET flag_value = 1 WHERE flag_name = ?";
    $self->db->query($sql, lc $flag_name);

    return $self->get_flag($flag_name) == 1 ? 1 : -1;
}

sub disable_flag
{
    my ($self, $flag_name) = @_;

    return -1 unless _is_valid($flag_name);

    my $sql = "UPDATE feature_flags SET flag_value = 0 WHERE flag_name = ?";
    $self->db->query($sql, lc $flag_name);

    return $self->get_flag($flag_name) == 0 ? 1 : -1;
}

sub list_flags
{
    my ($self) = @_;

    my $sql = "SELECT flag_name FROM feature_flags";
    my $query = $self->db->query($sql);

    # my @all = map {@$_} $dbh->selectall_array($sql);
    return $query->fetchall_arrayref;
}

sub get_flag
{
    my ($self, $flag_name) = @_;

    return -1 unless _is_valid($flag_name);

    my $sql = "SELECT flag_value FROM feature_flags WHERE flag_name = ?";
    my $query = $self->db->query($sql, lc $flag_name);
    my $row = $query->fetchrow_hashref;

    return $row->{'flag_value'} // -1;
}

sub _is_valid
{
    my $flag_name = shift;

    return $flag_name =~ /^[a-zA-Z0-9_-]+$/ ? 1 : 0;
}

1;
