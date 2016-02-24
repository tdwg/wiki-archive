# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::Plugins

This module defines the singleton object that handles Plugins
loading, initialization and execution.

This class uses Chain of Responsibility (GOF) pattern to dispatch
handler calls to registered plugins.

=cut

=pod

Note that as of version 1.026 of this module, TWiki internal
methods are _no longer available_ to plugins. Any calls to
TWiki internal methods must be replaced by calls via the
=$SESSION= object in this package, or via the Func package.
For example, the call:

=my $pref = TWiki::getPreferencesValue('URGH');=

should be replaced with

=my $pref = TWiki::Func::getPreferencesValue('URGH');=

and the call

=my $t = TWiki::writeWarning($message);=

should be replaced with

=my $pref = $TWiki::Plugins::SESSION->writeWarning($message);=

Methods in other modules such as Store must be accessed through
the relevant TWiki sub-object, for example

=TWiki::Store::saveTopic(...)=

should be replaced with

=$TWiki::Plugins::SESSION->{store}->saveTopic(...)=

Note that calling TWiki internal methods is very very bad practice,
and should be avoided wherever practical.

The developers of TWiki reserve the right to change internal
methods without warning, unless those methods are clearly
marked as PUBLIC. PUBLIC methods are part of the core specification
of a module and can be trusted.

=cut

package TWiki::Plugins;

use strict;
use Assert;
use TWiki::Plugin;
use TWiki::Func;

use vars qw ( $VERSION $SESSION $inited );

=pod

---++ PUBLIC constant $VERSION

This is the version number of the plugins package. Use it for checking
if you have a recent enough version.

---++ PUBLIC $SESSION

This is a reference to the TWiki session object. It can be used in
plugins to get at the methods of the TWiki kernel.

You are _highly_ recommended to only use the methods in the
[[TWikiFuncDotPm][Func]] interface, unless you have no other choice,
as kernel methods may change between TWiki releases.

=cut

$VERSION = '1.11';

$inited = 0;

my %onlyOnceHandlers =
  (
   registrationHandler            => 1,
   writeHeaderHandler             => 1,
   redirectCgiQueryHandler        => 1,
   renderFormFieldForEditHandler  => 1,
   renderWikiWordHandler          => 1,
  );

=pod

---++ ClassMethod new( $session )

Construct new singleton plugins collection object. The object is a
container for a list of plugins and the handlers registered by the plugins.
The plugins and the handlers are carefully ordered.

=cut

sub new {
    my ( $class, $session ) = @_;

    my $this = bless( {}, $class );

    ASSERT($session->isa( 'TWiki')) if DEBUG;
    $this->{session} = $session;

    unless( $inited ) {
        TWiki::registerTagHandler( 'PLUGINDESCRIPTIONS',
                                   \&_handlePLUGINDESCRIPTIONS );
        TWiki::registerTagHandler( 'ACTIVATEDPLUGINS',
                                   \&_handleACTIVATEDPLUGINS );
        TWiki::registerTagHandler( 'FAILEDPLUGINS',
                                   \&_handleFAILEDPLUGINS );
        $inited = 1;
    }

    return $this;
}

=pod

---++ ObjectMethod load($allDisabled) -> $loginName

Find all active plugins, and invoke the early initialisation.
Has to be done _after_ prefs are read.

Returns the user returned by the last =initializeUserHandler= to be
called.

If allDisabled is set, no plugin handlers will be called.

=cut

sub load {
    my ( $this, $allDisabled ) = @_;
    ASSERT($this->isa( 'TWiki::Plugins')) if DEBUG;

    my %lookup;

    my $session = $this->{session};
    my $query = $session->{cgiQuery};

    my @pluginList = ();
    my %already;

    unless( $allDisabled ) {
        if ( $query && defined( $query->param( 'debugenableplugins' ))) {
            @pluginList = split( /[,\s]+/,
                                 $query->param( 'debugenableplugins' ));
        } else {
            if( $TWiki::cfg{PluginsOrder} ) {
                foreach my $plugin( split( /[,\s]+/,
                                           $TWiki::cfg{PluginsOrder} )) {
                    # Note this allows the same plugin to be listed
                    # multiple times! Thus their handlers can be called
                    # more than once. This is *desireable*.
                    if( $TWiki::cfg{Plugins}{$plugin}{Enabled} ) {
                        push( @pluginList, $plugin );
                        $already{$plugin} = 1;
                    }
                }
            }
            foreach my $plugin ( sort keys %{$TWiki::cfg{Plugins}} ) {
                if( $TWiki::cfg{Plugins}{$plugin}{Enabled} &&
                      !$already{$plugin} ) {
                    push( @pluginList, $plugin );
                    $already{$plugin} = 1;
                }
            }
        }
    }
    my $user; # the user login name
    my $userDefiner; # the plugin that is defining the user
    foreach my $pn ( @pluginList ) {
        my $p;
        unless( $p = $lookup{$pn} ) {
            $p = new TWiki::Plugin( $session, $pn,
                                    $TWiki::cfg{Plugins}{$pn}{Module} )
        }
        push @{$this->{plugins}}, $p;
        my $anotherUser = $p->load();
        if( $anotherUser ) {
            if( $userDefiner ) {
                die 'Two plugins - '. $userDefiner->{name} . ' and ' .
                  $p->{name} .
                    ' are both trying to define the user login name.';
            } else {
                $userDefiner = $p;
                $user = $anotherUser;
            }
        }
        # Report initialisation errors
        if( $p->{errors} ) {
            $this->{session}->writeWarning( join( "\n", @{$p->{errors}} ));
        }
        $lookup{$pn} = $p;
    }

    return $user;
}

