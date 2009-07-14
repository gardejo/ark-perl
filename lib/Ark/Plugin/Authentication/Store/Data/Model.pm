package Ark::Plugin::Authentication::Store::Data::Model;
use Ark::Plugin 'Auth';

our $VERSION = '0.04_00';

has 'data_model_model' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->class_config->{model} || 'DataModel';
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

has 'data_model_by_key' => (
    is      => 'rw',
    isa     => 'Bool',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->class_config->{by_key} || 0;
    },
);

around 'find_user' => sub {
    my $prev = shift->(@_);
    return $prev if $prev;

    my ($self, $id, $info) = @_;

    my $model = $self->app->model( $self->data_model_model );

    my $user;
    if ($model->can('find_user')) {
        $user = $model->find_user($id, $info);
    }
    elsif ($self->data_model_by_key) {
        $user = $model->lookup( $self->data_model_target => $id );
    }
    else {
        my @users = $model->get( $self->data_model_target => {
            where => [
                $self->data_model_user_field => $id,
            ],
            limit => 1,
        } );
        return unless @users;
        $user = $users[0];
    }

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

            if ($self->data_model_by_key) {
                return $model->lookup(
                    $self->data_model_target =>
                        $user->{hash}{ $self->data_model_user_field }
                );
            }
            else {
                return ( $model->get(
                    $self->data_model_target => {
                        where => [
                            $self->data_model_user_field =>
                                $user->{hash}{ $self->data_model_user_field },
                        ],
                        limit => 1,
                    }
                ) )[0];
            }
        },
    );
};

1;
__END__

=head1 NAME

Ark::Plugin::Authentication::Store::Data::Model - Ark plugin for storing auth via Data::Model


=head1 VERSION

0.04_00


=head1 SYNOPSIS

=head2 Application class

    package MyApp::Web;
    use Ark;

    use_plugins qw(
        Authentication
        Authentication::Credential::Password
        Authentication::Store::Data::Model

        Session
        Session::State::Cookie
        Session::Store::Memory
    );

    # optional: as your pleasure...
    conf 'Plugin::Authentication::Credential::Password' => {
        user_field      => 'name',              # *A (default is 'username')
        password_field  => 'password',          # *B (same as default)
        password_type   => 'clear',             #    (same as default)
    };
    conf 'Plugin::Authentication::Store::Data::Model' => {
        model           => 'Foobar',            # *C (default is 'DataModel')
        target          => 'user',              # *D (same as default)
        user_field      => 'name',              # *A (default is 'username')
    };

    1;

