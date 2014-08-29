# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2014 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

use strict;
use warnings;

package RT;


use File::Spec ();
use Cwd ();

use vars qw($Config $System $SystemUser $Nobody $Handle $Logger $_Privileged $_Unprivileged $_INSTALL_MODE);

use vars qw($BasePath
 $EtcPath
 $BinPath
 $SbinPath
 $VarPath
 $LexiconPath
 $PluginPath
 $LocalPath
 $LocalEtcPath
 $LocalLibPath
 $LocalLexiconPath
 $LocalPluginPath
 $MasonComponentRoot
 $MasonLocalComponentRoot
 $MasonDataDir
 $MasonSessionDir);


RT->LoadGeneratedData();

=head1 NAME

RT - Request Tracker

=head1 SYNOPSIS

A fully featured request tracker package.

This documentation describes the point-of-entry for RT's Perl API.  To learn
more about what RT is and what it can do for you, visit
L<https://bestpractical.com/rt>.

=head1 DESCRIPTION

=head2 INITIALIZATION

If you're using RT's Perl libraries, you need to initialize RT before using any
of the modules.

You have the option of handling the timing of config loading and the actual
init sequence yourself with:

    use RT;
    BEGIN {
        RT->LoadConfig;
        RT->Init;
    }

or you can let RT do it all:

    use RT -init;

This second method is particular useful when writing one-liners to interact with RT:

    perl -MRT=-init -e '...'

The first method is necessary if you need to delay or conditionalize
initialization or if you want to fiddle with C<< RT->Config >> between loading
the config files and initializing the RT environment.

=cut

{
    my $DID_IMPORT_INIT;
    sub import {
        my $class  = shift;
        my $action = shift || '';

        if ($action eq "-init" and not $DID_IMPORT_INIT) {
            $class->LoadConfig;
            $class->Init;
            $DID_IMPORT_INIT = 1;
        }
    }
}

=head2 LoadConfig

Load RT's config file.  First, the site configuration file
(F<RT_SiteConfig.pm>) is loaded, in order to establish overall site
settings like hostname and name of RT instance.  Then, the core
configuration file (F<RT_Config.pm>) is loaded to set fallback values
for all settings; it bases some values on settings from the site
configuration file.

In order for the core configuration to not override the site's
settings, the function C<Set> is used; it only sets values if they
have not been set already.

=cut

sub LoadConfig {
    require RT::Config;
    $Config = RT::Config->new;
    $Config->LoadConfigs;
    require RT::I18N;

    # RT::Essentials mistakenly recommends that WebPath be set to '/'.
    # If the user does that, do what they mean.
    $RT::WebPath = '' if ($RT::WebPath eq '/');

    # fix relative LogDir and GnuPG homedir
    unless ( File::Spec->file_name_is_absolute( $Config->Get('LogDir') ) ) {
        $Config->Set( LogDir =>
              File::Spec->catfile( $BasePath, $Config->Get('LogDir') ) );
    }

    my $gpgopts = $Config->Get('GnuPGOptions');
    unless ( File::Spec->file_name_is_absolute( $gpgopts->{homedir} ) ) {
        $gpgopts->{homedir} = File::Spec->catfile( $BasePath, $gpgopts->{homedir} );
    }

    return $Config;
}

=head2 Init

L<Connects to the database|/ConnectToDatabase>, L<initilizes system
objects|/InitSystemObjects>, L<preloads classes|/InitClasses>, L<sets
up logging|/InitLogging>, and L<loads plugins|/InitPlugins>.

=cut

sub Init {
    shift if @_%2; # code is inconsistent about calling as method
    my %args = (@_);

    CheckPerlRequirements();

    InitPluginPaths();

    #Get a database connection
    ConnectToDatabase();
    InitSystemObjects();
    InitClasses(%args);
    InitLogging(%args);
    InitPlugins();
    RT::I18N->Init;
    RT->Config->PostLoadCheck;

}

