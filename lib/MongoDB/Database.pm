use MongoDB::Collection;

class MongoDB::Database;

has $.connection is rw;
has Str $.name is rw;

submethod BUILD ( :$connection, Str :$name ) {

    $!connection = $connection;

    # TODO validate name
    $!name = $name;
}

method collection ( Str $name --> MongoDB::Collection ) {

    return MongoDB::Collection.new(
        database    => self,
        name        => $name,
    );
}

# Run command should ony be working on the admin database using the virtual
# $cmd collection. Method is placed here because it works on a database be it a
# special one.
#
method run_command ( %command --> Hash ) {

    my MongoDB::Collection $c .= new(
        database    => self,
        name        => '$cmd',
    );

    return $c.find_one(%command);
}