=pod

---++ ObjectMethod settings()

Push plugin settings onto preference stack

=cut

sub settings {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Plugins')) if DEBUG;

    # Set the session for this call stack
    local $TWiki::Plugins::SESSION = $this->{session};

    foreach my $plugin ( @{$this->{plugins}} ) {
        $plugin->registerSettings( $this );
    }
}

=pod

---++ ObjectMethod enable()

Initialisation that is done after the user is known.

=cut

sub enable {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Plugins')) if DEBUG;
    my $prefs = $this->{session}->{prefs};
    my $dissed = $prefs->getPreferencesValue('DISABLEDPLUGINS') || '';
    my %disabled = map { $_ => 1 } split(/,\s*/, $dissed);

    # Set the session for this call stack
    local $TWiki::Plugins::SESSION = $this->{session};

    foreach my $plugin ( @{$this->{plugins}} ) {
        if ($disabled{$plugin->{name}}) {
            $plugin->{disabled} = 1;
            push( @{$plugin->{errors}}, $plugin->{name}.' has been disabled' );
        }
        $plugin->registerHandlers( $this );
        # Report initialisation errors
        if ( $plugin->{errors} ) {
            $this->{session}->writeWarning( join( "\n", @{$plugin->{errors}} ));
        }
    }
}

=pod

---++ ObjectMethod getPluginVersion() -> $number

Returns the $TWiki::Plugins::VERSION number if no parameter is specified,
else returns the version number of a named Plugin. If the Plugin cannot
be found or is not active, 0 is returned.

=cut

sub getPluginVersion {
    my ( $this, $thePlugin ) = @_;
    ASSERT($this->isa( 'TWiki::Plugins')) if DEBUG;

    return $VERSION unless $thePlugin;

    foreach my $plugin ( @{$this->{plugins}} ) {
        if( $plugin->{name} eq $thePlugin ) {
            return $plugin->getVersion();
        }
    }
    return 0;
}

=pod

---++ ObjectMethod addListener( $command, $handler )

   * =$command* - name of the event
   * =$handler= - the handler object.

Add a listener to the end of the list of registered listeners for this event.
The listener must implement =invoke($command,...)=, which will be triggered
when the event is to be processed.

=cut

sub addListener {
    my( $this, $c, $h ) = @_;
    ASSERT($this->isa( 'TWiki::Plugins')) if DEBUG;

    push( @{$this->{registeredHandlers}{$c}}, $h );
}

sub _dispatch {
    # must be shifted to clear parameter vector
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Plugins')) if DEBUG;
    my $handlerName = shift;

    foreach my $plugin ( @{$this->{registeredHandlers}{$handlerName}} ) {
        # Set the value of $SESSION for this call stack
        local $SESSION = $this->{session};
        # apply handler on the remaining list of args
        no strict 'refs';
        my $status = $plugin->invoke( $handlerName, @_ );
        use strict 'refs';
        if( $status && $onlyOnceHandlers{$handlerName} ) {
            return $status;
        }
    }
    return undef;
}

=pod

---++ ObjectMethod haveHandlerFor( $handlerName ) -> $boolean

   * =$handlerName= - name of the handler e.g. preRenderingHandler
Return: true if at least one plugin has registered a handler of
this type.

=cut

sub haveHandlerFor {
    my( $this, $handlerName ) = @_;

    return 0 unless defined( $this->{registeredHandlers}{$handlerName} );
    return scalar( @{$this->{registeredHandlers}{$handlerName}} );
}