=head2 Autentication controller class

    package MyApp::Web::Controller::Authentication;
    use Ark 'Controller';

    has '+namespace' => (
        default => q{},
    );

    sub login :Path('login') {
        my ($self, $c) = @_;

        if ($c->req->method eq 'POST') {
            # e.g. $c->authenticate({name => $username, password => $password})
            if (my $user = $c->authenticate($c->req->params) {
                $c->stash->{message} = 'Welcome, ' . $user->obj->name . '!!';
                $c->view('MT')->template('home');
            }
            else {
                $c->stash->{message} = 'Invalid username or password';
                $c->view('MT')->template('authorization/form');
            }
        }
        else {
            $c->view('MT')->template('authorization/form'); # require login
        }
    }

    1;

=head2 Authentication model class

    package MyApp::Web::Model::Foobar;          # *C
    use Ark 'Model::Adaptor';

    __PACKAGE__->config(
        class => 'MyApp::Schema::Table::User',  # *E
    );

    1;

=head2 Table schema class of user table

    package MyApp::Schema::Table::User;         # *E
    use base qw(Data::Model);
    use Data::Model::Driver::DBI;
    use Data::Model::Schema sugar => 'myapp';   # *F
    use MyApp::Schema::Column::User;            # *G

    my $dbfile = '/foo/bar.db';
    my $driver = Data::Model::Driver::DBI->new(
        dsn => "dbi:SQLite:dbname=$dbfile",
    );
    base_driver($driver);

    install_model 'user' => schema {            # *D
        key 'id';
        column 'user.id' => { auto_increment => 1 };
        column 'user.name';                     # *A
        unique 'name';
        column 'user.password';                 # *B
        # ...
    };

    # ...

    # optional: as your pleasure...
    sub find_user {
        my ($self, $id, $info) = @_;

        my @users = $self->get( user => {       # *D
            where => [
                name => lc $id,                 # ignore case
            ],
            # you can use $info for any more conditions!
        } );

        return unless @users;                   # not found
        return $users[0];                       # found
    }

    1;

=head2 Column schema class of user table

    package MyApp::Schema::Column::User;        # *G
    use Data::Model::Schema sugar => 'myapp';   # *F

    column_sugar 'user.id'
        => integer => {
            require     => 1,
            unsigned    => 1,
        };
    column_sugar 'user.name'                    # *A
        => text => {
            require     => 1,
        };
    column_sugar 'user.password'                # *B
        => text => {
            require     => 1,
        };
    # ... (common.last_updated_datetime, user.last_accessed_datetime, etc.)

    1;

=head2 Authentication template file

    <!-- This is /root/authorization/form.mt -->
    <form method="post">
    <p>
        <label for="name">User name:</label>
        <input type="text" id="name" name="name" />
    </p>
    <p>
        <label for="password">Password:</label>
        <input type="password" id="password" name="password" />
    </p>
    <p>
        <input type="submit" value="login" />
    </p>
    </form>


=head1 DESCRIPTION

This module is a plugin for L<Ark|Ark>; to store authentication informations
for any data by L<Data::Model|Data::Model>.

=head2 How to find an user

Default behavior of finding an user is below:

=over 4

=item 1

Constructs a model object of class named C<MyApp::Model::DataModel>.
You can change the class name into other one
by C<conf> function (see L<SYNOPSIS|/"SYNOPSIS">).
Most people make the model class delegete all methods to
L<Data::Model|Data::Model>'s model by
L<Ark::Model::Adaptor|Ark::Model::Adaptor>.

=item 2

Finds user's row by the column (field) named C<username>, from the model
named C<user>.
You can change these column (field) name and model name into other ones
by C<conf> function (see L<SYNOPSIS|/"SYNOPSIS">).
You can also implement C<find_user> method for L<Data::Model|Data::Model>'s
model (in that case, this plugin use the method instead of plugin's procedure).

=item 3

Returns L<Ark::Plugin::Authentication::User|Ark::Plugin::Authentication::User>
object as C<< $user >> to application controller, when user is authorized
by any C<Ark::Plugin::Authentication::Credential::*> plugin.
This will enable you to get L<Data::Model::Row|Data::Model::Row> object
by C<< $user->obj >> method.

=item 4

Retrieves L<Ark::Plugin::Authentication::User|
Ark::Plugin::Authentication::User> object as C<< $c->user >> to application
controller over a session, when you use C<< use_plugins qw(Session) >>.
You can get L<Data::Model::Row|Data::Model::Row> object
by C<< $c->user->obj >> method.

=back

=head2 How to find an user by key column (key field)

The plugin can find user's row by index
(so that means that the plugin use method C<< $model->lookup >>).
This will enable you to find user's row mostly faster about several dozen
persent (see L<http://gist.github.com/146906>).

When you define a B<key> column (key field) at schema...

    install_model 'user' => schema {
        key 'id';                               # define "id" column as key
        column 'user.id' => { auto_increment => 1 };
        column 'user.name';
        unique 'name';
        column 'user.password';
        # ...
    };

...and specify that C<by_key> flag is true;

    conf 'Plugin::Authentication::Credential::Password' => {
        user_field      => 'id',                # key column
        password_field  => 'password',
        password_type   => 'clear',
    };
    conf 'Plugin::Authentication::Store::Data::Model' => {
        model           => 'Foobar',
        target          => 'user',
        user_field      => 'id',                # key column
        by_key          => 1,                   # turn on!
    };

you can have the plugin use the key column.

    <form method="post">
    <p>
        <label for="id">User ID:</label>
        <input type="text" id="id" name="id" />
    </p>
    <p>
        <label for="password">Password:</label>
        <input type="password" id="password" name="password" />
    </p>
    <p>
        <input type="submit" value="login" />
    </p>
    </form>


=head1 SEE ALSO

=over 4

=item L<Ark::Plugin::Authentication::Store::DBIx::Class|
        Ark::Plugin::Authentication::Store::DBIx::Class>

This plugin looks-up a row from L<DBIx::Class|DBIx::Class>'s model.

=item L<Ark::Plugin::Authentication::Credential::Password|
        Ark::Plugin::Authentication::Credential::Password>

This plugin verifies password with user's row object.

=back


=head1 ACKNOWLEDGEMENTS

=over 4

=item Daisuke Murase ("typester")

The author of L<Ark::Plugin::Authentication::Store::DBIx::Class|
Ark::Plugin::Authentication::Store::DBIx::Class>.
I stolen almost every codes from this plugin.

=back


=head1 AUTHOR

=over 4

=item MORIYA Masaki ("gardejo")

C<< <moriya at ermitejo dot com> >>,
L<http://ttt.ermitejo.com/>

=back


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009 by MORIYA Masaki ("gardejo"),
L<http://ttt.ermitejo.com>.

This library is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
See L<perlgpl|perlapi> and L<perlartistic|perlartistic>.