=head2 ConnectToDatabase

Get a database connection. See also L</Handle>.

=cut

sub ConnectToDatabase {
    require RT::Handle;
    $Handle = RT::Handle->new unless $Handle;
    $Handle->Connect;
    return $Handle;
}

=head2 InitLogging

Create the Logger object and set up signal handlers.

=cut

sub InitLogging {

    my %arg = @_;

    # We have to set the record separator ($, man perlvar)
    # or Log::Dispatch starts getting
    # really pissy, as some other module we use unsets it.
    $, = '';
    use Log::Dispatch 1.6;

    my %level_to_num = (
        map( { $_ => } 0..7 ),
        debug     => 0,
        info      => 1,
        notice    => 2,
        warning   => 3,
        error     => 4, 'err' => 4,
        critical  => 5, crit  => 5,
        alert     => 6,
        emergency => 7, emerg => 7,
    );

    unless ( $RT::Logger ) {

        $RT::Logger = Log::Dispatch->new;

        my $stack_from_level;
        if ( $stack_from_level = RT->Config->Get('LogStackTraces') ) {
            # if option has old style '\d'(true) value
            $stack_from_level = 0 if $stack_from_level =~ /^\d+$/;
            $stack_from_level = $level_to_num{ $stack_from_level } || 0;
        } else {
            $stack_from_level = 99; # don't log
        }

        my $simple_cb = sub {
            # if this code throw any warning we can get segfault
            no warnings;
            my %p = @_;

            # skip Log::* stack frames
            my $frame = 0;
            $frame++ while caller($frame) && caller($frame) =~ /^Log::/;
            my ($package, $filename, $line) = caller($frame);

            $p{'message'} =~ s/(?:\r*\n)+$//;
            return "[$$] [". gmtime(time) ."] [". $p{'level'} ."]: "
                . $p{'message'} ." ($filename:$line)\n";
        };

        my $syslog_cb = sub {
            # if this code throw any warning we can get segfault
            no warnings;
            my %p = @_;

            my $frame = 0; # stack frame index
            # skip Log::* stack frames
            $frame++ while caller($frame) && caller($frame) =~ /^Log::/;
            my ($package, $filename, $line) = caller($frame);

            # syswrite() cannot take utf8; turn it off here.
            Encode::_utf8_off($p{message});

            $p{message} =~ s/(?:\r*\n)+$//;
            if ($p{level} eq 'debug') {
                return "[$$] $p{message} ($filename:$line)\n";
            } else {
                return "[$$] $p{message}\n";
            }
        };

        my $stack_cb = sub {
            no warnings;
            my %p = @_;
            return $p{'message'} unless $level_to_num{ $p{'level'} } >= $stack_from_level;

            require Devel::StackTrace;
            my $trace = Devel::StackTrace->new( ignore_class => [ 'Log::Dispatch', 'Log::Dispatch::Base' ] );
            return $p{'message'} . $trace->as_string;

            # skip calling of the Log::* subroutins
            my $frame = 0;
            $frame++ while caller($frame) && caller($frame) =~ /^Log::/;
            $frame++ while caller($frame) && (caller($frame))[3] =~ /^Log::/;

            $p{'message'} .= "\nStack trace:\n";
            while( my ($package, $filename, $line, $sub) = caller($frame++) ) {
                $p{'message'} .= "\t$sub(...) called at $filename:$line\n";
            }
            return $p{'message'};
        };

        if ( $Config->Get('LogToFile') ) {
            my ($filename, $logdir) = (
                $Config->Get('LogToFileNamed') || 'rt.log',
                $Config->Get('LogDir') || File::Spec->catdir( $VarPath, 'log' ),
            );
            if ( $filename =~ m![/\\]! ) { # looks like an absolute path.
                ($logdir) = $filename =~ m{^(.*[/\\])};
            }
            else {
                $filename = File::Spec->catfile( $logdir, $filename );
            }

            unless ( -d $logdir && ( ( -f $filename && -w $filename ) || -w $logdir ) ) {
                # localizing here would be hard when we don't have a current user yet
                die "Log file '$filename' couldn't be written or created.\n RT can't run.";
            }

            require Log::Dispatch::File;
            $RT::Logger->add( Log::Dispatch::File->new
                           ( name=>'file',
                             min_level=> $Config->Get('LogToFile'),
                             filename=> $filename,
                             mode=>'append',
                             callbacks => [ $simple_cb, $stack_cb ],
                           ));
        }
        if ( $Config->Get('LogToScreen') ) {
            require Log::Dispatch::Screen;
            $RT::Logger->add( Log::Dispatch::Screen->new
                         ( name => 'screen',
                           min_level => $Config->Get('LogToScreen'),
                           callbacks => [ $simple_cb, $stack_cb ],
                           stderr => 1,
                         ));
        }
        if ( $Config->Get('LogToSyslog') ) {
            require Log::Dispatch::Syslog;
            $RT::Logger->add(Log::Dispatch::Syslog->new
                         ( name => 'syslog',
                           ident => 'RT',
                           min_level => $Config->Get('LogToSyslog'),
                           callbacks => [ $syslog_cb, $stack_cb ],
                           stderr => 1,
                           $Config->Get('LogToSyslogConf'),
                         ));
        }
    }
    InitSignalHandlers(%arg);
}