# %FAILEDPLUGINS reports reasons why plugins failed to load
# note this is invoked with the session as the first parameter
sub _handleFAILEDPLUGINS {
    my $this = shift->{plugins};

    my $text = CGI::start_table( { border => 1, class => 'twikiTable' } ).
      CGI::Tr(CGI::th('Plugin').CGI::th('Errors'));

    foreach my $plugin ( @{$this->{plugins}} ) {
        my $td;
        if ( $plugin->{errors}) {
            $td = CGI::td( {class => 'twikiAlert' },
                "\n<verbatim>\n".
                  join( "\n", @{$plugin->{errors}} ).
                    "\n</verbatim>\n" );
        } else {
            $td = CGI::td( 'none' );
        }
        $text .= CGI::Tr( { valign=>'top' },
                          CGI::td(' '.$plugin->{installWeb}.'.'.$plugin->{name}.' '). $td );
    }

    $text .= CGI::end_table().CGI::start_table({ border=>1, class => 'twikiTable' }).
      CGI::Tr(CGI::th('Handler').CGI::th('Plugins'));

    foreach my $handler (@TWiki::Plugin::registrableHandlers) {
        my $h = '';
        if ( defined( $this->{registeredHandlers}{$handler} ) ) {
            $h = join( CGI::br(),
                       map{ $_->{name} }
                       @{$this->{registeredHandlers}{$handler}} );
        }
        if ( $h ) {
            if( defined( $TWiki::Plugin::deprecated{ $handler })) {
                $h .= CGI::br() . CGI::span(
                    { class=>'twikiAlert' },
                    " __This handler is deprecated__ - please check for updated versions of the plugins that use it!" );
            }
            $text .= CGI::Tr( { valign=>'top' },
                              CGI::td( $handler ).CGI::td( $h ) );
        }
    }

    return $text.CGI::end_table()."\n*".scalar(@{$this->{plugins}}).
      " plugins*\n\n";
}

# note this is invoked with the session as the first parameter
sub _handlePLUGINDESCRIPTIONS {
    my $this = shift->{plugins};
    my $text = '';
    foreach my $plugin ( @{$this->{plugins}} ) {
        $text .= CGI::li( $plugin->getDescription() );
    }

    return CGI::ul( $text );
}

# note this is invoked with the session as the first parameter
sub _handleACTIVATEDPLUGINS {
    my $this = shift->{plugins};
    my $text = '';
    foreach my $plugin ( @{$this->{plugins}} ) {
        unless( $plugin->{disabled} ) {
            $text .= "$plugin->{installWeb}.$plugin->{name}, ";
        }
    }
    $text =~ s/\,\s*$//o;
    return $text;
}

=pod

---++ ObjectMethod registrationHandler ()

Called by the register script

=cut

sub registrationHandler {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Plugins')) if DEBUG;
    #my( $web, $wikiName, $loginName ) = @_;
    $this->_dispatch( 'registrationHandler', @_ );
}

=pod

---++ ObjectMethod beforeCommonTagsHandler ()

Called at the beginning (for cache Plugins only)

=cut

sub beforeCommonTagsHandler {
    my $this = shift;
    #my( $text, $topic, $theWeb ) = @_;
    $this->_dispatch( 'beforeCommonTagsHandler', @_ );
}

=pod

---++ ObjectMethod commonTagsHandler ()

Called after %INCLUDE:"..."%

=cut

sub commonTagsHandler {
    my $this = shift;
    #my( $text, $topic, $theWeb ) = @_;
    $this->_dispatch( 'commonTagsHandler', @_ );
}

=pod

---++ ObjectMethod afterCommonTagsHandler ()

Called at the end (for cache Plugins only)

=cut

sub afterCommonTagsHandler {
    my $this = shift;
    #my( $text, $topic, $theWeb ) = @_;
    $this->_dispatch( 'afterCommonTagsHandler', @_ );
}

=pod

---++ ObjectMethod preRenderingHandler( $text, \%map )

   * =$text= - the text, with the head, verbatim and pre blocks replaced with placeholders
   * =\%removed= - reference to a hash that maps the placeholders to the removed blocks.

Placeholders are text strings constructed using the tag name and a sequence number e.g. 'pre1', "verbatim6", "head1" etc. Placeholders are inserted into the text inside \1 characters so the text will contain \1_pre1\1 for placeholder pre1.

Each removed block is represented by the block text and the parameters passed to the tag (usually empty) e.g. for
<verbatim>
<pre class='slobadob'>
XYZ
</pre>
the map will contain:
<pre>
$removed->{'pre1'}{text}:   XYZ
$removed->{'pre1'}{params}: class="slobadob"
</pre>
</verbatim>

