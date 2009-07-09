package Ark::Plugin::Authentication::Store::Data::Model;
use Ark::Plugin 'Auth';

our $VERSION = '0.00_00';

has 'data_model_model' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->class_config->{model} || 'Data::Model';
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

    my $condition = {
        where => [
            $self->data_model_user_field => $id,
        ],
        limit => 1,
    };

    my $iterator = $model->get( $self->data_model_target => $condition );
    return
        unless $iterator;

    my $user = $iterator->next;

    if ($user) {
        $self->ensure_class_loaded('Ark::Plugin::Authentication::User');

        return Ark::Plugin::Authentication::User->new(
            store => 'Data::Model',
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

    return unless $user->{store} eq 'Data::Model';

    $self->ensure_class_loaded('Ark::Plugin::Authentication::User');

    Ark::Plugin::Authentication::User->new(
        store       => 'Data::Model',
        hash        => $user->{hash},
        obj_builder => sub {
            my $model  = $self->app->model( $self->data_model_model );

            $model->get(
                $self->data_model_target => {
                    where => [
                        $self->data_model_user_field =>
                            $user->{hash}{ $self->data_model_user_field },
                    ],
                    limit => 1,
                }
            )->next;
        },
    );
};

1;

=head1 NAME

Ark::Plugin::Authentication::Store::Data::Model - Ark plugin for storing auth via Data::Model


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
        user_field      => 'name',              # *C (default is 'username')
    };
    conf 'Plugin::Authentication::Credential::Password' => {
        user_field      => 'name',              # *C (default is 'username')
        password_field  => 'password',          # *D (same as default)
        password_type   => 'clear',             # (same as default)
    };

    1;

=head2 Autentication controller

    package MyApp::Web::Controller::Authentication;
    use Ark 'Controller';

    has '+namespace' => (
        default => q{},
    );

    sub login :Path('login') {
        my ($self, $c) = @_;

        $c->detach(
              $c->req->method ne 'POST'         ? 'require_authentication'
            : $c->authenticate($c->req->params) ? 'authorized'
            :                                     'unauthorized'
        );
    }
    sub require_authentication :Private {
        my ($self, $c) = @_;

        $c->view('MT')->template('authorization/form');
    }
    sub authorized :Private {
        my ($self, $c) = @_;

        $c->stash->{message} = 'Welcome, ' . $c->user->obj->name . '!!';
        $c->view('MT')->template('home');
    }
    sub unauthorized :Private {
        my ($self, $c) = @_;

        $c->stash->{message} = 'Invalid username or password';
        $c->view('MT')->template('authorization/form');
    }

    1;

=head2 Authentication model

    package MyApp::Web::Model::Foobar;          # *A
    use Ark 'Model::Adaptor';

    __PACKAGE__->config(
        class => 'MyApp::Schema::Table::User',  # *E
    );

    1;

=head2 Table schema of user table

    package MyApp::Schema::Table::User;         # *E
    use base qw(Data::Model);
    use Data::Model::Schema sugar => 'myapp';   # *F
    use Data::Model::Driver::DBI;
    use MyApp::Schema::Column::User;            # *G

    my $dbfile = '/foo/bar.db';
    my $driver = Data::Model::Driver::DBI->new(
        dsn => "dbi:SQLite:dbname=$dbfile",
    );
    base_driver($driver);

    install_model 'user' => schema {            # *B
        key 'id';
        column 'user.id';
        column 'user.name';                     # *C
        unique 'name';
        column 'user.password';                 # *D
        # ...
    };

    # ...

=head2 Column schema of user table

    package MyApp::Schema::Column::User;        # *G
    use Data::Model::Schema sugar => 'myapp';   # *F

    column_sugar 'user.id'
        => int => {
            require     => 1,
            unsigned    => 1,
        };
    column_sugar 'user.name' =>                 # *C
        varchar => {
            require => 1,
            size    => 16,
        };
    column_sugar 'user.password' =>             # *D
        varchar => {
            require => 1,
            size    => 16,
        };
    # ... (common.last_updated_datetime, user.last_login_datetime, etc.)

    1;

=head2 /root/authorization/form.mt

    [%=r $self->render('inc/header') %]

    <form method="post">
    <p>
        <label for="name">User name:</label>
        <input type="text" id="name" name="name" />
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

=item L<Ark::Plugin::Authentication::Store::Data::Model::Fast|
Ark::Plugin::Authentication::Store::Data::Model::Fast>

This class looks-up a row B<by an index>. Maybe fast!

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
