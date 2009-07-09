package Ark::Plugin::Authentication::Store::Data::Model::Fast;
use Ark::Plugin 'Auth';

our $VERSION = '0.00_00';

has 'data_model_model' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->class_config->{model} || 'Data::Model::Fast';
    },
);

has 'data_model_target' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->class_config->{target} || 'user';
    },
);

has 'data_model_user_field' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->class_config->{user_field} || 'username';
    },
);

around 'find_user' => sub {
    my $prev = shift->(@_);
    return $prev if $prev;

    my ($self, $id, $info) = @_;    # How I intend to use $info?

    my $model = $self->app->model( $self->data_model_model );

    my $user = $model->lookup( $self->data_model_target => $id );

    if ($user) {
        $self->ensure_class_loaded('Ark::Plugin::Authentication::User');

        return Ark::Plugin::Authentication::User->new(
            store => 'Data::Model::Fast',
            obj   => $user,
            hash  => $user->get_columns,
        );
    }

    return;
};

around 'from_session' => sub {
    my $prev = shift->(@_);
    return $prev if $prev;

    my ($self, $user) = @_;

    return unless $user->{store} eq 'Data::Model::Fast';

    $self->ensure_class_loaded('Ark::Plugin::Authentication::User');

    Ark::Plugin::Authentication::User->new(
        store       => 'Data::Model::Fast',
        hash        => $user->{hash},
        obj_builder => sub {
            my $model  = $self->app->model( $self->data_model_model );

            $model->lookup(
                $self->data_model_target =>
                    $user->{hash}{ $self->data_model_user_field }
            );
        },
    );
};

1;

=head1 NAME

Ark::Plugin::Authentication::Store::Data::Model::Fast - Ark plugin for storing auth via Data::Model


=head1 VERSION

0.00_00


=head1 SYNOPSIS

=head2 Application root

    package MyApp::Web;
    use Ark;

    use_plugins qw(
        Session
        Session::State::Cookie
        Session::Store::Memory

        Authentication
        Authentication::Credential::Password
        Authentication::Store::Data::Model
    );

    # as your pleasure...
    conf 'Plugin::Authentication::Store::Data::Model' => {
        model           => 'Foobar',            # *A
        target          => 'user',              # *B (same as default)
        user_field      => 'id',                # *C (default is 'username')
    };
    conf 'Plugin::Authentication::Credential::Password' => {
        user_field      => 'id',                # *C (default is 'username')
        password_field  => 'password',          # *D (same as default)
        password_type   => 'clear',             # (same as default)
    };

    1;

=head2 Autentication controller

See L<same controller on Ark::Plugin::Authentication::Store::Data::Model|
Ark::Plugin::Authentication::Store::Data::Model/"Autentication controller">.

=head2 Authentication model

See L<same model on Ark::Plugin::Authentication::Store::Data::Model|
Ark::Plugin::Authentication::Store::Data::Model/"Authentication model">.

=head2 Table schema of user table

See L<same table schema on Ark::Plugin::Authentication::Store::Data::Model|
Ark::Plugin::Authentication::Store::Data::Model/"Table schema of user table">.

=head2 Column schema of user table

See L<same column schema on Ark::Plugin::Authentication::Store::Data::Model|
Ark::Plugin::Authentication::Store::Data::Model/"Column schema of user table">.

=head2 /root/authorization/form.mt

    [%=r $self->render('inc/header') %]

    <form method="post">
    <p>
        <label for="id">User ID:</label>
        <input type="text" id="id" name="id" />
    </p>
    <p>
        <label for="password">Password:</label>
        <input type="password" id="password" name="password" />
    </p>

    <p><input type="submit" value="login" /></p>
    </form>

    [%=r $self->render('inc/footer') %]



=head1 DESCRIPTION

blah blah blah


=head1 SEE ALSO

=over 4

=item L<Ark::Plugin::Authentication::Store::Data::Model|
Ark::Plugin::Authentication::Store::Data::Model>

This class looks-up a row ordinarily (by C<< $model->get >>).

=back


=head1 ACKNOWLEDGEMENTS

=over 4

=item MURASE Daisuke ("typester")

The author of L<Ark::Plugin::Authentication::Store::DBIx::Class|
Ark::Plugin::Authentication::Store::DBIx::Class>.

=back


=head1 AUTHOR

=over 4

=item MORIYA Masaki ("Gardejo")

C<< <moriya at ermitejo dot com> >>,
L<http://ttt.ermitejo.com/>

=back


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009 by MORIYA Masaki ("Gardejo"),
L<http://ttt.ermitejo.com>.

This library is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
See L<perlgpl|perlapi> and L<perlartistic|perlartistic>.