Iterating over blocks for a single tag is easy. For example, to prepend a line number to every line of a pre block you might use this code:

foreach my $placeholder ( keys %$map ) {
    if( $placeholder =~ /^pre/i ) {
       my $n = 1;
       $map->{$placeholder}{text} =~ s/^/$n++/gem;
    }
}

=cut

sub preRenderingHandler {
    my $this = shift;
    $this->_dispatch( 'preRenderingHandler', @_ );
    # Apply the startRenderingHandler (*deprecated*!) if any are defined
}

=pod

---++ ObjectMethod postRenderingHandler( \$text )

   * =\$text= - a reference to the HTML, with the head, verbatim and pre blocks replaced with placeholders

=cut

sub postRenderingHandler {
    my $this = shift;
    $this->_dispatch( 'postRenderingHandler', @_ );
}

=pod

---++ ObjectMethod startRenderingHandler ()

Called just before the line loop

*DEPRECATED* Use preRenderingHandler instead. This handler correctly 
handles verbatim and other TWiki ML block types, and exposes them to 
the plugin.

=cut

sub startRenderingHandler {
    my $this = shift;
    #my ( $text, $web, $topic ) = @_;
    $this->_dispatch( 'startRenderingHandler', @_ );
}

=pod

---++ ObjectMethod outsidePREHandler ()

Called in line loop outside of &lt;PRE&gt; tag

*DEPRECATED* Use preRenderingHandler instead. 
This handler correctly handles pre and other 
TWiki ML block types, and is called only once 
instead of line-by-line.

=cut

sub outsidePREHandler {
    my $this = shift;
    #my( $text ) = @_;
    $this->_dispatch( 'outsidePREHandler', @_ );
}

=pod

---++ ObjectMethod insidePREHandler ()

Called in line loop inside of &lt;PRE&gt; tag

*DEPRECATED* Use preRenderingHandler instead. 
This handler correctly handles pre and other 
TWiki ML block types, and is called only once 
instead of line-by-line.

=cut

sub insidePREHandler {
    my $this = shift;
    #my( $text ) = @_;
    $this->_dispatch( 'insidePREHandler', @_ );
}

=pod

---++ ObjectMethod endRenderingHandler ()

Called just after the line loop

*DEPRECATED* Use postRenderingHandler instead.

=cut

sub endRenderingHandler {
    my $this = shift;
    #my ( $text ) = @_;
    $this->_dispatch( 'endRenderingHandler', @_ );
}

=pod

---++ ObjectMethod beforeEditHandler ()

Called by edit

=cut

sub beforeEditHandler {
    my $this = shift;
    #my( $text, $topic, $web, $meta ) = @_;
    $this->_dispatch( 'beforeEditHandler', @_ );
}

=pod

---++ ObjectMethod afterEditHandler ()

Called by edit

=cut

sub afterEditHandler {
    my $this = shift;
    #my( $text, $topic, $web ) = @_;
    $this->_dispatch( 'afterEditHandler', @_ );
}

=pod

---++ ObjectMethod beforeSaveHandler ()

Called just before the save action

=cut

sub beforeSaveHandler {
    my $this = shift;
    #my ( $theText, $theTopic, $theWeb, $meta ) = @_;
    $this->_dispatch( 'beforeSaveHandler', @_ );
}

=pod

---++ ObjectMethod afterSaveHandler ()

Called just after the save action

=cut

sub afterSaveHandler {
    my $this = shift;
    #my ( $theText, $theTopic, $theWeb, $error, $meta ) = @_;
    $this->_dispatch( 'afterSaveHandler', @_ );
}

=pod

---++ ObjectMethod afterRenameHandler ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment )

Called just after the rename/move/delete action of a web, topic or attachment.

   * =$oldWeb= - name of old web
   * =$oldTopic= - name of old topic (empty string if web rename)
   * =$oldAttachment= - name of old attachment (empty string if web or topic rename)
   * =$newWeb= - name of new web
   * =$newTopic= - name of new topic (empty string if web rename)
   * =$newAttachment= - name of new attachment (empty string if web or topic rename)

=cut

sub afterRenameHandler {
    my $this = shift;
    #my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment ) = @_;
    $this->_dispatch( 'afterRenameHandler', @_ );
}

=pod

---++ ObjectMethod mergeHandler ()

Called to handle text merge.

=cut

sub mergeHandler {
    my $this = shift;
    $this->_dispatch( 'mergeHandler', @_ );
}

=pod