{   # Work around bug in Log::Dispatch < 2.30, wherein the short forms
    # of ->warn, ->err, and ->crit do not usefully propagate out, unlike
    # ->warning, ->error, and ->critical
    package Log::Dispatch;
    no warnings 'redefine';
    sub warn { shift->warning(@_) }
    sub err  { shift->error(@_) }
    sub crit { shift->critical(@_) }
}

sub InitSignalHandlers {

    my %arg = @_;
    return if $arg{'NoSignalHandlers'};

# Signal handlers
## This is the default handling of warnings and die'ings in the code
## (including other used modules - maybe except for errors catched by
## Mason).  It will log all problems through the standard logging
## mechanism (see above).

    $SIG{__WARN__} = sub {
        # The 'wide character' warnings has to be silenced for now, at least
        # until HTML::Mason offers a sane way to process both raw output and
        # unicode strings.
        # use 'goto &foo' syntax to hide ANON sub from stack
        if( index($_[0], 'Wide character in ') != 0 ) {
            unshift @_, $RT::Logger, qw(level warning message);
            goto &Log::Dispatch::log;
        }
        # Return value is used only by RT::Test to filter warnings from
        # reaching the Test::NoWarnings catcher.  If Log::Dispatch::log() ever
        # starts returning 'IGNORE', we'll need to switch to something more
        # clever.  I don't expect that to happen.
        return 'IGNORE';
    };

#When we call die, trap it and log->crit with the value of the die.

    $SIG{__DIE__}  = sub {
        # if we are not in eval and perl is not parsing code
        # then rollback transactions and log RT error
        unless ($^S || !defined $^S ) {
            $RT::Handle->Rollback(1) if $RT::Handle;
            $RT::Logger->crit("$_[0]") if $RT::Logger;
        }
        die $_[0];
    };
}


sub CheckPerlRequirements {
    if ($^V < 5.008003) {
        die sprintf "RT requires Perl v5.8.3 or newer.  Your current Perl is v%vd\n", $^V;
    }

    # use $error here so the following "die" can still affect the global $@
    my $error;
    {
        local $@;
        eval {
            my $x = '';
            my $y = \$x;
            require Scalar::Util;
            Scalar::Util::weaken($y);
        };
        $error = $@;
    }

    if ($error) {
        die <<"EOF";

RT requires the Scalar::Util module be built with support for  the 'weaken'
function.

It is sometimes the case that operating system upgrades will replace
a working Scalar::Util with a non-working one. If your system was working
correctly up until now, this is likely the cause of the problem.

Please reinstall Scalar::Util, being careful to let it build with your C
compiler. Usually this is as simple as running the following command as
root.

    perl -MCPAN -e'install Scalar::Util'

EOF

    }
}

