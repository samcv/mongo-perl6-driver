use v6.c;

use BSON::Document;

use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

#-------------------------------------------------------------------------------
unit package MongoDB;


# Array index and error codes
constant C-MANDATORY          = 0;
constant C-TYPE               = 1;

# error code
constant C-NOTINSCHEMA        = -1;

#-----------------------------------------------------------------------------
role HL::CollectionRole {

  # Schema is a document to describe a table. Its keys are the fields in the table
  # The value of a field is an Array or BSON::Document. When an Array, it holds
  # the following info
  # - Mandatory field if True(Bool)
  # - Type of field,
  # -
  # When BSON::Document is used, it means the structure is nested and is always
  # mandatory.
  #
  # BSON::Document.new: (
  #   contact => BSON::Document.new((
  #     name => [ True, Str],
  #     surname => [True, Str]
  #   )),
  #   address => BSON::Document.new((
  #     street => [ True, Str],
  #     number => [ False, Int],
  #   ))
  # )
  has BSON::Document $!schema;

  # Record to read in data or write to database
  has BSON::Document $!record;
  has Array $!failed-fields;

  has MongoDB::Client $!client;
  has MongoDB::Database $!db;
  has MongoDB::Collection $!cl;
  
  has Bool $!append-unknown-fields;

  #---------------------------------------------------------------------------
  method reset( *%fields ) {
    $!record .= new;
  }

  #---------------------------------------------------------------------------
  method set( *%fields ) {

    # Define the record in the same order as noted in schema
    $!record .= new unless $!record.defined;
    for $!schema.keys -> $field-name {
      if %fields{$field-name}:exists {
        $!record{$field-name} = %fields{$field-name};
      }
    }

    # Add the rest of the fields not found in schema. These fail later
    # depending on option $!append-unknown-fields.
    for %fields.keys -> $field-name {
      if $!schema{$field-name}:!exists {
        $!record{$field-name} = %fields{$field-name};
      }
    }
  }

  #---------------------------------------------------------------------------
  method read ( --> BSON::Document ) {

  }

  #---------------------------------------------------------------------------
  method read-next ( --> BSON::Document ) {

  }

  #---------------------------------------------------------------------------
  method insert ( --> BSON::Document ) {

    my BSON::Document $doc;

    $!failed-fields = [];
    self!check-record( $!schema, $!record);
    if $!failed-fields.elems {
      $doc = self!document-failures;
    }

    else {
      $doc = $!db.run-command(
        BSON::Document.new: (
          insert => $!cl.name,
          documents => [
            $!record
          ]
        )
      );
    }

    $doc;
  }

  #---------------------------------------------------------------------------
  method update ( --> BSON::Document ) {

  }

  #---------------------------------------------------------------------------
  method delete ( --> BSON::Document ) {

  }

  #---------------------------------------------------------------------------
  method !check-record (
    BSON::Document:D $schema,
    BSON::Document:D $record
  ) {

    for $!schema.keys -> $field-name {
      if $record{$field-name}:exists {
        if $record{$field-name} ~~ BSON::Document {
          self!check-record( $!schema{$field-name}, $record{$field-name});
        }

        elsif $record{$field-name} !~~ $!schema{$field-name}[C-TYPE] {
          $!failed-fields.push: [
            $field-name,                      # failed fieldname
            C-TYPE,                           # failed on type
            $record{$field-name}.WHAT,        # has type
            $!schema{$field-name}[C-TYPE]     # should be type
          ];
        }
      }

      else {
        if $!schema{$field-name}[C-MANDATORY] {
          $!failed-fields.push: [
            $field-name,                      # failed fieldname
            C-MANDATORY,                      # field is missing
          ];
        }
      }
    }

    unless $!append-unknown-fields {
      for $record.keys -> $field-name {
        if $schema{$field-name}:!exists {
          $!failed-fields.push: [
            $field-name,                      # failed fieldname
            C-NOTINSCHEMA,                    # field not in schema
          ];
        }
      }
    }
  }

  #---------------------------------------------------------------------------
  method !check-schema ( BSON::Document:D $schema --> Bool ) {

  }

  #---------------------------------------------------------------------------
  method !document-failures ( --> BSON::Document ) {

    my BSON::Document $error-doc .= new;
    $error-doc<ok> = 0;
    $error-doc<reason> = 'Missing fields or fields having wrong types';
    $error-doc<fields> = BSON::Document.new;

    for @$!failed-fields -> $field-spec {

      if $field-spec[1] ~~ C-MANDATORY {
        $error-doc<fields>{$field-spec[0]} = 'missing';
      }

      elsif $field-spec[1] ~~ C-TYPE {
        $error-doc<fields>{$field-spec[0]} = 
          [~] 'type failure, is ', $field-spec[2].WHAT.perl, " but must be ",
          $field-spec[3].WHAT.perl;
      }

      elsif $field-spec[1] ~~ C-NOTINSCHEMA {
        $error-doc<fields>{$field-spec[0]} = 'not described in schema';
      }
    }

    $error-doc;
  }
}

#-----------------------------------------------------------------------------
#TODO See if class can be generated in $A below
class HL::Collection does HL::CollectionRole {

  #---------------------------------------------------------------------------
  submethod BUILD (
    Str:D :$uri,
    Str:D :$db-name,
    Str:D :$cl-name,
    BSON::Document:D :$schema,
    Bool :$append-unknown-fields = False
  ) {

    $!client = MongoDB::Client.new(:$uri);
    $!db = $!client.database($db-name);
    $!cl = $!db.collection($cl-name);

    $!schema = $schema;
    $!append-unknown-fields = $append-unknown-fields;
  }
}

sub gen-table-class (
  Str:D :$uri,
  Str:D :$db-name,
  Str:D :$cl-name,
  BSON::Document:D :$schema

  --> MongoDB::HL::Collection
) is export {

  my $name = "MongoDB::HL::Collection::$cl-name.tc()";

  my $A := Metamodel::ClassHOW.new_type(:$name);
  $A.^add_parent( MongoDB::HL::Collection, :!hides);
  $A.^compose;

  $A.new( :$uri, :$db-name, :$cl-name, :$schema);
}