---++ ObjectMethod beforeAttachmentSaveHandler ( $attrHashRef, $topic, $web ) 

This code provides Plugins with the opportunity to alter an uploaded attachment between the upload and save-to-store processes. It is invoked as per other Plugins.
   * =$attrHashRef= - Hash reference of attachment attributes (keys are indicated below)
   * =$topic= -     | Topic name
   * =$web= -       | Web name

Keys in $attrHashRef:
| *Key*       | *Value* |
| attachment  | Name of the attachment |
| tmpFilename | Name of the local file that stores the upload |
| comment     | Comment to be associated with the upload |
| user        | Login name of the person submitting the attachment, e.g. 'jsmith' |

Note: All keys should be used read-only, except for comment which can be modified.

Example usage:

<pre>
   my( $attrHashRef, $topic, $web ) = @_;
   $$attrHashRef{'comment'} .= " (NOTE: Extracted from blah.tar.gz)";
</pre>

=cut

sub beforeAttachmentSaveHandler {
    my $this = shift;
    #my ( $theAttrHash, $theTopic, $theWeb ) = @_;
    $this->_dispatch( 'beforeAttachmentSaveHandler', @_ );
}

=pod

---++ ObjectMethod afterAttachmentSaveHandler( $attachmentAttrHash, $topic, $web, $error )

deal with an uploaded attachment between the upload and save-to-store processes. It is invoked as per other plugins.

   * =$attrHashRef= - Hash reference of attachment attributes (keys are indicated below)
   * =$topic= -     | Topic name
   * =$web= -       | Web name
   * =$error= -     | Error string of save action, empty if OK

Keys in $attrHashRef:
| *Key*       | *Value* |
| attachment  | Name of the attachment |
| tmpFilename | Name of the local file that stores the upload |
| comment     | Comment to be associated with the upload |
| user        | Login name of the person submitting the attachment, e.g. 'jsmith' |

Note: The hash is *read-only*

=cut

sub afterAttachmentSaveHandler {
    my $this = shift;
    #my ( $theText, $theTopic, $theWeb ) = @_;
    $this->_dispatch( 'afterAttachmentSaveHandler', @_ );
}


=pod

---++ ObjectMethod writeHeaderHandler () -> $headers

Called by TWiki::writePageHeader. *DEPRECATED* do not use!

*DEPRECATED* Use modifyHeaderHandler instead. it is a lot 
more flexible, and allows you to modify existing headers 
as well as add new ones. It also works correctly when 
multiple plugins want to modify headers.

=cut

sub writeHeaderHandler {
    my $this = shift;
    return $this->_dispatch( 'writeHeaderHandler', @_ );
}

=pod

---++ ObjectMethod modifyHeaderHandler ( \@headers, $query )

=cut

sub modifyHeaderHandler {
    my $this = shift;
    return $this->_dispatch( 'modifyHeaderHandler', @_ );
}

=pod

---++ ObjectMethod redirectCgiQueryHandler () -> $result

Called by TWiki::redirect

=cut

sub redirectCgiQueryHandler {
    my $this = shift;
    return $this->_dispatch( 'redirectCgiQueryHandler', @_ );
}

=pod

---++ ObjectMethod renderFormFieldForEditHandler ( $name, $type, $size, $value, $attributes, $possibleValues ) -> $html

This handler is called before built-in types are considered. It generates the HTML text rendering this form field, or false, if the rendering should be done by the built-in type handlers.
   * =$name= - name of form field
   * =$type= - type of form field
   * =$size= - size of form field
   * =$value= - value held in the form field
   * =$attributes= - attributes of form field 
   * =$possibleValues= - the values defined as options for form field, if any. May be a scalar (one legal value) or an array (several legal values)
Return HTML text that renders this field. If false, form rendering continues by considering the built-in types.

Note that a common application would be to generate formatting of the
field involving generation of javascript. Such usually also requires
the insertion of some common javascript into the page header. Unfortunately,
there is currently no mechanism to pass that script to where the header of
the page is visible. Consequentially, the common javascript may have to
be emitted as part of the field formatting and might be duplicated many
times throughout the page.

=cut

sub renderFormFieldForEditHandler {
    my $this = shift;
    return $this->_dispatch( 'renderFormFieldForEditHandler', @_ );
}

=pod

---++ ObjectMethod renderWikiWordHandler () -> $result

Change how a WikiWord is rendered

Originated from the TWiki:Plugins.SpacedWikiWordPlugin hack

=cut

sub renderWikiWordHandler {
    my $this = shift;
    return $this->_dispatch( 'renderWikiWordHandler', @_ );
}

1;