=head2 InitClasses

Load all modules that define base classes.

=cut

sub InitClasses {
    shift if @_%2; # so we can call it as a function or method
    my %args = (@_);
    require RT::Tickets;
    require RT::Transactions;
    require RT::Attachments;
    require RT::Users;
    require RT::Principals;
    require RT::CurrentUser;
    require RT::Templates;
    require RT::Queues;
    require RT::ScripActions;
    require RT::ScripConditions;
    require RT::Scrips;
    require RT::Groups;
    require RT::GroupMembers;
    require RT::CustomFields;
    require RT::CustomFieldValues;
    require RT::ObjectCustomFields;
    require RT::ObjectCustomFieldValues;
    require RT::Attributes;
    require RT::Dashboard;
    require RT::Approval;
    require RT::Lifecycle;
    require RT::Link;
    require RT::Links;
    require RT::Article;
    require RT::Articles;
    require RT::Class;
    require RT::Classes;
    require RT::ObjectClass;
    require RT::ObjectClasses;
    require RT::ObjectTopic;
    require RT::ObjectTopics;
    require RT::Topic;
    require RT::Topics;

    # on a cold server (just after restart) people could have an object
    # in the session, as we deserialize it so we never call constructor
    # of the class, so the list of accessible fields is empty and we die
    # with "Method xxx is not implemented in RT::SomeClass"

    # without this, we also can never call _ClassAccessible, because we
    # won't have filled RT::Record::_TABLE_ATTR
    $_->_BuildTableAttributes foreach qw(
        RT::Ticket
        RT::Transaction
        RT::Attachment
        RT::User
        RT::Principal
        RT::Template
        RT::Queue
        RT::ScripAction
        RT::ScripCondition
        RT::Scrip
        RT::Group
        RT::GroupMember
        RT::CustomField
        RT::CustomFieldValue
        RT::ObjectCustomField
        RT::ObjectCustomFieldValue
        RT::Attribute
        RT::ACE
        RT::Link
        RT::Article
        RT::Class
        RT::ObjectClass
        RT::ObjectTopic
        RT::Topic
    );

    if ( $args{'Heavy'} ) {
        # load scrips' modules
        my $scrips = RT::Scrips->new(RT->SystemUser);
        $scrips->Limit( FIELD => 'Stage', OPERATOR => '!=', VALUE => 'Disabled' );
        while ( my $scrip = $scrips->Next ) {
            local $@;
            eval { $scrip->LoadModules } or
                $RT::Logger->error("Invalid Scrip ".$scrip->Id.".  Unable to load the Action or Condition.  ".
                                   "You should delete or repair this Scrip in the admin UI.\n$@\n");
        }

	foreach my $class ( grep $_, RT->Config->Get('CustomFieldValuesSources') ) {
            local $@;
            eval "require $class; 1" or $RT::Logger->error(
                "Class '$class' is listed in CustomFieldValuesSources option"
                ." in the config, but we failed to load it:\n$@\n"
            );
        }

    }
}

=head2 InitSystemObjects

Initializes system objects: C<$RT::System>, C<< RT->SystemUser >>
and C<< RT->Nobody >>.

=cut

sub InitSystemObjects {

    #RT's system user is a genuine database user. its id lives here
    require RT::CurrentUser;
    $SystemUser = RT::CurrentUser->new;
    $SystemUser->LoadByName('RT_System');

    #RT's "nobody user" is a genuine database user. its ID lives here.
    $Nobody = RT::CurrentUser->new;
    $Nobody->LoadByName('Nobody');

    require RT::System;
    $System = RT::System->new( $SystemUser );
}

=head1 CLASS METHODS

=head2 Config

Returns the current L<config object|RT::Config>, but note that
you must L<load config|/LoadConfig> first otherwise this method
returns undef.

