use Test::Base;
use File::Temp;

eval "use Data::Model";
plan skip_all => 'Data::Model required to run this test' if $@;

my $db = "testdatabase_datamodelfast";
END { unlink $db }

{
    # create Database
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db")
        or die DBI->errstr;

    $dbh->do(<<'...');
CREATE TABLE user (
    id INTEGER NOT NULL PRIMARY KEY,
    username TEXT NOT NULL,
    password TEXT NOT NULL
);
...

    $dbh->do(<<'...');
INSERT INTO user (id, username, password) values ('1', 'user1', 'pass1');
...


    $dbh->do(<<'...');
INSERT INTO user (id, username, password) values ('2', 'user2', 'pass2');
...

}

{
    package T1::Schema::Column;
    use Data::Model::Schema sugar => 't1';

    column_sugar 'user.id'
        => integer => {
            require => 1,
        };
    column_sugar 'user.username'
        => text => {
            require => 1,
        };
    column_sugar 'user.password'
        => text => {
            require => 1,
        };
}

{
    package T1::Schema::Table;
    use base qw/Data::Model/;
    use Data::Model::Schema sugar => 't1';
    use Data::Model::Driver::DBI;
    my $driver = Data::Model::Driver::DBI->new(
        dsn => "dbi:SQLite:dbname=$db",
    );
    base_driver( $driver );

    install_model user => schema {
        key 'id';
        column 'user.id';
        column 'user.username';
        column 'user.password';
    };

}

{
    package T1;
    use Ark;

    use_plugins qw/
        Session
        Session::State::Cookie
        Session::Store::Memory

        Authentication
        Authentication::Credential::Password
        Authentication::Store::Data::Model::Fast
        /;

    conf 'Plugin::Authentication::Store::Data::Model::Fast' => {
        user_field => 'id',
    };
    conf 'Plugin::Authentication::Credential::Password' => {
        user_field => 'id',
    };

    package T1::Model::Data::Model::Fast;
    use Ark 'Model::Adaptor';

    __PACKAGE__->config(
        class       => 'T1::Schema::Table',
    );

    package T1::Controller::Root;
    use Ark 'Controller';

    __PACKAGE__->config->{namespace} = '';

    sub index :Path {
        my ($self, $c) = @_;

        if ($c->user && $c->user->authenticated) {
            $c->res->body( 'logined: ' . $c->user->obj->username );
        }
        else {
            $c->res->body( 'require login' );
        }
    }

    sub login :Local {
        my ($self, $c) = @_;

        if (my $user = $c->authenticate({ id => '1', password => 'pass1' })) {
            $c->res->body( 'login done' );
        }
    }
}

plan 'no_plan';

use Ark::Test 'T1',
    components => [qw/Controller::Root
                      Model::Data::Model::Fast
                     /],
    reuse_connection => 1;


is(get('/'), 'require login', 'not login ok');
is(get('/login'), 'login done', 'login ok');
is(get('/'), 'logined: user1', 'logined ok');