Method can be called as class method.

=cut

sub Config { return $Config || shift->LoadConfig(); }

=head2 DatabaseHandle

Returns the current L<database handle object|RT::Handle>.

See also L</ConnectToDatabase>.

=cut

sub DatabaseHandle { return $Handle }

=head2 Logger

Returns the logger. See also L</InitLogging>.

=cut

sub Logger { return $Logger }

=head2 System

Returns the current L<system object|RT::System>. See also
L</InitSystemObjects>.

=cut

sub System { return $System }

=head2 SystemUser

Returns the system user's object, it's object of
L<RT::CurrentUser> class that represents the system. See also
L</InitSystemObjects>.

=cut

sub SystemUser { return $SystemUser }

=head2 Nobody

Returns object of Nobody. It's object of L<RT::CurrentUser> class
that represents a user who can own ticket and nothing else. See
also L</InitSystemObjects>.

=cut

sub Nobody { return $Nobody }

sub PrivilegedUsers {
    if (!$_Privileged) {
    $_Privileged = RT::Group->new(RT->SystemUser);
    $_Privileged->LoadSystemInternalGroup('Privileged');
    }
    return $_Privileged;
}

sub UnprivilegedUsers {
    if (!$_Unprivileged) {
    $_Unprivileged = RT::Group->new(RT->SystemUser);
    $_Unprivileged->LoadSystemInternalGroup('Unprivileged');
    }
    return $_Unprivileged;
}


=head2 Plugins

Returns a listref of all Plugins currently configured for this RT instance.
You can define plugins by adding them to the @Plugins list in your RT_SiteConfig

=cut

our @PLUGINS = ();
sub Plugins {
    my $self = shift;
    unless (@PLUGINS) {
        $self->InitPluginPaths;
        @PLUGINS = $self->InitPlugins;
    }
    return \@PLUGINS;
}

=head2 PluginDirs

Takes an optional subdir (e.g. po, lib, etc.) and returns a list of
directories from plugins where that subdirectory exists.

This code does not check plugin names, plugin validitity, or load
plugins (see L</InitPlugins>) in any way, and requires that RT's
configuration have been already loaded.

=cut

sub PluginDirs {
    my $self = shift;
    my $subdir = shift;

    require RT::Plugin;

    my @res;
    foreach my $plugin (grep $_, RT->Config->Get('Plugins')) {
        my $path = RT::Plugin->new( name => $plugin )->Path( $subdir );
        next unless -d $path;
        push @res, $path;
    }
    return @res;
}

=head2 InitPluginPaths

Push plugins' lib paths into @INC right after F<local/lib>.
In case F<local/lib> isn't in @INC, append them to @INC

=cut

sub InitPluginPaths {
    my $self = shift || __PACKAGE__;

    my @lib_dirs = $self->PluginDirs('lib');

    my @tmp_inc;
    my $added;
    for (@INC) {
        my $realpath = Cwd::realpath($_);
        next unless defined $realpath;
        if ( $realpath eq $RT::LocalLibPath) {
            push @tmp_inc, $_, @lib_dirs;
            $added = 1;
        } else {
            push @tmp_inc, $_;
        }
    }

    # append @lib_dirs in case $RT::LocalLibPath isn't in @INC
    push @tmp_inc, @lib_dirs unless $added;

    my %seen;
    @INC = grep !$seen{$_}++, @tmp_inc;
}

=head2 InitPlugins

Initialize all Plugins found in the RT configuration file, setting up
their lib and L<HTML::Mason> component roots.

=cut

sub InitPlugins {
    my $self    = shift;
    my @plugins;
    require RT::Plugin;
    foreach my $plugin (grep $_, RT->Config->Get('Plugins')) {
        $plugin->require;
        die $UNIVERSAL::require::ERROR if ($UNIVERSAL::require::ERROR);
        push @plugins, RT::Plugin->new(name =>$plugin);
    }
    return @plugins;
}


sub InstallMode {
    my $self = shift;
    if (@_) {
        my ($integrity, $state, $msg) = RT::Handle->CheckIntegrity;
        if ($_[0] and $integrity) {
            # Trying to turn install mode on but we have a good DB!
            require Carp;
            $RT::Logger->error(
                Carp::longmess("Something tried to turn on InstallMode but we have DB integrity!")
            );
        }
        else {
            $_INSTALL_MODE = shift;
            if($_INSTALL_MODE) {
                require RT::CurrentUser;
               $SystemUser = RT::CurrentUser->new();
            }
        }
    }
    return $_INSTALL_MODE;
}

sub LoadGeneratedData {
    my $class = shift;
    my $pm_path = ( File::Spec->splitpath( $INC{'RT.pm'} ) )[1];

    require "$pm_path/RT/Generated.pm" || die "Couldn't load RT::Generated: $@";
    $class->CanonicalizeGeneratedPaths();
}

sub CanonicalizeGeneratedPaths {
    my $class = shift;
    unless ( File::Spec->file_name_is_absolute($EtcPath) ) {

   # if BasePath exists and is absolute, we won't infer it from $INC{'RT.pm'}.
   # otherwise RT.pm will make the source dir(where we configure RT) be the
   # BasePath instead of the one specified by --prefix
        unless ( -d $BasePath
                 && File::Spec->file_name_is_absolute($BasePath) )
        {
            my $pm_path = ( File::Spec->splitpath( $INC{'RT.pm'} ) )[1];

     # need rel2abs here is to make sure path is absolute, since $INC{'RT.pm'}
     # is not always absolute
            $BasePath = File::Spec->rel2abs(
                          File::Spec->catdir( $pm_path, File::Spec->updir ) );
        }

        $BasePath = Cwd::realpath($BasePath);

        for my $path (
                    qw/EtcPath BinPath SbinPath VarPath LocalPath LocalEtcPath
                    LocalLibPath LexiconPath LocalLexiconPath PluginPath
                    LocalPluginPath MasonComponentRoot MasonLocalComponentRoot
                    MasonDataDir MasonSessionDir/
                     )
        {
            no strict 'refs';

            # just change relative ones
            $$path = File::Spec->catfile( $BasePath, $$path )
                unless File::Spec->file_name_is_absolute($$path);
        }
    }

}

=head2 AddJavaScript

helper method to add js files to C<JSFiles> config.
to add extra js files, you can add the following line
in the plugin's main file:

    RT->AddJavaScript( 'foo.js', 'bar.js' ); 

=cut

sub AddJavaScript {
    my $self = shift;

    my @old = RT->Config->Get('JSFiles');
    RT->Config->Set( 'JSFiles', @old, @_ );
    return RT->Config->Get('JSFiles');
}

=head2 AddStyleSheets

helper method to add css files to C<CSSFiles> config

to add extra css files, you can add the following line
in the plugin's main file:

    RT->AddStyleSheets( 'foo.css', 'bar.css' ); 

=cut

sub AddStyleSheets {
    my $self = shift;
    my @old = RT->Config->Get('CSSFiles');
    RT->Config->Set( 'CSSFiles', @old, @_ );
    return RT->Config->Get('CSSFiles');
}

=head2 JavaScript

helper method of RT->Config->Get('JSFiles')

=cut

sub JavaScript {
    return RT->Config->Get('JSFiles');
}

=head2 StyleSheets

helper method of RT->Config->Get('CSSFiles')

=cut

sub StyleSheets {
    return RT->Config->Get('CSSFiles');
}

=head1 BUGS

Please report them to rt-bugs@bestpractical.com, if you know what's
broken and have at least some idea of what needs to be fixed.

If you're not sure what's going on, report them rt-devel@lists.bestpractical.com.

=head1 SEE ALSO

L<RT::StyleGuide>
L<DBIx::SearchBuilder>

=cut

require RT::Base;
RT::Base->_ImportOverlays();

1;
